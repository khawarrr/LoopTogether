//
//  AuthView.swift
//  nameRunner
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Branding
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)
                        Text("LoopTogether")
                            .font(.largeTitle.bold())
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    // Sign In / Sign Up toggle
                    Picker("Mode", selection: $isSignUp) {
                        Text("Sign In").tag(false)
                        Text("Sign Up").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Input fields
                    VStack(spacing: 12) {
                        if isSignUp {
                            TextField("Name", text: $name)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)

                        if isSignUp {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Email / password action button
                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isLoading)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.tertiary)
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)

                    // Sign in with Apple
                    SignInWithAppleButton(.continue) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            guard let appleCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                                  let nonce = currentNonce else { return }
                            Task {
                                do {
                                    try await authManager.signInWithApple(credential: appleCredential, nonce: nonce)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Google sign-in
                    Button {
                        Task {
                            do {
                                try await authManager.signInWithGoogle()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(Color(.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    Button("Continue without an account") {
                        dismiss()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        if isSignUp, password != confirmPassword {
            errorMessage = "Passwords don't match."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    try await authManager.updateDisplayName(name)
                }
            } else {
                try await authManager.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Nonce helpers

private func randomNonceString(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}

private func sha256(_ input: String) -> String {
    let data = SHA256.hash(data: Data(input.utf8))
    return data.compactMap { String(format: "%02x", $0) }.joined()
}
