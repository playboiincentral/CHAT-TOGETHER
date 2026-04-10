//
//  LoginView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        ZStack {
            
            // Background
            LinearGradient(
                colors: [.pink, .pink, .pink],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Spacer()
                
                HStack(spacing: 12) {
                    
                    Image("chattogether_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("chat")
                        Text("together")
                    }
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    
                    VStack(spacing: 6) {
                        
                        Text("By continuing, you agree to our")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 4) {
                            
                            Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .underline()
                                .background(
                                    Rectangle()
                                        .fill(.ultraThinMaterial)
                                )
                            
                            Text("and")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .underline()
                                .background(
                                    Rectangle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                    .multilineTextAlignment(.center)
                    
                    // Apple Button (chuẩn Apple)
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            authVM.handleAppleRequest(request)
                        },
                        onCompletion: { result in
                            authVM.handleAppleCompletion(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    
                    // Google Button
                    Button {
                        Task {
                            await authVM.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                            Text("Sign in with Google")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                }
            }
            .padding()
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    LoginView()
}
