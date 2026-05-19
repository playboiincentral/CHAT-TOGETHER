const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({
  maxInstances: 100,
  region: "asia-southeast1"
});


// =======================================================
// 1️⃣ JOIN QUEUE (Atomic FIFO)
// =======================================================

exports.joinQueue = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const userId = request.auth.uid;

  const userRef = db.collection("users").doc(userId);
  const queueRef = db.collection("system").doc("matchQueue");

  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new Error("User not found");

  const gender = userDoc.data().gender;
  if (!gender) throw new Error("Missing gender");

  const myQueueKey = gender === "male" ? "male" : "female";
  const targetQueueKey = gender === "male" ? "female" : "male";

  let createdRoomId = null;

  // =========================
  // 🔥 BLOCK + FRIEND
  // =========================

  const blockSnapshot = await db.collection("blocks")
    .where("blockerId", "==", userId)
    .get();

  const blockedSet = new Set(
    blockSnapshot.docs.map(doc => doc.data().blockedId)
  );

  const blockedBySnapshot = await db.collection("blocks")
    .where("blockedId", "==", userId)
    .get();

  blockedBySnapshot.docs.forEach(doc => {
    blockedSet.add(doc.data().blockerId);
  });

  const friendSnapshot = await db.collection("friendships")
    .where("users", "array-contains", userId)
    .get();

  const friendSet = new Set();

  friendSnapshot.docs.forEach(doc => {
    const users = doc.data().users || [];
    const other = users.find(u => u !== userId);
    if (other) friendSet.add(other);
  });

  // =========================
  // 🔥 TRANSACTION
  // =========================

  await db.runTransaction(async (transaction) => {
    const queueSnap = await transaction.get(queueRef);

    let data = queueSnap.exists
      ? queueSnap.data()
      : { male: [], female: [] };

    let myQueue = data[myQueueKey] || [];
    let targetQueue = data[targetQueueKey] || [];

    // =========================
    // ❌ tránh join trùng
    // =========================

    const alreadyInQueue =
      myQueue.some(u => u.uid === userId) ||
      targetQueue.some(u => u.uid === userId);

    if (alreadyInQueue) {
      data[myQueueKey] = myQueue;
      data[targetQueueKey] = targetQueue;

      transaction.set(queueRef, data, { merge: true });
      return;
    }

    // =========================
    // 🔥 MATCH
    // =========================

    if (targetQueue.length > 0) {

      const MAX_CHECK = 10;
      let partnerId = null;

      for (let i = 0; i < Math.min(MAX_CHECK, targetQueue.length); i++) {

        const candidate = targetQueue[i];

        if (!candidate || !candidate.uid) {
          targetQueue.splice(i, 1);
          i--;
          continue;
        }

        const candidateId = candidate.uid;
        const isBlocked = blockedSet.has(candidateId);
        const isFriend = friendSet.has(candidateId);

        if (!isBlocked && !isFriend) {
          partnerId = candidateId;
          targetQueue.splice(i, 1);
          break;
        }
      }

      if (partnerId) {

        const roomRef = db.collection("chatRooms").doc();
        createdRoomId = roomRef.id;

        transaction.set(roomRef, {
          users: [userId, partnerId],
          type: "random",
          activeUsers: [userId, partnerId],
          status: "active",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          endedAt: null,
          endedBy: null,
          lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: null,
          lastMessageSenderId: null,
          lastMessageAt: null
        });

        data[targetQueueKey] = targetQueue;

      } else {
        // ❌ không match được → vào queue
        myQueue.push({
          uid: userId
        });

        data[myQueueKey] = myQueue;
      }

    } else {

      myQueue.push({
        uid: userId
      });

      data[myQueueKey] = myQueue;
    }

    transaction.set(queueRef, data, { merge: true });
  });

  return { roomId: createdRoomId };
});

// =======================================================
// 1️⃣ JOIN QUEUE (Atomic FIFO)
// =======================================================

exports.leaveRoom = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const userId = request.auth.uid;
  const roomId = request.data.roomId;

  if (!roomId) {
    throw new Error("Missing roomId");
  }

  const roomRef = db.collection("chatRooms").doc(roomId);
  const roomSnap = await roomRef.get();

  if (!roomSnap.exists) return { success: true };

  const room = roomSnap.data();

  // ❌ Không phải user trong room → bỏ qua
  if (!room.users.includes(userId)) {
    return { success: true };
  }

  if (room.type === "random") {
    // 🔥 RANDOM → XOÁ LUÔN
    await deleteRoomWithMessages(roomRef);
  }

  return { success: true };
});

// =======================================================
// 2️⃣ LEAVE QUEUE
// =======================================================

exports.leaveQueue = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const userId = request.auth.uid;
  const queueRef = db.collection("system").doc("matchQueue");

  await db.runTransaction(async (transaction) => {

    const queueDoc = await transaction.get(queueRef);
    if (!queueDoc.exists) return;

    const data = queueDoc.data();

    let male = data.male || [];
    let female = data.female || [];

    male = male.filter(u => u.uid !== userId);
    female = female.filter(u => u.uid !== userId);

    transaction.set(queueRef, {
      male,
      female
    });
  });

  return { success: true };
});

// ===========================================
// Friend Room
// ===========================================

exports.getOrCreateFriendRoom = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const currentUserId = request.auth.uid;
  const friendId = request.data.friendId;

  if (!friendId) {
    throw new Error("Missing friendId");
  }

  // 🔥 Tạo ID deterministic (QUAN TRỌNG)
  const sortedUsers = [currentUserId, friendId].sort();
  const roomId = sortedUsers.join("_");

  const roomRef = db.collection("chatRooms").doc(roomId);

  await db.runTransaction(async (transaction) => {

  const doc = await transaction.get(roomRef);

  if (doc.exists) {
    return;
  }

  transaction.set(roomRef, {
    users: sortedUsers,
    type: "friend",
    status: "active",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessage: null,
    lastMessageSenderId: null,
    lastMessageAt: null,
    lastReadAt: {
    [currentUserId]: admin.firestore.FieldValue.serverTimestamp()
  }
  });
});

  return { roomId };
});

// =======================================================
// 4️⃣ CLEANUP ENDED ROOMS
// =======================================================

exports.cleanupEndedRooms = onSchedule(
  "every 2 minutes",
  async () => {

    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);

    const snapshot = await db.collection("chatRooms")
      .where("status", "==", "ended")
      .where("type", "==", "random")
      .where("endedAt", "<", twoMinutesAgo)
      .get();

    for (const doc of snapshot.docs) {
      await deleteRoomWithMessages(doc.ref);
      console.log("Room deleted:", doc.id);
    }
  }
);


// =======================================================
// 5️⃣ DELETE ROOM + MESSAGES
// =======================================================

async function deleteRoomWithMessages(roomRef) {

  const messagesRef = roomRef.collection("messages");

  while (true) {
    const snapshot = await messagesRef.limit(500).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }

  await roomRef.delete();
}

exports.blockUser = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const blockerId = request.auth.uid;
  const blockedId = request.data.blockedId;

  if (!blockedId) {
    throw new Error("Missing blockedId");
  }

  const batch = db.batch();

  // 1️⃣ Tạo block
  const blockRef = db.collection("blocks").doc();
  batch.set(blockRef, {
    blockerId,
    blockedId,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // 2️⃣ Xoá friendship nếu có
  const sortedUsers = [blockerId, blockedId].sort();
  const friendshipId = sortedUsers.join("_");

  const friendshipRef = db.collection("friendships").doc(friendshipId);
  batch.delete(friendshipRef);

  // 3️⃣ Xoá friend requests
  const requests = await db.collection("friendRequests").get();
  requests.docs.forEach(doc => {
    const data = doc.data();
    if (
      (data.fromUserId === blockerId && data.toUserId === blockedId) ||
      (data.fromUserId === blockedId && data.toUserId === blockerId)
    ) {
      batch.delete(doc.ref);
    }
  });

  await batch.commit();

  // 4️⃣ HANDLE ROOM
const rooms = await db.collection("chatRooms")
  .where("users", "array-contains", blockerId)
  .get();

for (const doc of rooms.docs) {
  const room = doc.data();
  const users = room.users || [];

  if (!users.includes(blockedId)) continue;

  const roomRef = doc.ref;

  await deleteRoomWithMessages(roomRef);
}

  return { success: true };
});

exports.removeFriend = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const currentUserId = request.auth.uid;
  const partnerId = request.data.partnerId;

  if (!partnerId) {
    throw new Error("Missing partnerId");
  }

  const userRef1 = db.collection("users").doc(currentUserId);
  const userRef2 = db.collection("users").doc(partnerId);

  const sortedUsers = [currentUserId, partnerId].sort();
  const friendshipId = sortedUsers.join("_");

  const friendshipRef = db.collection("friendships").doc(friendshipId);

  await db.runTransaction(async (transaction) => {
    const friendshipDoc = await transaction.get(friendshipRef);

    if (!friendshipDoc.exists) return;

    // xoá friendship
    transaction.delete(friendshipRef);

    // giảm count
    transaction.update(userRef1, {
      friendCount: admin.firestore.FieldValue.increment(-1)
    });

    transaction.update(userRef2, {
      friendCount: admin.firestore.FieldValue.increment(-1)
    });
  });

  // 🔥 xoá chatroom
  const roomId = sortedUsers.join("_");
  const roomRef = db.collection("chatRooms").doc(roomId);

  const roomSnap = await roomRef.get();

  if (roomSnap.exists) {
    await deleteRoomWithMessages(roomRef);
  }

  return { success: true };
});

// =======================================================
// 6️⃣ ACCEPT FRIEND REQUEST (LIMIT 200 + ATOMIC)
// =======================================================

exports.acceptFriendRequest = onCall(async (request) => {

  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const currentUserId = request.auth.uid;
  const partnerId = request.data.partnerId;
  const requestId = request.data.requestId;

  if (!partnerId || !requestId) {
    throw new Error("Missing data");
  }

  const userRef1 = db.collection("users").doc(currentUserId);
  const userRef2 = db.collection("users").doc(partnerId);

  const sortedUsers = [currentUserId, partnerId].sort();
  const friendshipId = sortedUsers.join("_");

  const friendshipRef = db.collection("friendships").doc(friendshipId);
  const requestRef = db.collection("friendRequests").doc(requestId);

  await db.runTransaction(async (transaction) => {

    // 🔥 1. Lấy user data
    const [user1Doc, user2Doc, requestDoc, friendshipDoc] = await Promise.all([
      transaction.get(userRef1),
      transaction.get(userRef2),
      transaction.get(requestRef),
      transaction.get(friendshipRef)
    ]);

    if (!user1Doc.exists || !user2Doc.exists) {
      throw new Error("User not found");
    }

    if (!requestDoc.exists) {
      throw new Error("Request not found");
    }

    // 🔥 2. Check request hợp lệ
    const requestData = requestDoc.data();

    if (
      requestData.toUserId !== currentUserId ||
      requestData.fromUserId !== partnerId
    ) {
      throw new Error("Invalid request");
    }

    // 🔥 3. Check limit 200
    const count1 = user1Doc.data().friendCount || 0;
    const count2 = user2Doc.data().friendCount || 0;

    if (count1 >= 200 || count2 >= 200) {
      throw new Error("Friend limit reached");
    }

    // 🔥 4. Tránh duplicate
    if (friendshipDoc.exists) {
      // vẫn xoá request để clean
      transaction.delete(requestRef);
      return;
    }

    // 🔥 5. Tạo friendship
    transaction.set(friendshipRef, {
      users: sortedUsers,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 🔥 6. Tăng friendCount
    transaction.update(userRef1, {
      friendCount: admin.firestore.FieldValue.increment(1)
    });

    transaction.update(userRef2, {
      friendCount: admin.firestore.FieldValue.increment(1)
    });

    // 🔥 7. Xoá request
    transaction.delete(requestRef);
  });

  return { success: true };
});

exports.deleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthorized");
  }

  const uid = request.auth.uid;

  // =======================================================
  // 1️⃣ DELETE FRIENDS + CHATROOMS (QUAN TRỌNG NHẤT)
  // =======================================================
  const friendships = await db.collection("friendships")
    .where("users", "array-contains", uid)
    .get();

  for (const doc of friendships.docs) {
    const users = doc.data().users || [];
    const partnerId = users.find(u => u !== uid);

    if (!partnerId) continue;

    const sortedUsers = [uid, partnerId].sort();
    const friendshipId = sortedUsers.join("_");

    // 🔥 xoá friendship
    await db.collection("friendships").doc(friendshipId).delete();

    // 🔥 xoá chatroom friend
    const roomId = sortedUsers.join("_");
    const roomRef = db.collection("chatRooms").doc(roomId);

    const roomSnap = await roomRef.get();
    if (roomSnap.exists) {
      await deleteRoomWithMessages(roomRef);
    }
  }

  // =======================================================
  // 2️⃣ DELETE FRIEND REQUESTS
  // =======================================================
  const sent = await db.collection("friendRequests")
    .where("fromUserId", "==", uid)
    .get();

  const received = await db.collection("friendRequests")
    .where("toUserId", "==", uid)
    .get();

  const batch = db.batch();

  sent.docs.forEach(doc => batch.delete(doc.ref));
  received.docs.forEach(doc => batch.delete(doc.ref));

  // =======================================================
  // 3️⃣ DELETE BLOCKS
  // =======================================================
  const blocks1 = await db.collection("blocks")
    .where("blockerId", "==", uid)
    .get();

  const blocks2 = await db.collection("blocks")
    .where("blockedId", "==", uid)
    .get();

  blocks1.docs.forEach(doc => batch.delete(doc.ref));
  blocks2.docs.forEach(doc => batch.delete(doc.ref));

  // =======================================================
  // 4️⃣ DELETE USER
  // =======================================================
  const userRef = db.collection("users").doc(uid);
  batch.delete(userRef);

  await batch.commit();

  // =======================================================
  // 5️⃣ DELETE AVATAR (Storage)
  // =======================================================
  const bucket = admin.storage().bucket();

  try {
    await bucket.file(`avatars/${uid}.jpg`).delete();
  } catch (e) {
    console.log("No avatar");
  }

  // =======================================================
  // 6️⃣ DELETE AUTH
  // =======================================================
  await admin.auth().deleteUser(uid);

  return { success: true };
});

const openaiKey = defineSecret("OPENAI_API_KEY");

exports.onMessageCreated = onDocumentCreated(
  {
    document: "chatRooms/{roomId}/messages/{messageId}",
    secrets: [openaiKey]
  },
  async (event) => {
    const data = event.data.data();
    if (!data || data.isAI || !data.text) return;

    const mentionRegex = /@tomi\b/i;

    // ❌ Không mention → bỏ
    if (!mentionRegex.test(data.text)) return;

    // 🔥 Clean message hiện tại
    const prompt = data.text.replace(mentionRegex, "").trim();
    const finalPrompt = prompt || "User just mentioned you, respond naturally in chat.";

    const roomId = event.params.roomId;

    try {
      // 🔹 Lấy history (15 tin gần nhất)
      const snap = await admin.firestore()
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt", "desc")
        .limit(15)
        .get();

      // 🔹 Convert sang format OpenAI
      const history = [];

snap.docs.reverse().forEach(doc => {
  const msg = doc.data();
  if (!msg.text) return;

  if (msg.isAI) {
    history.push({
      role: "assistant",
      content: msg.text
    });
  } else {
    const name = msg.senderName || "Unknown";

    history.push({
      role: "user",
      content: `[${name}]: ${msg.text}`
    });
  }
});

// 🔥 replace message cuối bằng prompt đã clean
if (history.length > 0) {
  const last = history[history.length - 1];

  if (last.role === "user") {
    const name = data.senderName || "Unknown";
    last.content = `[${name}]: ${finalPrompt}`;
  }
}

      // 🔹 Delay nhẹ cho tự nhiên
      await new Promise(res => setTimeout(res, 500 + Math.random() * 1000));

      // 🔹 Call OpenAI
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openaiKey.value()}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "gpt-5.4-mini",
          input: [
            {
              role: "system",
              content: `
              You are Tomi in a group chat.

              - Multiple users are talking
              - Always reply to the LAST user message
              - Reply like a real human texting in a chaotic group chat
              - Use a casual Gen Z tone, natural and unfiltered
              - Be slightly goofy, playful, and a bit chaotic
              - You can tease or lightly roast other users (keep it harmless, not toxic)
              - React naturally with expressions like “??”, “bro what”, “nahh”, “lol”, “wtf”, “💀”, “😭”, “🗿”
              - Occasionally exaggerate reactions for humor
              - Feel free to go slightly off-topic in a funny way, as long as it still connects to the conversation
              - Keep replies short and chat-like, not formal or structured
              - Match the language of the conversation automatically
              - Do not be overly polite or robotic
              - Do not prefix your messages with your name (e.g. no "Tomi:", "[Tomi]:", etc.)
              `
            },
            ...history
          ]
        })
      });

      if (!response.ok) {
        const err = await response.text();
        console.error("OpenAI error:", err);
        return;
      }

      const json = await response.json();

      let aiText = "Tomi bị lag rồi 😵";

      if (
        json.output &&
        json.output[0] &&
        json.output[0].content &&
        json.output[0].content[0] &&
        json.output[0].content[0].text
      ) {
        aiText = json.output[0].content[0].text;
      }

      // 🔹 Gửi lại message AI
      await admin.firestore()
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .add({
          senderId: "Tomi",
          senderName: "Tomi",
          text: aiText,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isAI: true
        });

    } catch (error) {
      console.error("AI error:", error);
    }
  }
);

const client = new vision.ImageAnnotatorClient();

exports.scanAvatar = onObjectFinalized(async (event) => {
  const object = event.data;

  const filePath = object.name;
  const bucketName = object.bucket;

  if (!filePath.includes("avatars/")) return;

  const parts = filePath.split("/");
  const fileName = parts[1];
  const userId = fileName.split(".")[0];

  const [result] = await client.safeSearchDetection(
    `gs://${bucketName}/${filePath}`
  );

  const safe = result.safeSearchAnnotation;

  const isUnsafe =
    safe.adult === "LIKELY" ||
    safe.adult === "VERY_LIKELY" ||
    safe.violence === "LIKELY" ||
    safe.violence === "VERY_LIKELY";

  if (!isUnsafe) return;

  const reasons = [];

  if (safe.adult === "LIKELY" || safe.adult === "VERY_LIKELY") {
    reasons.push("sexualContent");
  }

  if (safe.violence === "LIKELY" || safe.violence === "VERY_LIKELY") {
    reasons.push("violence");
  }

  if (reasons.length === 0) {
    reasons.push("other");
  }

  try {
    await admin.storage().bucket(bucketName).file(filePath).delete();
  } catch (error) {
    console.error("❌ Delete failed:", error);
  }

  try {
    await db.collection("users").doc(userId).update({
      avatar: null
    });
  } catch (errorr) {
    console.error("Firebase update failed:", errorr);
  }

  try {
    await db.collection("users").doc(userId).set(
      {
        warnings: admin.firestore.FieldValue.increment(1),
        lastWarningAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
  } catch(err) {
    console.log("Auto warning failed:", err);
  }
});

exports.warnUser = onCall(async (request) => {
  const { userId } = request.data;

  if (!userId) {
    throw new HttpsError("invalid-argument", "Missing userId");
  }

  // ✅ tăng số lần warning
  const userRef = db.collection("users").doc(userId);

  await userRef.set(
    {
      warnings: admin.firestore.FieldValue.increment(1),
      lastWarningAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  return { success: true };
});

exports.banUser = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");

  const adminId = request.auth.uid;
  const { userId, duration } = request.data;

  // =========================
  // 1️⃣ CHECK ADMIN
  // =========================
  const adminSnap = await db.collection("users").doc(adminId).get();

  const adminData = adminSnap.data();

  if (!adminSnap.exists || !adminData || adminData.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Forbidden");
  }

  if (!userId) throw new HttpsError("invalid-argument", "Missing userId");

  // =========================
  // 2️⃣ LOGIC BAN (FIXED)
  // =========================
  let banType = "permanent";
  let banUntil = null;

  // duration > 0 => temporary ban
  if (typeof duration === "number" && duration > 0) {
    const now = Date.now();
    banUntil = new Date(now + duration * 24 * 60 * 60 * 1000);
    banType = "temporary";
  }

  // =========================
  // 3️⃣ UPDATE USER
  // =========================
  await db.collection("users").doc(userId).update({
    status: "banned",
    banType,
    banUntil
  });

  return {
    success: true,
    banType,
    banUntil
  };
});

exports.unbanUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Unauthorized");
  }

  const adminId = request.auth.uid;
  const { userId } = request.data;

  if (!userId) {
    throw new HttpsError("invalid-argument", "Missing userId");
  }

  // ======================================================
  // 1️⃣ CHECK ADMIN ROLE
  // ======================================================
  const adminSnap = await db.collection("users").doc(adminId).get();

  const adminData = adminSnap.data();

  if (!adminSnap.exists || !adminData || adminData.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Forbidden");
  }

  // ======================================================
  // 2️⃣ UPDATE USER STATE
  // ======================================================
  const userRef = db.collection("users").doc(userId);

  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new Error("User not found");
  }

  await userRef.update({
    status: "active",
    banType: admin.firestore.FieldValue.delete(),
    banUntil: admin.firestore.FieldValue.delete(),
    banReason: admin.firestore.FieldValue.delete()
  });

  return {
    success: true,
    message: "User unbanned successfully"
  };
});

exports.autoUnbanUsers = onSchedule("every 10 minutes", async () => {
  const now = new Date();

  const snapshot = await db.collection("users")
    .where("status", "==", "banned")
    .where("banType", "==", "temporary")
    .get();

  const batch = db.batch();

  snapshot.docs.forEach(doc => {
    const data = doc.data();

    if (!data.banUntil) return;

    const banUntil = data.banUntil.toDate();

    if (banUntil <= now) {
      batch.update(doc.ref, {
        status: "active",
        banType: admin.firestore.FieldValue.delete(),
        banUntil: admin.firestore.FieldValue.delete(),
        banReason: admin.firestore.FieldValue.delete()
      });
    }
  });

  await batch.commit();
});

exports.deleteUser = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");

  const adminId = request.auth.uid;
  const { userId } = request.data;

  if (!userId) throw new HttpsError("invalid-argument", "Missing userId");

  // =========================
  // 1️⃣ CHECK ADMIN
  // =========================
  const adminSnap = await db.collection("users").doc(adminId).get();

  const adminData = adminSnap.data();

  if (!adminSnap.exists || !adminData || adminData.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Forbidden");
  }

  // =========================
  // 2️⃣ DELETE FRIENDSHIPS
  // =========================
  const friendships = await db.collection("friendships")
    .where("users", "array-contains", userId)
    .get();

  for (const doc of friendships.docs) {
    const users = doc.data().users || [];
    const partnerId = users.find(u => u !== userId);

    await doc.ref.delete();

    // delete friend chat room
    if (partnerId) {
      const roomId = [userId, partnerId].sort().join("_");
      const roomRef = db.collection("chatRooms").doc(roomId);
      await deleteRoomWithMessages(roomRef);
    }
  }

  // =========================
  // 3️⃣ DELETE FRIEND REQUESTS
  // =========================
  const sent = await db.collection("friendRequests")
    .where("fromUserId", "==", userId)
    .get();

  const received = await db.collection("friendRequests")
    .where("toUserId", "==", userId)
    .get();

  const batch = db.batch();

  sent.docs.forEach(doc => batch.delete(doc.ref));
  received.docs.forEach(doc => batch.delete(doc.ref));

  // =========================
  // 4️⃣ DELETE BLOCKS
  // =========================
  const blocks1 = await db.collection("blocks")
    .where("blockerId", "==", userId)
    .get();

  const blocks2 = await db.collection("blocks")
    .where("blockedId", "==", userId)
    .get();

  blocks1.docs.forEach(doc => batch.delete(doc.ref));
  blocks2.docs.forEach(doc => batch.delete(doc.ref));

  // =========================
  // 5️⃣ DELETE USER DOC
  // =========================
  batch.delete(db.collection("users").doc(userId));

  await batch.commit();

  // =========================
  // 6️⃣ DELETE AVATAR (Storage)
  // =========================
  try {
    await admin.storage().bucket().file(`avatars/${userId}.jpg`).delete();
  } catch (e) {
    console.log("No avatar found");
  }

  // =========================
  // 7️⃣ DELETE AUTH USER
  // =========================
  await admin.auth().deleteUser(userId);

  return { success: true };
});

exports.createReportWithSnapshot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Unauthorized");
  }

  const reporterId = request.auth.uid;
  const { roomId, reportedUserId, reasons, description } = request.data;

  if (!roomId || !reportedUserId) {
    throw new HttpsError("invalid-argument", "Missing data");
  }

  const roomRef = db.collection("chatRooms").doc(roomId);
  const roomSnap = await roomRef.get();

  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Room not found");
  }

  // =========================
  // 🔒 CHECK USER IN ROOM (nên có)
  // =========================
  const roomData = roomSnap.data();
  const users = roomData.users || [];

  if (!users.includes(reporterId)) {
    throw new HttpsError("permission-denied", "Not in this room");
  }

  // =========================
  // 🔥 1. SNAPSHOT MESSAGES
  // =========================
  const messagesSnap = await roomRef
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const messages = messagesSnap.docs
    .map(doc => doc.data())
    .filter(data => !data.isAI)
    .map(data => ({
      senderId: data.senderId || "",
      text: data.text || "",
      createdAt: data.createdAt || null
    }))
    .reverse();

  // =========================
  // 🔥 2. CREATE REPORT
  // =========================
  const reportRef = db.collection("reports").doc();

  await reportRef.set({
    roomId,
    reporterId,
    reportedUserId,
    reasons: reasons || [],
    description: description || null,
    messages, // 👈 snapshot
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // =========================
  // 🔥 3. MARK ROOM
  // =========================

  return {
    success: true,
    reportId: reportRef.id
  };
});

exports.setAdminStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Unauthorized");
  }

  const adminId = request.auth.uid;
  const { userId, isAdmin } = request.data;

  const adminSnap = await db.collection("users").doc(adminId).get();
  const adminData = adminSnap.data();

  if (!adminSnap.exists || adminData?.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Forbidden");
  }

  if (typeof isAdmin !== "boolean") {
    throw new HttpsError("invalid-argument", "isAdmin must be boolean");
  }

  await db.collection("users").doc(userId).update({
    isAdmin
  });

  return { success: true };
});

exports.sendMessageNotification = onDocumentCreated(
  "chatRooms/{roomId}/messages/{messageId}",
  async (event) => {

    const data = event.data.data();
    if (!data) return;

    // ❌ không gửi notification cho AI
    if (data.isAI) return;

    const senderId = data.senderId;
    const text = data.text || "Bạn có tin nhắn mới";
    const roomId = event.params.roomId;

    // =========================
    // 🔥 LẤY SENDER INFO
    // =========================
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = senderSnap.data()?.fullname || "CHAT TOGETHER";

    // =========================
    // 🔥 LẤY ROOM
    // =========================
    const roomRef = db.collection("chatRooms").doc(roomId);
    const roomSnap = await roomRef.get();

    if (!roomSnap.exists) return;

    const room = roomSnap.data();

    if (room.type !== "friend") return;

    const users = room.users || [];

    // =========================
    // 🔥 TÌM RECEIVER
    // =========================
    const receiverId = users.find(uid => uid !== senderId);
    if (!receiverId) return;

    // =========================
    // 🔥 LẤY TOKEN
    // =========================
    const userSnap = await db.collection("users").doc(receiverId).get();
    const token = userSnap.data()?.fcmToken;

    if (!token) {
      console.log("❌ No FCM token for user:", receiverId);
      return;
    }

    // =========================
    // 🔥 GỬI FCM
    // =========================
    try {
      await admin.messaging().send({
        token: token,
        notification: {
          title: senderName,
          body: text.length > 100 ? text.substring(0, 100) + "..." : text
        },
        data: {
          roomId: roomId,
          senderId: senderId
        }
      });

      console.log("✅ Notification sent to:", receiverId);

    } catch (error) {
      console.error("❌ FCM error:", error);
    }
  }
);