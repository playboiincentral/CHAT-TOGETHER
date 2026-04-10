const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

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

  // 🔥 Lấy gender 1 lần
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new Error("User not found");

  const gender = userDoc.data().gender;
  if (!gender) throw new Error("Missing gender");

  const myQueueKey = gender === "male" ? "male" : "female";
  const targetQueueKey = gender === "male" ? "female" : "male";

  let createdRoomId = null;

  // 🔥 BLOCK LIST
const blockSnapshot = await db.collection("blocks")
  .where("blockerId", "==", userId)
  .get();

const blockedSet = new Set(
  blockSnapshot.docs.map(doc => doc.data().blockedId)
);

// 🔥 REVERSE BLOCK (người khác block mình)
const blockedBySnapshot = await db.collection("blocks")
  .where("blockedId", "==", userId)
  .get();

blockedBySnapshot.docs.forEach(doc => {
  blockedSet.add(doc.data().blockerId);
});

// 🔥 FRIEND LIST
const friendSnapshot = await db.collection("friendships")
  .where("users", "array-contains", userId)
  .get();

const friendSet = new Set();

friendSnapshot.docs.forEach(doc => {
  const users = doc.data().users || [];
  const other = users.find(u => u !== userId);
  if (other) friendSet.add(other);
});

  await db.runTransaction(async (transaction) => {
    const queueSnap = await transaction.get(queueRef);

    let data = queueSnap.exists
      ? queueSnap.data()
      : { male: [], female: [] };

    let myQueue = data[myQueueKey] || [];
    let targetQueue = data[targetQueueKey] || [];

    // ❌ tránh join trùng
    const alreadyInQueue =
      myQueue.includes(userId) || targetQueue.includes(userId);

    if (alreadyInQueue) return;

    // 🔥 MATCH NGAY (O(1))
    if (targetQueue.length > 0) {

      const MAX_CHECK = 10;
      
  let partnerId = null;

  for (let i = 0; i < Math.min(MAX_CHECK, targetQueue.length); i++) {
    const candidate = targetQueue[i];

    const isBlocked = blockedSet.has(candidate);
    const isFriend = friendSet.has(candidate);

    if (!isBlocked && !isFriend) {
      partnerId = candidate;
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
      hasReport: false,
      lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: null,
      lastMessageSenderId: null,
      lastMessageAt: null
    });

    data[targetQueueKey] = targetQueue;

  } else {
    // ❌ không có ai phù hợp → vào queue
    myQueue.push(userId);
    data[myQueueKey] = myQueue;
  }

} else {
  myQueue.push(userId);
  data[myQueueKey] = myQueue;
}

    transaction.set(queueRef, data);
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

    let users = queueDoc.data().users || [];
    users = users.filter(uid => uid !== userId);

    transaction.set(queueRef, { users });
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
    hasReport: false,
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
// 3️⃣ DETECT INACTIVE ROOMS (Heartbeat timeout)
// =======================================================

exports.detectInactiveRooms = onSchedule(
  "every 1 minutes",
  async () => {

    const timeoutTime = new Date(Date.now() - 45 * 1000);

    const snapshot = await db.collection("chatRooms")
      .where("status", "==", "active")
      .where("type", "==", "random")
      .get();

    for (const doc of snapshot.docs) {

      const room = doc.data();
      const lastActivity = room.lastActivityAt?.toDate?.();

      if (!lastActivity) continue;

      if (lastActivity < timeoutTime) {

        await doc.ref.update({
          status: "ended",
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          endedBy: "system"
        });

        console.log("Room ended due to inactivity:", doc.id);
      }
    }
  }
);

// =======================================================
// 4️⃣ CLEANUP ENDED ROOMS
//    - Xoá nếu không có report
//    - Giữ lại nếu hasReport = true
// =======================================================

exports.cleanupEndedRooms = onSchedule(
  "every 2 minutes",
  async () => {

    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);

    const snapshot = await db.collection("chatRooms")
      .where("status", "==", "ended")
      .where("type", "==", "random")
      .where("endedAt", "<", twoMinutesAgo)
      .where("hasReport", "==", false)
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
};

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

async function isBlocked(db, userA, userB) {
  const snapshot = await db.collection("blocks")
    .where("blockerId", "in", [userA, userB])
    .get();

  return snapshot.docs.some(doc => {
    const data = doc.data();
    return (
      (data.blockerId === userA && data.blockedId === userB) ||
      (data.blockerId === userB && data.blockedId === userA)
    );
  });
}

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

    const [user1Doc, user2Doc, friendshipDoc] = await Promise.all([
      transaction.get(userRef1),
      transaction.get(userRef2),
      transaction.get(friendshipRef)
    ]);

    if (!friendshipDoc.exists) return;

    // 🔥 xoá friendship
    transaction.delete(friendshipRef);

    // 🔥 giảm count
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

    if (!data || data.isAI) return;
    if (!data.text) return;

    const mentionRegex = /@togi\b/i;

    // ❌ không gọi Togi → ignore
    if (!mentionRegex.test(data.text)) return;

    // 🔥 remove @Togi
    const prompt = data.text.replace(mentionRegex, "").trim();
    if (!prompt) return;

    try {
  await new Promise(res => setTimeout(res, 500 + Math.random() * 1000));

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey.value()}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input: [
        {
          role: "system",
          content: `
You are Togi, a Gen Z chat buddy.
- Reply short
- Casual like texting
- Use emoji sometimes
- Reply in same language as user (Vietnamese or English)
`
        },
        {
          role: "user",
          content: prompt
        }
      ]
    })
  });

  // ❗ check lỗi thật
  if (!response.ok) {
    const err = await response.text();
    console.error("OpenAI error:", err);
    return;
  }

  const json = await response.json();

  console.log("AI RAW:", JSON.stringify(json, null, 2)); // 🔥 debug

  const aiText =
    json.output?.[0]?.content?.[0]?.text ||
    "Togi bị lag rồi 😵";

  await admin.firestore()
    .collection("chatRooms")
    .doc(event.params.roomId)
    .collection("messages")
    .add({
      senderId: "Togi",
      text: aiText,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isAI: true
    });

} catch (error) {
  console.error("AI error:", error);
}
  }
);