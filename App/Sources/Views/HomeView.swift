import SwiftUI

struct HomeView: View {
    @State private var showTrain = false
    @State private var showDelete = false
    @State private var showBlur = false
    @State private var showDuplicates = false
    @State private var showVideos = false
    @State private var showSettings = false

    @State private var modelTrained = false
    @State private var trainingSetCount = 0
    @State private var totalDeleted = 0
    @State private var savedBytes: Int64 = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text(verbatim: "SmartCleanup")
                    .font(.largeTitle.bold())

                Text(modelTrained ? "Model wytrenowany ✅" : "Model nie jest jeszcze wytrenowany")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                StatsRow(trainingSetCount: trainingSetCount, totalDeleted: totalDeleted, savedBytes: savedBytes)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Haptics.selection()
                        showTrain = true
                    } label: {
                        MenuButtonLabel(
                            title: "Ucz model",
                            subtitle: "Oznacz kilka zdjęć jako Zachowaj / Usuń",
                            systemImage: "brain.head.profile"
                        )
                    }

                    Button {
                        Haptics.selection()
                        showDelete = true
                    } label: {
                        MenuButtonLabel(
                            title: "Usuń zdjęcia",
                            subtitle: "Przejrzyj propozycje modelu i posprzątaj galerię",
                            systemImage: "trash"
                        )
                    }

                    Button {
                        Haptics.selection()
                        showBlur = true
                    } label: {
                        MenuButtonLabel(
                            title: "Wykryj rozmycie",
                            subtitle: "Znajdź nieostre zdjęcia i usuń je z galerii",
                            systemImage: "wand.and.rays"
                        )
                    }

                    Button {
                        Haptics.selection()
                        showDuplicates = true
                    } label: {
                        MenuButtonLabel(
                            title: "Usuń duplikaty",
                            subtitle: "Znajdź podobne zdjęcia (np. serie ujęć) i wybierz, które zostawić",
                            systemImage: "square.on.square"
                        )
                    }

                    Button {
                        Haptics.selection()
                        showVideos = true
                    } label: {
                        MenuButtonLabel(
                            title: "Duże wideo",
                            subtitle: "Obejrzyj, usuń lub skompresuj największe filmy",
                            systemImage: "film"
                        )
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fullScreenCover(isPresented: $showTrain) { TrainView() }
            .fullScreenCover(isPresented: $showDelete) { DeleteView() }
            .fullScreenCover(isPresented: $showBlur) { BlurReviewView() }
            .fullScreenCover(isPresented: $showDuplicates) { DuplicateReviewView() }
            .fullScreenCover(isPresented: $showVideos) { LargeVideosView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        // Refresh whenever this screen (re)appears — including right after a fullScreenCover
        // dismisses — rather than trusting SwiftUI to re-run computed properties on its own.
        .onAppear(perform: refreshStats)
        .onChange(of: showTrain) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showDelete) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showBlur) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showDuplicates) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showVideos) { _, isShowing in if !isShowing { refreshStats() } }
    }

    private func refreshStats() {
        modelTrained = ClassifierTrainer.hasSavedModel()
        let counts = TrainingDataStore.sampleCounts()
        trainingSetCount = counts.keep + counts.delete
        totalDeleted = StatsStore.totalDeleted
        savedBytes = StatsStore.totalBytesFreedEstimate
    }
}

private struct StatsRow: View {
    let trainingSetCount: Int
    let totalDeleted: Int
    let savedBytes: Int64

    private var savedSpaceText: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(trainingSetCount)", label: "do treningu", systemImage: "photo.stack")
            StatTile(value: "\(totalDeleted)", label: "usuniętych", systemImage: "trash")
            StatTile(value: "~\(savedSpaceText)", label: "oszczędzone", systemImage: "internaldrive")
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MenuButtonLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
