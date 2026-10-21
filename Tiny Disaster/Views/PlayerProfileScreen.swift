import SwiftUI
import UIKit
import PhotosUI

struct PlayerAvatar: View {
    let data: Data?
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.townCream
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.43, weight: .medium))
                        .foregroundStyle(Color.townMoss)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.townInk.opacity(0.1), lineWidth: 1))
        .accessibilityLabel(data == nil ? "Default player avatar" : "Player profile photo")
    }
}

struct PlayerProfileScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @StateObject private var model = PlayerProfileViewModel()
    @State private var selection: PhotosPickerItem?

    var body: some View {
        let photoTitle = player.avatarData == nil ? "Choose a photo" : "Change photo"
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Player profile", title: "Make it yours.", detail: "Choose a photo for your place in the neighborhood.")
                PaperCard {
                    VStack(spacing: 19) {
                        PlayerAvatar(data: player.avatarData, size: 128)
                            .padding(.top, 8)
                        VStack(spacing: 6) {
                            Text("Your little corner")
                                .font(.system(.title2, design: .serif, weight: .bold))
                            Text("A familiar face for your next clever idea.")
                                .font(.caption)
                                .foregroundStyle(Color.townMuted)
                                .multilineTextAlignment(.center)
                        }
                        PhotosPicker(selection: $selection, matching: .images, preferredItemEncoding: .automatic) {
                            Label(photoTitle, systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(TownButtonStyle())
                        .disabled(model.isImporting)
                        if model.isImporting {
                            ProgressView("Preparing your photo…")
                                .font(.caption)
                                .tint(.townMoss)
                        }
                        if player.avatarData != nil {
                            Button(role: .destructive) {
                                model.removePhoto(from: player)
                                selection = nil
                            } label: {
                                Label("Remove photo", systemImage: "trash")
                                    .font(.subheadline.weight(.medium))
                                    .frame(minHeight: 44)
                            }
                            .foregroundStyle(Color.townCoral)
                            .disabled(model.isImporting)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "Your journey so far")
                        Label("\(player.completed) of 20 levels completed", systemImage: "checkmark.circle")
                        Label("\(player.totalStars) of 60 stars collected", systemImage: "star.fill")
                            .foregroundStyle(Color.townGold)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                Text("Your photo is saved on this device. You can replace or remove it at any time. Starting a fresh journey keeps your profile photo.")
                    .font(.caption)
                    .foregroundStyle(Color.townMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
        .navigationTitle("Player profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selection) {
            guard let item = selection else { return }
            await model.importPhoto(item, into: player)
            if selection == item { selection = nil }
        }
        .alert("Photo could not be updated", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
    }
}
