import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var marginPercent = SettingsStore.uncertaintyMarginPercent
    @State private var blurThresholdPercent = SettingsStore.blurThresholdPercent
    @State private var duplicateHammingThreshold = Double(SettingsStore.duplicateHammingThreshold)
    @AppStorage(SettingsStore.colorSchemeKey) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(SettingsStore.languageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(Reminders.enabledKey) private var remindersEnabled = false
    @State private var notificationsDenied = false

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
                    Toggle("Przypomnienia", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, isOn in
                            guard isOn else { return }
                            Task { notificationsDenied = !(await Reminders.enable()) }
                        }
                    if remindersEnabled && notificationsDenied {
                        Button("Włącz powiadomienia w Ustawieniach iOS") {
                            UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)
                        }
                    }
                } header: {
                    Text("Powiadomienia")
                } footer: {
                    Text("Najwyżej raz w tygodniu, bez spamu.")
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
                    Slider(value: $blurThresholdPercent, in: 75...95, step: 5) {
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
                } header: {
                    Text("Próg rozmycia")
                } footer: {
                    Text("Niższa wartość oznacza więcej zdjęć proponowanych jako rozmyte w „Wykryj rozmycie”.")
                }

                Section {
                    Slider(value: $duplicateHammingThreshold, in: 10...40, step: 5) {
                        Text("Czułość dopasowania duplikatów")
                    }
                    .onChange(of: duplicateHammingThreshold) { _, newValue in
                        SettingsStore.duplicateHammingThreshold = Int(newValue)
                    }

                    HStack {
                        Text("Czułość dopasowania")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Int(duplicateHammingThreshold), format: .number)
                            .font(.headline.monospacedDigit())
                    }
                } header: {
                    Text("Czułość dopasowania duplikatów")
                } footer: {
                    Text("Wyższa wartość oznacza więcej zdjęć uznanych za duplikaty w „Usuń duplikaty” — nawet takich, które różnią się nieco bardziej.")
                }

                Section {
                    // Sliders only; appearance and language are explicit choices, not tuning.
                    Button("Przywróć domyślne ustawienia") {
                        Haptics.selection()
                        marginPercent = SettingsStore.defaultMarginPercent
                        blurThresholdPercent = SettingsStore.defaultBlurThresholdPercent
                        duplicateHammingThreshold = Double(SettingsStore.defaultDuplicateHammingThreshold)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .task {
                notificationsDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
    }
}
