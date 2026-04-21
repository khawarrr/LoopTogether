//
//  EditProfileView.swift
//  nameRunner
//

import SwiftUI
import FirebaseAuth
import PhotosUI

enum Gender: String, CaseIterable, Identifiable {
    case preferNotToSay = "Prefer not to say"
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

struct EditProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileImageManager.self) private var imageManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userGender") private var gender: String = Gender.preferNotToSay.rawValue

    @State private var displayName: String = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                profileCircle
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.blue)
                                    .background(Color(uiColor: .systemBackground), in: Circle())
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Display Name") {
                    TextField("Enter your name", text: $displayName)
                        .autocapitalization(.words)
                }

                Section("Email") {
                    Text(authManager.currentUser?.email ?? "—")
                        .foregroundStyle(.secondary)
                }

                Section("Gender") {
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            Text(g.rawValue).tag(g.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if authManager.isEmailPasswordUser {
                    Section {
                        SecureField("Current password", text: $currentPassword)
                            .textContentType(.password)
                        SecureField("New password", text: $newPassword)
                            .textContentType(.newPassword)
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    } header: {
                        Text("Change Password")
                    } footer: {
                        Text("Leave blank to keep your current password.")
                    }
                } else {
                    Section("Change Password") {
                        Label("Password is managed by your Google account.", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
            .onAppear {
                displayName = authManager.displayName ?? ""
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        imageManager.save(image)
                    }
                }
            }
        }
    }

    private var profileCircle: some View {
        Group {
            if let img = imageManager.profileImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 2))
    }

    private func save() async {
        errorMessage = nil

        // Validate password fields if the user filled them in
        let changingPassword = !newPassword.isEmpty || !currentPassword.isEmpty
        if changingPassword {
            guard !currentPassword.isEmpty else {
                errorMessage = "Enter your current password to change it."
                return
            }
            guard newPassword == confirmPassword else {
                errorMessage = "New passwords don't match."
                return
            }
            guard newPassword.count >= 6 else {
                errorMessage = "New password must be at least 6 characters."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.updateDisplayName(displayName)
            if changingPassword {
                try await authManager.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
