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
                    ToolIntroView(intro: .videos) {
                        Button("Pokaż filmy") {
                            Haptics.selection()
                            Task { await flow.start() }
                        }
                        .buttonStyle(.primary)
                    }

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
                            ProgressView(value: progress).progressViewStyle(CapsuleBarStyle())
                            Text("Pobieram z iCloud…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .compressing(let progress):
                            ProgressView(value: progress).progressViewStyle(CapsuleBarStyle())
                            Text("Kompresuję…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button("Przerwij po tym wideo") {
                            Haptics.selection()
                            flow.stop()
                        }
                        .buttonStyle(.neutral)
                        .controlSize(.small)
                        .padding(.top)
                    }
                    .padding(.horizontal, 40)

                case .copiesReady(let count, let savedBytes):
                    VStack(spacing: 16) {
                        IconCircle(systemImage: "checkmark", size: 88)
                        Text("Skompresowane kopie zapisane: \(count)")
                            .font(.title3.weight(.heavy))
                            .multilineTextAlignment(.center)
                        InfoRow(
                            systemImage: "checkmark.shield",
                            text: "Kopie są już w bibliotece. Teraz usuniemy oryginały, co zwolni ok. \(formatBytes(savedBytes)). Trafią do „Ostatnio usuniętych”."
                        )
                        HoldToConfirmButton(title: "Usuń oryginały", action: { Task { await flow.deleteOriginals() } })
                        Button("Zostaw oryginały") {
                            Haptics.selection()
                            Task { await flow.keepOriginals() }
                        }
                        .buttonStyle(.secondary)
                    }
                    .padding(.horizontal, 18)

                case .deletingOriginals:
                    ProgressView("Usuwam oryginały…")
                }
            }
            .screenBackground()
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
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(flow.videos) { item in
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                InfoRow(systemImage: "checkmark.shield", text: "Miejsce zwolni się dopiero po opróżnieniu albumu „Ostatnio usunięte”.")
                Button("Kompresuj zaznaczone (\(flow.selected.count)) · ~\(ByteCountFormatter.string(fromByteCount: selectedSavings, countStyle: .file))") {
                    Haptics.selection()
                    flow.compressSelected()
                }
                .buttonStyle(.primary)
                .disabled(flow.selected.isEmpty)
            }
            .padding(16)
            .background(Color.appBackground)
        }
    }
}

private struct VideoRow: View {
    let item: VideoItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AssetThumbnail(asset: item.asset, targetSide: 128)
                .frame(width: 60, height: 60)
                .overlay(alignment: .bottomTrailing) {
                    Text(Duration.seconds(item.asset.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(3)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.headline.weight(.heavy).monospacedDigit())
                if item.isCompressionCandidate {
                    Text("Kompresja: ~\(ByteCountFormatter.string(fromByteCount: item.estimatedSavings, countStyle: .file)) mniej")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.accent)
                } else if let reason = item.skipReason {
                    Text(LocalizedStringKey(reason))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if item.isCompressionCandidate {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.accent) : AnyShapeStyle(.tertiary))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(isSelected ? "Odznacz" : "Zaznacz"))
            }
        }
        .card(radius: 20, padding: 8)
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
                .padding(18)
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

extension ToolIntro {
    static var videos: ToolIntro {
        ToolIntro(
            title: "Duże wideo",
            systemImage: "film",
            lead: "Pokazuje filmy od największych. Możesz je obejrzeć, usunąć albo skompresować.",
            steps: [
                ("play.circle", "**Stuknij film**, by go obejrzeć. W odtwarzaczu przytrzymaj „Usuń wideo”."),
                ("checkmark.circle", "**Zaznacz** filmy do kompresji (HEVC 1080p). Przy każdym widać szacowaną oszczędność."),
                ("doc.on.doc", "**Najpierw zapisujemy kopię.** O usunięciu oryginałów zdecydujesz potem."),
                ("slowmo", "**Slow motion i tryb kinowy** pomijamy, żeby nie zepsuć efektów."),
            ],
            infos: [InfoRow(systemImage: "checkmark.shield", text: "Miejsce zwolni się dopiero po opróżnieniu albumu „Ostatnio usunięte”.")]
        )
    }
}
