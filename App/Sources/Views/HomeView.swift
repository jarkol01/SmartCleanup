import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showTrain = false
    @State private var showDelete = false
    @State private var showBlur = false
    @State private var showDuplicates = false
    @State private var showVideos = false
    @State private var showSettings = false

    @State private var keepCount = 0
    @State private var deleteCount = 0
    @State private var totalDeleted = 0
    @State private var savedBytes: Int64 = 0
    @State private var storage: StorageSnapshot?
    @State private var storageHistory: [StorageSnapshot] = []

    private var modelReady: Bool {
        keepCount >= ClassifierTrainer.minSamplesPerClass && deleteCount >= ClassifierTrainer.minSamplesPerClass
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header

                if savedBytes > 0 || totalDeleted > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("oszczędzone").font(.subheadline.weight(.bold))
                        Text(verbatim: "~\(formatBytes(savedBytes))")
                            .font(.system(size: 40, weight: .heavy).monospacedDigit())
                        Text("\(Text(totalDeleted, format: .number).bold().foregroundStyle(.primary)) usuniętych")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 26, fill: .accentSoft, padding: 18)
                }

                if let storage {
                    StorageCard(current: storage, history: storageHistory)
                }

                if modelReady {
                    SectionHeader(title: "Twój model").padding(.top, 4)
                    modelCard
                } else {
                    startCard
                }

                SectionHeader(title: "Sprzątanie").padding(.top, 4)
                ToolRow(
                    title: "Usuń zdjęcia",
                    subtitle: "Przejrzyj propozycje modelu i posprzątaj galerię",
                    systemImage: "trash",
                    ai: true,
                    locked: !modelReady
                ) { showDelete = true }
                ToolRow(
                    title: "Wykryj rozmycie",
                    subtitle: "Znajdź nieostre zdjęcia i usuń je z galerii",
                    systemImage: "camera.aperture"
                ) { showBlur = true }
                ToolRow(
                    title: "Usuń duplikaty",
                    subtitle: "Znajdź podobne zdjęcia (np. serie ujęć) i wybierz, które zostawić",
                    systemImage: "square.on.square"
                ) { showDuplicates = true }
                ToolRow(
                    title: "Duże wideo",
                    subtitle: "Obejrzyj, usuń lub skompresuj największe filmy",
                    systemImage: "film"
                ) { showVideos = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $showTrain) { TrainView() }
        .fullScreenCover(isPresented: $showDelete) { DeleteView() }
        .fullScreenCover(isPresented: $showBlur) { BlurReviewView() }
        .fullScreenCover(isPresented: $showDuplicates) { DuplicateReviewView() }
        .fullScreenCover(isPresented: $showVideos) { LargeVideosView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        // Refresh whenever this screen (re)appears, including right after a fullScreenCover
        // dismisses, rather than trusting SwiftUI to re-run computed properties on its own.
        .onAppear(perform: refreshStats)
        .onChange(of: showTrain) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showDelete) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showBlur) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showDuplicates) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: showVideos) { _, isShowing in if !isShowing { refreshStats() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshStats() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconCircle(systemImage: "sparkles", size: 34)
            Text(verbatim: "SmartCleanup").font(.title2.weight(.heavy))
            Spacer()
            Button {
                Haptics.selection()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.card, in: Circle())
            }
            .accessibilityLabel(Text("Ustawienia"))
        }
        .frame(minHeight: 44)
        .padding(.top, 8)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zacznij tutaj").textCase(.uppercase).chip(.accent, .onAccent)
            Text("Naucz model, co chcesz usuwać").font(.title2.weight(.heavy))
            Text("Oznacz kilka zdjęć jako Zachowaj / Usuń. Potrzeba co najmniej 3 z każdej kategorii.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                MiniProgress(title: "Zachowaj", count: keepCount)
                MiniProgress(title: "Usuń", count: deleteCount)
            }
            Button("Ucz model") {
                Haptics.selection()
                showTrain = true
            }
            .buttonStyle(.primary)
            .padding(.top, 4)
        }
        .card(radius: 26, fill: .accentSoft, padding: 18)
    }

    private var modelCard: some View {
        HStack(spacing: 12) {
            IconCircle(systemImage: "lightbulb")
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("Model wytrenowany").font(.headline.weight(.heavy))
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.accent)
                }
                Text("\(keepCount + deleteCount) przykładów · \(keepCount) / \(deleteCount)")
                    .monospacedDigit()
                Text("Uczy się z każdej Twojej decyzji")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if keepCount < ClassifierTrainer.matureSamplesPerClass || deleteCount < ClassifierTrainer.matureSamplesPerClass {
                Button("Doucz model") {
                    Haptics.selection()
                    showTrain = true
                }
                .buttonStyle(.secondary)
                .controlSize(.small)
            }
        }
        .card(radius: 20, padding: 14)
    }

    private func refreshStats() {
        (keepCount, deleteCount) = TrainingDataStore.sampleCounts()
        totalDeleted = StatsStore.totalDeleted
        savedBytes = StatsStore.totalBytesFreedEstimate
        storage = StorageStore.recordSnapshot()
        storageHistory = StorageStore.snapshots
    }
}

private struct MiniProgress: View {
    let title: LocalizedStringKey
    let count: Int

    var body: some View {
        let needed = ClassifierTrainer.minSamplesPerClass
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: "\(min(count, needed))/\(needed)").monospacedDigit()
            }
            .font(.footnote.weight(.bold))
            ProgressView(value: Double(min(count, needed)), total: Double(needed))
                .progressViewStyle(CapsuleBarStyle(height: 6, fill: .accent, trackFill: .card))
        }
    }
}
