import Foundation
import Combine
import PhotosUI
import SwiftUI

@MainActor
final class PlayerProfileViewModel: ObservableObject {
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?
    private var activeImport: UUID?

    func importPhoto(_ item: PhotosPickerItem?, into player: PlayerStore) async {
        guard let item else { return }
        let token = UUID()
        activeImport = token
        isImporting = true
        errorMessage = nil
        defer {
            if activeImport == token {
                activeImport = nil
                isImporting = false
            }
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ProfilePhotoError.unreadableImage }
            try Task.checkCancellation()
            let portrait = try await Task.detached(priority: .userInitiated) {
                try ProfileImageProcessor.portrait(from: data)
            }.value
            try Task.checkCancellation()
            guard activeImport == token else { return }
            try player.replaceProfilePhoto(with: portrait)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, activeImport == token else { return }
            errorMessage = "Your photo could not be loaded or saved. Please choose an image available on your device and try again."
        }
    }

    func removePhoto(from player: PlayerStore) {
        guard !isImporting else { return }
        do {
            try player.removeProfilePhoto()
        } catch {
            errorMessage = "Your photo could not be removed. Please try again."
        }
    }
}
