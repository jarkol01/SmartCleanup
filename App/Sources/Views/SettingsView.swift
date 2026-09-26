import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var marginPercent = SettingsStore.uncertaintyMarginPercent
    @State private var blurThresholdPercent = SettingsStore.blurThresholdPercent
    @AppStorage(SettingsStore.colorSchemeKey) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(SettingsStore.languageKey) private var languageRaw = AppLanguage.system.rawValue

    private var thresholdPercentText: String { "\(Int(100 - marginPercent))%" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Wygląd", selection: $colorSchemeRaw) {
                        ForEach(AppColorScheme.allCases) { option in
                            Text(LocalizedStringKey(option.label)).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Wygląd")
                }

                Section {
                    Picker("Język", selection: $languageRaw) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(LocalizedStringKey(option.label)).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Język")
                }

                Section {
                    Slider(value: $marginPercent, in: 0...50, step: 1) {
                        Text("Margines niepewności")
                    }
                    .onChange(of: marginPercent) { _, newValue in
                        SettingsStore.uncertaintyMarginPercent = newValue
                    }

                    HStack {
                        Text("Poniżej \(thresholdPercentText) pewności uznajemy za niepewne")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Int(marginPercent), format: .number)
                            .font(.headline.monospacedDigit())
                    }
                } header: {
                    Text("Próg pewności")
                } footer: {
                    Text("Wyższa wartość oznacza więcej zdjęć w „Przejrzyj niepewne” — model musi być bardziej pewny, żeby coś ominęło ręczną kontrolę.")
                }

                Section {
                    Button("Przywróć domyślne (25)") {
                        marginPercent = SettingsStore.defaultMarginPercent
                        SettingsStore.uncertaintyMarginPercent = marginPercent
                    }
                }

                Section {
                    Slider(value: $blurThresholdPercent, in: 10...90, step: 5) {
                        Text("Próg rozmycia")
                    }
                    .onChange(of: blurThresholdPercent) { _, newValue in
                        SettingsStore.blurThresholdPercent = newValue
                    }

                    HStack {
                        Text("Od \(Int(blurThresholdPercent))% pewności uznajemy zdjęcie za rozmyte")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Int(blurThresholdPercent), format: .number)
                            .font(.headline.monospacedDigit())
                    }

                    Button("Przywróć domyślne (50)") {
                        blurThresholdPercent = SettingsStore.defaultBlurThresholdPercent
                        SettingsStore.blurThresholdPercent = blurThresholdPercent
                    }
                } header: {
                    Text("Próg rozmycia")
                } footer: {
                    Text("Niższa wartość oznacza więcej zdjęć proponowanych jako rozmyte w „Wykryj rozmycie”.")
                }
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        // Re-applied here (not just at the app root) because a presented .sheet gets its own
        // UIHostingController whose interface style is fixed at presentation time — the app-level
        // .preferredColorScheme doesn't propagate live to it while already open.
        .preferredColorScheme((AppColorScheme(rawValue: colorSchemeRaw) ?? .system).colorScheme)
    }
}
