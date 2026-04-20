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
