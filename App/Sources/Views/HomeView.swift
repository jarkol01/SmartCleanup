import SwiftUI

struct HomeView: View {
    @State private var showTrain = false
    @State private var showDelete = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("SmartCleanup")
                    .font(.largeTitle.bold())

                Text(ClassifierTrainer.hasSavedModel() ? "Model wytrenowany ✅" : "Model nie jest jeszcze wytrenowany")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                StatsRow()

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showTrain = true
                    } label: {
                        MenuButtonLabel(
                            title: "Ucz model",
                            subtitle: "Oznacz kilka zdjęć jako Zachowaj / Usuń",
                            systemImage: "brain.head.profile"
                        )
                    }

                    Button {
                        showDelete = true
                    } label: {
                        MenuButtonLabel(
                            title: "Usuń zdjęcia",
                            subtitle: "Przejrzyj propozycje modelu i posprzątaj galerię",
                            systemImage: "trash"
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
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fullScreenCover(isPresented: $showTrain) { TrainView() }
            .fullScreenCover(isPresented: $showDelete) { DeleteView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

private struct StatsRow: View {
    private var trainingCounts: (keep: Int, delete: Int) { TrainingDataStore.sampleCounts() }

    private var savedSpaceText: String {
        let bytes = StatsStore.totalBytesFreedEstimate
        guard bytes > 0 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            StatTile(
                value: "\(trainingCounts.keep + trainingCounts.delete)",
                label: "do treningu",
                systemImage: "photo.stack"
            )
            StatTile(
                value: "\(StatsStore.totalDeleted)",
                label: "usuniętych",
                systemImage: "trash"
            )
            StatTile(
                value: "~\(savedSpaceText)",
                label: "oszczędzone",
                systemImage: "internaldrive"
            )
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
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
    let title: String
    let subtitle: String
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
