//
//  ProfileImageManager.swift
//  nameRunner
//

import UIKit
import SwiftUI

@Observable
final class ProfileImageManager {
    var profileImage: UIImage?

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return }
        profileImage = image
    }

    func save(_ image: UIImage) {
        profileImage = image
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func delete() {
        profileImage = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
