import AVKit
import Photos
import SwiftUI

/// Videos by real file size: tap to watch (and hold-to-delete), select candidates to compress.
struct LargeVideosView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = VideoFlow()
    @State private var playing: VideoItem?

    var body: some View {
        NavigationStack {
            Group {
                switch flow.stage {
                case .checkingAccess:
                    ProgressView().task { await flow.start() }

                case .accessDenied:
                    ContentUnavailableView(
                        "Brak dostępu do zdjęć",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("Włącz dostęp do zdjęć w Ustawieniach, aby korzystać z aplikacji.")
                    )

                case .loading:
                    ProgressView("Sprawdzam rozmiary wideo…")

                case .empty:
                    ContentUnavailableView("Brak wideo", systemImage: "film")

                case .list:
                    VideoListView(flow: flow, onPlay: { playing = $0 })

                case .compressing(let index, let total, let phase):
                    VStack(spacing: 12) {
                        Text("Wideo \(index)/\(total)")
                            .font(.headline)
                        switch phase {
                        case .downloading(let progress):
                            ProgressView(value: progress)
                            Text("Pobieram z iCloud…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .compressing(let progress):
                            ProgressView(value: progress)
                            Text("Kompresuję…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button("Przerwij po tym wideo") {
                            Haptics.selection()
                            flow.stop()
                        }
                        .padding(.top)
                    }
                    .padding(.horizontal, 40)

                case .copiesReady(let count, let savedBytes):
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("Skompresowane kopie zapisane: \(count)")
                            .font(.headline)
                        Text("Kopie są już w bibliotece. Teraz usuniemy oryginały, co zwolni ok. \(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)). Trafią do „Ostatnio usuniętych”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        HoldToConfirmButton(title: "Usuń oryginały", action: { Task { await flow.deleteOriginals() } })
                        Button("Zostaw oryginały") {
                            Haptics.selection()
                            Task { await flow.keepOriginals() }
                        }
                    }
                    .padding(.horizontal, 32)

                case .deletingOriginals:
                    ProgressView("Usuwam oryginały…")
                }
            }
            .navigationTitle("Duże wideo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        Haptics.selection()
                        dismiss()
                    }
                }
                if flow.stage == .list, !flow.candidates.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(flow.selected.count == flow.candidates.count ? "Odznacz" : "Zaznacz wszystkie") {
                            Haptics.selection()
                            flow.toggleSelectAll()
                        }
                    }
                }
            }
            .sheet(item: $playing) { item in
                VideoPlayerSheet(item: item) {
                    Task {
                        await flow.delete(item)
                        playing = nil
                    }
                }
            }
            .alert("Błąd", isPresented: Binding(
                get: { flow.errorMessage != nil },
                set: { if !$0 { flow.errorMessage = nil } }
            )) {
                Button("OK") { flow.errorMessage = nil }
            } message: {
                Text(flow.errorMessage ?? "")
            }
            .alert("Gotowe", isPresented: Binding(
                get: { flow.result != nil },
                set: { if !$0 { flow.result = nil } }
            )) {
                Button("OK") { flow.result = nil }
            } message: {
                if let result = flow.result {
                    if result.originalsDeleted {
                        Text("Skompresowane wideo: \(result.compressedCount). Odzyskano \(ByteCountFormatter.string(fromByteCount: result.savedBytes, countStyle: .file)).")
                    } else {
                        Text("Zapisane skompresowane kopie: \(result.compressedCount). Oryginały zostały w bibliotece.")
                    }
                }
            }
        }
    }
}

private struct VideoListView: View {
    @Bindable var flow: VideoFlow
    let onPlay: (VideoItem) -> Void

    private var selectedSavings: Int64 {
        flow.videos.filter { flow.selected.contains($0.id) }.reduce(0) { $0 + $1.estimatedSavings }
    }

    var body: some View {
        List(flow.videos) { item in
            VideoRow(
                item: item,
                isSelected: flow.selected.contains(item.id),
                onToggle: {
                    Haptics.selection()
                    flow.toggleSelection(item)
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.selection()
                onPlay(item)
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text("Miejsce zwolni się dopiero po opróżnieniu albumu „Ostatnio usunięte”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Haptics.selection()
                    flow.compressSelected()
                } label: {
                    Text("Kompresuj zaznaczone (\(flow.selected.count)) · ~\(ByteCountFormatter.string(fromByteCount: selectedSavings, countStyle: .file))")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(flow.selected.isEmpty)
            }
            .padding()
            .background(.bar)
        }
    }
}

private struct VideoRow: View {
    let item: VideoItem
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var image: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.gray.opacity(0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Text(Duration.seconds(item.asset.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .padding(2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.headline.monospacedDigit())
                if item.isCompressionCandidate {
                    Text("Kompresja: ~\(ByteCountFormatter.string(fromByteCount: item.estimatedSavings, countStyle: .file)) mniej")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let reason = item.skipReason {
                    Text(LocalizedStringKey(reason))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if item.isCompressionCandidate {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(isSelected ? "Odznacz" : "Zaznacz"))
            }
        }
        .task {
            image = await PhotoLibraryService.requestImage(for: item.asset, targetSize: CGSize(width: 128, height: 128))
        }
    }
}

private struct VideoPlayerSheet: View {
    let item: VideoItem
    let onDelete: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HoldToConfirmButton(title: "Usuń wideo (\(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)))", action: onDelete)
            .padding()
        }
        .task {
            guard let playerItem = await PhotoLibraryService.requestPlayerItem(for: item.asset) else { return }
            // Default .soloAmbient session is silenced by the ring/silent switch.
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            player = AVPlayer(playerItem: playerItem)
            player?.play()
        }
        .onDisappear { player?.pause() }
    }
}
