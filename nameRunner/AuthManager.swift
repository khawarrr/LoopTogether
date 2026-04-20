//
//  AuthManager.swift
//  nameRunner
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit

@Observable
final class AuthManager {
    var currentUser: User?
    var isSignedIn: Bool { currentUser != nil }

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Email / Password

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        currentUser = result.user
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUser = result.user
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        currentUser = nil
    }

    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        // Best-effort Firestore cleanup — don't block deletion if it fails
        try? await FirestoreService.deleteUserData(uid: user.uid)
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
    }

    // MARK: - Profile

    var displayName: String? { currentUser?.displayName }
    var isEmailPasswordUser: Bool {
        currentUser?.providerData.contains(where: { $0.providerID == "password" }) ?? false
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = currentUser else { return }
        let request = user.createProfileChangeRequest()
        request.displayName = name.trimmingCharacters(in: .whitespaces)
        try await request.commitChanges()
        try await Auth.auth().currentUser?.reload()
        // Nil-then-reassign forces @Observable to detect the change
        currentUser = nil
        currentUser = Auth.auth().currentUser
    }

    func updatePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = currentUser, let email = user.email else { return }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        try await user.updatePassword(to: newPassword)
    }

    // MARK: - Google

    @MainActor
    func signInWithGoogle() async throws {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = scene.windows.first?.rootViewController
        else { throw GoogleSignInError.noRootViewController }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let firebaseResult = try await Auth.auth().signIn(with: credential)
        currentUser = firebaseResult.user
    }
}

enum GoogleSignInError: LocalizedError {
    case noRootViewController
    case missingToken
    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Unable to present Google Sign-In."
        case .missingToken: return "Google Sign-In failed. Please try again."
        }
    }
}
