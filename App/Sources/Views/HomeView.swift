import SwiftUI

struct HomeView: View {
    @State private var showTrain = false
    @State private var showDelete = false

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
            .fullScreenCover(isPresented: $showTrain) { TrainView() }
            .fullScreenCover(isPresented: $showDelete) { DeleteView() }
        }
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
