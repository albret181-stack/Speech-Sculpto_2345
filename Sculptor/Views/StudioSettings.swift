import SwiftUI
import AppKit

struct StudioSettings: View {
    @EnvironmentObject private var studio: StudioController
    @EnvironmentObject private var updates: UpdateManager
    @AppStorage("allowAppleCloud") private var allowAppleCloud = false
    @AppStorage("aiProvider") private var providerRaw = AIProvider.none.rawValue
    @AppStorage("aiModel") private var selectedModel = "qwen3:4b"
    @State private var apiKey = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Настройки · Скульптор речи").font(.system(size: 23, weight: .bold))
            Text("Приложение сохраняет аудио и статистику локально. Облачные запросы выполняются только после твоего явного действия.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            Toggle("Разрешить распознавание речи серверами Apple, если локальный русский язык не поддерживается", isOn: $allowAppleCloud)
                .toggleStyle(.checkbox)
            Text("По умолчанию выключено. При выключенной опции распознавание Apple будет запускаться только на устройстве.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Picker("Модель для смыслового разбора", selection: $providerRaw) {
                ForEach(AIProvider.allCases) { option in Text(option.rawValue).tag(option.rawValue) }
            }
            .pickerStyle(.radioGroup)
            if providerRaw != AIProvider.none.rawValue {
                TextField("Название модели", text: $selectedModel)
                    .textFieldStyle(.roundedBorder)
                if providerRaw == AIProvider.ollama.rawValue {
                    Text("Нужен установленный Ollama, запущенный на 127.0.0.1:11434. Модель нужно скачать отдельно.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else if providerRaw == AIProvider.openai.rawValue {
                    SecureField("OpenAI API-ключ", text: $apiKey)
                    HStack {
                        Button("Сохранить в Keychain") { APISecret.save(apiKey); apiKey = ""; saved = true }
                        if saved { Text("Ключ сохранён").foregroundStyle(.green) }
                    }
                    Text("Для OpenAI можно указать gpt-4.1-mini. API оплачивается отдельно от подписки ChatGPT. Перед каждым запросом приложение показывает, что будет отправлено.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Обновления").font(.headline)
                Toggle("Проверять обновления при запуске", isOn: $updates.autoCheck)
                HStack {
                    Button("Проверить обновления") { Task { await updates.check() } }
                    if updates.hasUpdate {
                        Button("Установить \(updates.release?.tagName ?? "")") {
                            Task { await updates.install() }
                        }.disabled(!updates.canInstall || updates.installing)
                    }
                }
                if let message = updates.statusMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Text("Проверка публичных GitHub Releases без авторизации. Для установки релиз должен содержать ZIP и SHA256SUMS.txt. Обновления пока экспериментальные, без подписи разработчика.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button("Журнал ошибок") { studio.showDiagnostics() }
                Button("Показать локальные записи") { studio.showFolder() }
                Spacer()
                Text("v0.6.3 · macOS 14.2+").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(28).frame(width: 575)
        .onAppear {
            if providerRaw == AIProvider.openai.rawValue && selectedModel == "qwen3:4b" { selectedModel = "gpt-4.1-mini" }
        }
        .onChange(of: providerRaw) { _, newValue in
            if newValue == AIProvider.openai.rawValue { selectedModel = "gpt-4.1-mini" }
            else if newValue == AIProvider.ollama.rawValue { selectedModel = "qwen3:4b" }
        }
    }
}
