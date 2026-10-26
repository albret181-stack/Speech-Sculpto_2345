import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

private enum Design {
    // Monochrome Studio — quietly warm grays, strong typographic hierarchy.
    static let bg = Color(hex: 0xF4F6FB)
    static let side = Color(hex: 0xEDF1F9)
    static let panel = Color(hex: 0xFFFFFF)
    static let panel2 = Color(hex: 0xE8F0F8)
    static let main = Color(hex: 0x283348)
    static let subtle = Color(hex: 0x62728A)
    static let acid = Color(hex: 0x5075BE)
    static let stroke = Color(hex: 0xDAE2EF)
    static let inverse = Color.white
    static let mutedBlue = Color(hex: 0xDCEAF6)
    static let lavender = Color(hex: 0xE9E7F7)
    static let softTeal = Color(hex: 0xDDF0F1)
    static let deep = Color(hex: 0x374967)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

private enum StudioPage: String, CaseIterable {
    case home = "Главная"
    case analysis = "Разбор"
    case training = "Практика"
    case history = "История"
    case vocabulary = "Словарь"
    case progress = "Прогресс"
    var symbol: String {
        switch self {
        case .home: "square.grid.2x2"
        case .analysis: "waveform.path.ecg"
        case .training: "sparkle.magnifyingglass"
        case .history: "clock.arrow.circlepath"
        case .vocabulary: "character.book.closed"
        case .progress: "chart.xyaxis.line"
        }
    }
}

struct StudioView: View {
    @EnvironmentObject private var studio: StudioController
    @EnvironmentObject private var updates: UpdateManager
    @EnvironmentObject private var vocabulary: VocabularyStore
    @EnvironmentObject private var coaching: CoachingStore
    @AppStorage("allowAppleCloud") private var allowAppleCloud = false
    @AppStorage("aiProvider") private var providerRaw = AIProvider.none.rawValue
    @AppStorage("aiModel") private var selectedModel = "qwen3:4b"
    @State private var page: StudioPage = .home
    @State private var showImport = false
    @State private var showPreferences = false
    @State private var showUpdatePanel = false
    @State private var toDelete: UUID?
    @State private var player: AVAudioPlayer?
    @State private var activeLessonID: String?
    @State private var progressDays = 30
    @AppStorage("progressGoalFillersPer100") private var progressGoalFillersPer100 = 3.0

    private var report: SpeechReport? { studio.selected?.report ?? studio.latestReport }

    var body: some View {
        HStack(spacing: 0) {
            navigation
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    switch page {
                    case .home: home
                    case .analysis: analysis
                    case .training: training
                    case .history: history
                    case .vocabulary: VocabularyStudio().environmentObject(vocabulary)
                    case .progress: progressDashboard
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 28)
                .frame(maxWidth: 1250, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Design.bg)
        }
        .background(Design.bg)
        .sheet(isPresented: $showPreferences) { StudioSettings().environmentObject(studio).environmentObject(updates) }
        .task { if updates.autoCheck { await updates.check(silent: true) } }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                page = .history
                Task { await studio.importBatch(urls, allowAppleCloud: allowAppleCloud) }
            }
        }
        .alert("Сообщение", isPresented: Binding(get: { studio.message != nil }, set: { if !$0 { studio.message = nil } })) {
            Button("Понятно", role: .cancel) { studio.message = nil }
        } message: { Text(studio.message ?? "") }
        .confirmationDialog("Удалить запись и локальные результаты?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Удалить", role: .destructive) { if let id = toDelete { studio.delete(id) }; toDelete = nil }
            Button("Отмена", role: .cancel) { toDelete = nil }
        } message: { Text("Восстановить удалённый аудиофайл будет невозможно.") }
    }


    private var navigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Design.main).frame(width: 34, height: 34)
                    Image(systemName: "waveform").foregroundStyle(Design.inverse)
                        .font(.system(size: 15, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("скульптор").font(.system(size: 12, weight: .bold))
                    Text("речи.").font(.system(size: 12, weight: .bold))
                }.foregroundStyle(Design.main)
            }
            .padding(.horizontal, 10).padding(.top, 9).padding(.bottom, 50)

            ForEach(StudioPage.allCases, id: \.self) { item in
                Button { page = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol).frame(width: 18)
                        Text(item.rawValue)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12, weight: page == item ? .bold : .medium))
                    .foregroundStyle(page == item ? Design.inverse : Design.main)
                    .padding(.horizontal, 13).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(page == item ? Design.main : Color.clear,
                                in: Capsule())
                }.buttonStyle(.plain)
            }
            Spacer()
            Button { showPreferences = true } label: {
                Label("Настройки ИИ", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }.buttonStyle(.plain)
            Rectangle().fill(Design.stroke).frame(height: 1)
            Text("Личная студия")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Design.main)
            Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") + " · macOS")
                .font(.system(size: 10)).foregroundStyle(Design.subtle)
        }
        .padding(16)
        .frame(width: 211)
        .background(Design.side, in: RoundedRectangle(cornerRadius: 16))
        .padding(.leading, 12)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 5) {
                Circle().fill(Design.subtle.opacity(0.5)).frame(width: 6, height: 6)
                Circle().fill(Design.subtle.opacity(0.5)).frame(width: 6, height: 6)
                Circle().fill(Design.subtle.opacity(0.5)).frame(width: 6, height: 6)
            }
            Spacer()
            Button {
                showUpdatePanel = true
                Task { await updates.check() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: updates.hasUpdate ? "bell.badge.fill" : "bell")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Design.main)
                        .frame(width: 38, height: 38)
                        .background(Design.panel, in: Circle())
                    if updates.hasUpdate {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Проверить обновления")
            .popover(isPresented: $showUpdatePanel) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(updates.hasUpdate ? "Доступно обновление" : "Обновления приложения").font(.headline)
                    Text(updates.release?.name ?? "Проверка GitHub Releases").font(.subheadline)
                    Text(updates.release?.body ?? updates.statusMessage ?? "Последняя версия проверяется при запуске приложения.").font(.caption).lineLimit(6)
                    if updates.hasUpdate { Button(updates.installing ? "Загрузка…" : "Скачать и установить") {
                        Task { await updates.install() }
                    }.disabled(!updates.canInstall || updates.installing) }
                    if updates.hasUpdate && !updates.canInstall { Text("Нет проверяемого установочного пакета.").font(.caption) }
                    Button("Закрыть") { showUpdatePanel = false }
                }.padding(18).frame(width: 315)
            }
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 10))
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Design.inverse)
                    .background(Design.main, in: Circle())
                Text(studio.isRecording ? "Микрофон · запись" : "Микрофон · готов")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Design.main)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Design.panel, in: Capsule())
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                Text("Локальное хранение")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Design.subtle)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Design.panel, in: Capsule())
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("ЛИЧНОЕ ПРОСТРАНСТВО / СТУДИЯ")
                    Text("Мастерская речи")
                        .font(.system(size: 41, weight: .semibold, design: .rounded))
                        .tracking(-1.9)
                        .foregroundStyle(Design.main)
                    Text("Замечай речевые привычки. Управляй подачей. Говори свободнее.")
                        .font(.system(size: 13)).foregroundStyle(Design.subtle)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 17) {
                    capturePanel
                    HStack(spacing: 12) {
                        stat("ЗАПИСЕЙ", value: "\(studio.totalRecordings)", symbol: "mic")
                        stat("СЛОВ-ПАРАЗИТОВ", value: "\(studio.totalFillers)", symbol: "quote.bubble")
                        stat("УРОКОВ", value: "\(coaching.completed(studio.sessions).count)", symbol: "graduationcap")
                    }
                    recentRecordings
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 17) {
                    progressPanel
                    wordOfDayPanel
                    practiceSpotlight
                }
                .frame(width: 300)
            }
        }
    }

    private var recentRecordings: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Последние записи")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Design.main)
                Spacer()
                Button("Вся история ↗") { page = .history }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Design.subtle)
                    .buttonStyle(.plain)
            }
            let recent = studio.sessions.filter { !$0.isPractice }
            if recent.isEmpty {
                Text("Здесь появятся первые записи. Начни с рассказа на 1–2 минуты.")
                    .font(.system(size: 13)).foregroundStyle(Design.subtle)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            } else {
                ForEach(recent.prefix(3)) { session in sessionRow(session) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("ПРОГРЕСС / РЕЧЬ")
            Text("Чистота речи")
                .font(.system(size: 19, weight: .semibold)).foregroundStyle(Design.main)
            Text("Слова-паразиты на 100 слов")
                .font(.system(size: 11)).foregroundStyle(Design.subtle)
            let history = Array(studio.sessions.filter { !$0.isPractice }
                                .compactMap { $0.report?.metrics.fillersPer100 }
                                .prefix(7).reversed())
            if let last = history.last {
                Text(String(format: "%.1f", last).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 41, weight: .semibold))
                    .tracking(-1.6).foregroundStyle(Design.main)
                SpeechTrend(values: history)
                    .frame(height: 62)
            } else {
                Text("—").font(.system(size: 41)).foregroundStyle(Design.main)
                Text("Появится после первого анализа.")
                    .font(.system(size: 11)).foregroundStyle(Design.subtle)
                    .frame(height: 62, alignment: .center)
            }
            Rectangle().fill(Design.stroke).frame(height: 1)
            let issue = studio.latestReport?.issues.first
            Text(issue.map { "В фокусе: \($0.heading)" } ?? "Следующий шаг: первый разбор")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.main).lineLimit(2)
            Text("Сравнивай сопоставимые записи, а не только суммы.")
                .font(.system(size: 10)).foregroundStyle(Design.subtle).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private var wordOfDayPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Слово дня", systemImage: "character.book.closed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Design.acid)
                Spacer()
                Text("Ежедневно").font(.system(size: 10)).foregroundStyle(Design.subtle)
            }
            HStack(spacing: 12) {
                Image(systemName: vocabulary.dailyWord.symbol)
                    .font(.system(size: 26))
                    .frame(width: 53, height: 53)
                    .foregroundStyle(Design.acid)
                    .background(Design.mutedBlue, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(vocabulary.dailyWord.term).font(.system(size: 19, weight: .semibold)).foregroundStyle(Design.main)
                    Text(vocabulary.dailyWord.meaning).font(.system(size: 11)).foregroundStyle(Design.subtle).lineLimit(3)
                }
            }
            Button("Значение, примеры и практика") { page = .vocabulary }
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Design.acid)
                .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private var practiceSpotlight: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18).fill(Design.deep)
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 230, height: 230)
                .offset(x: 116, y: -85)
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 170, height: 170)
                .offset(x: 147, y: -54)
            VStack(alignment: .leading, spacing: 11) {
                Text("СЛЕДУЮЩИЙ УРОК / 02")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1).foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 30)
                Text(studio.latestReport?.issues.first?.heading ?? "Научись выделять главную мысль")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white).lineLimit(3)
                Text("Одна цель, короткая тренировка и повторная запись.")
                    .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.72))
                Button("Перейти к практике ↗") { page = .training }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.main)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Design.panel, in: Capsule())
                    .buttonStyle(.plain)
            }
            .padding(22)
        }
        .frame(height: 245)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var capturePanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            captureHeadline
            captureWaveform
            captureActions
            Text("Перед записью разговора предупреди других участников.")
                .font(.system(size: 10))
                .foregroundStyle(Design.subtle)
        }
        .padding(25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Design.panel, Design.softTeal.opacity(0.6), Design.mutedBlue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 23)
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
        )
    }

    private var captureHeadline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("НОВАЯ ЗАПИСЬ / 01")
                Spacer()
                Text(studio.isRecording ? "● Идёт запись" : "● Готово к записи")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Design.panel, in: Capsule())
            }
            Text(studio.isRecording ? "Записываем твой голос." : "Начни с голоса.\nОстальное — за нами.")
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .tracking(-0.9)
                .foregroundStyle(Design.main)
                .fixedSize(horizontal: false, vertical: true)
            Text("Разговор или свободный рассказ. Запись и результаты останутся на Mac.")
                .font(.system(size: 12))
                .foregroundStyle(Design.subtle)
        }
    }

    private var captureWaveform: some View {
        Image(systemName: "waveform")
            .resizable()
            .scaledToFit()
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Design.main.opacity(0.55))
            .accessibilityLabel("Декоративная звуковая волна, не сигнал микрофона")
    }

    private var captureActions: some View {
        HStack(spacing: 10) {
            Button(action: toggleStudioRecording) {
                Label(studio.isRecording ? "Завершить и разобрать" : "Начать запись",
                      systemImage: studio.isRecording ? "stop.fill" : "record.circle")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(studio.isBusy || studio.processingID != nil)

            Button {
                showImport = true
            } label: {
                Label("Загрузить аудиофайлы", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(studio.isRecording || studio.isBusy)
            Spacer(minLength: 0)
            Text(studio.isRecording ? timeString(studio.elapsed) : "00:00")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Design.main)
        }
    }

    private func toggleStudioRecording() {
        Task { @MainActor in
            if studio.isRecording {
                if let id = await studio.stop() {
                    page = .analysis
                    await studio.analyze(id, allowAppleCloud: allowAppleCloud)
                }
            } else {
                await studio.start()
            }
        }
    }

    private var analysis: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text("Разбор, который\nможно применить.")
                .font(.system(size: 42, weight: .bold, design: .rounded)).tracking(-1.7)
                .foregroundStyle(Design.main)
            picker
            if let session = studio.selected {
                if let report = session.report { reportView(session: session, report: report) }
                else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Запись готова к разбору").font(.title2.weight(.semibold))
                        Text("Распознавание русского языка выполняется средствами macOS. Для приватности по умолчанию разрешено только локальное распознавание; его доступность зависит от Mac.")
                            .foregroundStyle(Design.subtle)
                        HStack {
                            Button { Task { await studio.analyze(session.id, allowAppleCloud: allowAppleCloud) } } label: {
                                Label("Анализировать", systemImage: "wand.and.stars")
                            }.buttonStyle(PrimaryButtonStyle())
                            if studio.processingID != nil { ProgressView().tint(Design.acid); Text("Обрабатываем аудио…").foregroundStyle(Design.subtle) }
                        }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Design.panel, in: RoundedRectangle(cornerRadius: 18))
                }
            } else {
                emptyHint("Пока нет записей", "Запиши разговор или импортируй аудиофайл. После обработки здесь появится разбор.")
            }
        }
    }

    private func reportView(session: SpeechSession, report: SpeechReport) -> some View {
        VStack(alignment: .leading, spacing: 21) {
            Text(report.verdict).font(.system(size: 23, weight: .semibold)).foregroundStyle(Design.main)
            HStack(spacing: 12) {
                metric("СЛОВА-ПАРАЗИТЫ", "\(report.metrics.fillerCount)", String(format: "%.1f на 100 слов", report.metrics.fillersPer100))
                metric("ТЕМП", report.metrics.words > 0 ? "\(Int(report.metrics.wordsPerMinute))" : "—", "слов / минуту")
                metric("ПАУЗЫ", "\(report.metrics.pauseCount)", "обнаруженных")
                metric("ИНТОНАЦИЯ", report.metrics.pitchRangeSemitones.map { String(format: "%.1f", $0) } ?? "—", "полутона · диапазон")
            }
            sectionTitle("ОСНОВНЫЕ ЗАМЕЧАНИЯ")
            if !report.fillerBreakdown.isEmpty { fillerSuggestions(report: report) }
            if !report.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Примеры из твоей записи").font(.system(size: 17, weight: .semibold)).foregroundStyle(Design.main)
                    Text("Алгоритм различает вероятные речевые заполнители и выражения, которые могут быть уместными.")
                        .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    ForEach(Array(SpeechContext.analyze(report.transcript, segments: report.segments).prefix(10).enumerated()), id: \.offset) { _, cue in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("«\(cue.phrase)» · \(cue.interpretation == .possibleFiller ? "Проверить" : "Возможно, уместно")")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Design.main)
                                Text(cue.excerpt).font(.system(size: 12)).foregroundStyle(Design.main).textSelection(.enabled)
                                Text(cue.explanation).font(.system(size: 11)).foregroundStyle(Design.subtle)
                            }
                            Spacer(minLength: 0)
                            if let time = cue.timestamp {
                                Button { play(session, from: time) } label: {
                                    Label(timeString(time), systemImage: "play.circle")
                                }.buttonStyle(.plain).foregroundStyle(Design.acid)
                            }
                        }
                        .padding(12).background(Design.panel2, in: RoundedRectangle(cornerRadius: 10))
                    }
                }.padding(19).background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
            }
            ForEach(report.issues) { issue in
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text(issue.heading).font(.system(size: 16, weight: .semibold)).foregroundStyle(Design.main)
                        Spacer()
                        if let at = issue.timestamp {
                            Button { play(session, from: at) } label: {
                                Label(timeString(at), systemImage: "play.circle.fill")
                                    .font(.system(size: 12)).foregroundStyle(Design.acid)
                            }.buttonStyle(.plain)
                        }
                    }
                    Text(issue.evidence).font(.system(size: 13)).foregroundStyle(Design.main)
                    Text(issue.explanation).font(.system(size: 13)).foregroundStyle(Design.subtle)
                    HStack {
                        Image(systemName: "arrow.turn.down.right").foregroundStyle(Design.acid)
                        Text(issue.exercise).font(.system(size: 12)).foregroundStyle(Design.acid)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
            }
            HStack {
                Button("Перейти к упражнению") { page = .training }.buttonStyle(PrimaryButtonStyle())
                Button("Слушать запись") { studio.play(session.id) }.buttonStyle(OutlineButtonStyle())
                Spacer()
                Button("Повторить анализ") { Task { await studio.analyze(session.id, allowAppleCloud: allowAppleCloud) } }
                    .buttonStyle(.plain).foregroundStyle(Design.subtle)
            }
            aiReport(session: session, report: report)
            VStack(alignment: .leading, spacing: 13) {
                sectionTitle("РАСШИФРОВКА")
                Text(report.transcript.isEmpty ? "Расшифровка недоступна на этом Mac в выбранном режиме." : report.transcript)
                    .font(.system(size: 14)).foregroundStyle(Design.main).textSelection(.enabled)
                    .lineSpacing(6)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Design.panel, in: RoundedRectangle(cornerRadius: 17))
            ForEach(report.caveats, id: \.self) { caveat in
                Label(caveat, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Design.subtle)
            }
        }
    }

    private func fillerSuggestions(report: SpeechReport) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Что сказать вместо слова-паразита")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Design.main)
            Text("Не всегда нужно искать синоним. Иногда лучше сделать паузу или назвать мысль точнее.")
                .font(.system(size: 12)).foregroundStyle(Design.subtle)
            ForEach(report.fillerBreakdown.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { item in
                HStack(alignment: .top, spacing: 13) {
                    Text("«\(item.key)»")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Design.main)
                        .frame(width: 110, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(fillerAdvice(for: item.key)).font(.system(size: 12)).foregroundStyle(Design.main)
                        Text("В записи: \(item.value) раз. Проверь контекст: выражение может быть уместным.")
                            .font(.system(size: 11)).foregroundStyle(Design.subtle)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Design.panel2, in: RoundedRectangle(cornerRadius: 11))
            }
            Button("Перейти к словарю и потренироваться") { page = .vocabulary }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Design.acid)
                .buttonStyle(.plain)
        }
        .padding(19)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
    }

    private func fillerAdvice(for word: String) -> String {
        switch word.lowercased() {
        case "ну", "эээ", "эм", "ммм": return "Попробуй короткую паузу перед следующей мыслью."
        case "короче": return "Если подводишь итог, скажи: «Главный вывод…»."
        case "типа", "как бы": return "Назови факт прямо: «Например…» или уточни смысл."
        case "вот": return "Начни сразу с содержательной части предложения."
        case "по факту", "на самом деле": return "Если противопоставляешь аргументы, скажи: «Однако…»."
        case "то есть": return "Для пояснения подойдёт «Иными словами…», но не заменяй один повтор другим."
        case "в целом": return "Если обобщаешь: «Основной вывод…»."
        default: return "Оцени роль выражения: оставь его, если оно нужно по смыслу, иначе сократи или сделай паузу."
        }
    }

    private func aiReport(session: SpeechSession, report: SpeechReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ДОПОЛНИТЕЛЬНЫЙ ИИ-РАЗБОР")
            if let comment = report.aiComment {
                Text(comment).font(.system(size: 13)).foregroundStyle(Design.main).textSelection(.enabled)
            } else {
                Text("Основные показатели рассчитаны локально. По желанию можно попросить выбранную LLM объяснить структуру и формулировки.")
                    .font(.system(size: 13)).foregroundStyle(Design.subtle)
            }
            Text(AIProvider(rawValue: providerRaw) == .openai ? "При запуске в OpenAI отправится расшифровка (до 9000 символов) и измерения, но не аудиофайл." :
                 "При запуске Ollama текст обрабатывается локально через 127.0.0.1. Без выбранной модели текст никуда не отправляется.")
                .font(.system(size: 11)).foregroundStyle(Design.subtle)
            Button(studio.aiBusy ? "ИИ отвечает…" : "Получить отзыв от ИИ") {
                guard !report.transcript.isEmpty else { studio.message = "Сначала нужна расшифровка аудио."; return }
                let provider = AIProvider(rawValue: providerRaw) ?? .none
                guard provider != .none else { showPreferences = true; return }
                studio.aiBusy = true
                Task {
                    defer { studio.aiBusy = false }
                    do {
                        let text = try await AIReview.generate(report: report, provider: provider, model: selectedModel)
                        studio.saveAI(session.id, value: text)
                    } catch { studio.message = error.localizedDescription }
                }
            }
            .buttonStyle(OutlineButtonStyle()).disabled(studio.aiBusy || report.transcript.isEmpty)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel2, in: RoundedRectangle(cornerRadius: 17))
    }

    private var training: some View {
        let baseline = studio.sessions.first(where: { !$0.isPractice && $0.report != nil })
        let recommended = LessonPlanner.recommended(from: baseline)
        let choices = [recommended,
            CoachingLesson(id: "filler", title: "Осознанная пауза", instruction: "За минуту объясни идею, заменяя лишние вводные слова паузами.", focus: "filler", baselineID: baseline?.id, baselineRate: baseline?.report?.metrics.fillersPer100, createdAt: Date()),
            CoachingLesson(id: "intonation", title: "Интонационный акцент", instruction: "Выделяй голосом ключевое слово каждой фразы. Не пытайся искусственно повышать голос.", focus: "intonation", baselineID: baseline?.id, baselineRate: nil, createdAt: Date()),
            CoachingLesson(id: "clarity", title: "Тезис — аргумент — вывод", instruction: "За минуту сформулируй тезис, один аргумент и ясный вывод.", focus: "clarity", baselineID: baseline?.id, baselineRate: nil, createdAt: Date())
        ]
        let unique = choices.enumerated().filter { index, item in
            !choices.prefix(index).contains(where: { $0.id == item.id })
        }.map { $0.element }
        let selected = coaching.lessons.first(where: { $0.id == activeLessonID }) ?? unique.first!
        let relevantAttempts = coaching.attempts(for: selected.id, sessions: studio.sessions)
        return VStack(alignment: .leading, spacing: 22) {
            sectionTitle("ПЕРСОНАЛЬНАЯ ПРАКТИКА")
            Text("Тренируй одну привычку за раз.")
                .font(.system(size: 39, weight: .semibold, design: .rounded)).foregroundStyle(Design.main)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("ПОДОБРАНО ПО ТВОИМ ЗАПИСЯМ")
                    ForEach(unique, id: \.id) { lesson in
                        Button {
                            if coaching.select(lesson) { activeLessonID = lesson.id }
                        } label: {
                            HStack {
                                Image(systemName: lesson.id == selected.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Design.acid)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.title).font(.system(size: 13, weight: .semibold))
                                    if lesson.id == recommended.id { Text("Рекомендовано").font(.system(size: 10)).foregroundStyle(Design.acid) }
                                }
                                Spacer()
                            }.foregroundStyle(Design.main).padding(12)
                                .background(lesson.id == selected.id ? Design.mutedBlue : Design.bg,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }.padding(19).frame(width: 262)
                    .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 15) {
                    Label("ТВОЁ УПРАЖНЕНИЕ", systemImage: "target")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Design.acid)
                    Text(selected.title).font(.system(size: 24, weight: .semibold)).foregroundStyle(Design.main)
                    Text(selected.instruction).font(.system(size: 14)).foregroundStyle(Design.subtle)
                    Text("Запиши попытку, затем сравни её с предыдущими по одинаковому упражнению.")
                        .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    Button {
                        Task {
                            if studio.isRecording {
                                if let id = await studio.stop() {
                                    await studio.analyze(id, allowAppleCloud: allowAppleCloud)
                                }
                            } else {
                                if !coaching.lessons.contains(where: { $0.id == selected.id }) {
                                    guard coaching.select(selected) else { return }
                                }
                                activeLessonID = selected.id
                                await studio.start(practice: true, lessonID: selected.id)
                            }
                        }
                    } label: {
                        Label(studio.isRecording ? "Завершить упражнение" : "Записать попытку",
                              systemImage: studio.isRecording ? "stop.fill" : "mic")
                    }.buttonStyle(PrimaryButtonStyle()).disabled(studio.isBusy || studio.processingID != nil)
                    if studio.isRecording { Text(timeString(studio.elapsed)).monospacedDigit().foregroundStyle(Design.acid) }
                    if studio.processingID != nil { ProgressView() }
                }.padding(23).frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
            }
            sectionTitle("ИСТОРИЯ УПРАЖНЕНИЯ")
            if relevantAttempts.isEmpty {
                emptyHint("Пока нет попыток", "Первая запись создаст историю этого урока. Оценку сформируем после распознавания речи.")
            } else {
                let baselineAttempt = relevantAttempts.reversed().first(where: { ($0.1.report?.metrics.words ?? 0) > 0 })?.1
                ForEach(relevantAttempts, id: \.0.id) { _, session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.createdAt, format: .dateTime.day().month().hour().minute())
                                .foregroundStyle(Design.main)
                            Text(session.report == nil ? "Анализ ещё не выполнен" : "Анализ готов")
                                .font(.system(size: 11)).foregroundStyle(Design.subtle)
                        }
                        Spacer()
                        if selected.focus == "filler", let report = session.report, report.metrics.words > 0 {
                            Text(String(format: "%.1f / 100 слов", report.metrics.fillersPer100))
                                .foregroundStyle(Design.main)
                            if let initial = baselineAttempt?.report, initial.metrics.words > 0 {
                                Text(String(format: "Первая: %.1f", initial.metrics.fillersPer100))
                                    .font(.system(size: 11)).foregroundStyle(Design.subtle)
                            }
                        } else if session.report != nil {
                            Text("Просмотри разбор").font(.system(size: 11)).foregroundStyle(Design.subtle)
                        }
                        Button("Разбор") { studio.selectedID = session.id; page = .analysis }
                            .buttonStyle(.plain).foregroundStyle(Design.acid)
                    }.padding(14).background(Design.panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("Сравнение ориентировочное. Попытки могут отличаться по длительности и сложности; успех урока не определяется одним числом.")
                .font(.system(size: 11)).foregroundStyle(Design.subtle)
            if let error = coaching.message {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
    }

    private var progressDashboard: some View {
        let p = ProgressAnalytics.window(studio.sessions, days: progressDays)
        let daily = ProgressAnalytics.daily(studio.sessions, days: progressDays)
        let values = daily.compactMap { $0 }
        return VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    sectionTitle("РАЗВИТИЕ РЕЧИ / ЛИЧНАЯ СТАТИСТИКА")
                    Text("Мой прогресс")
                        .font(.system(size: 39, weight: .semibold, design: .rounded)).foregroundStyle(Design.main)
                    Text("Отслеживай динамику, а не только количество записей.")
                        .font(.system(size: 13)).foregroundStyle(Design.subtle)
                }
                Spacer()
                Picker("Период", selection: $progressDays) {
                    Text("7 дней").tag(7)
                    Text("30 дней").tag(30)
                }.pickerStyle(.segmented).frame(width: 220)
            }
            HStack(spacing: 12) {
                stat("ЗАПИСЕЙ", value: "\(p.recordings)", symbol: "mic")
                stat("ПРОАНАЛИЗИРОВАНО", value: "\(p.analyzed)", symbol: "checkmark.circle")
                stat("УРОКОВ", value: "\(p.lessons)", symbol: "graduationcap")
                stat("АКТИВНЫХ ДНЕЙ", value: "\(p.activeDays)", symbol: "calendar")
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 15) {
                    sectionTitle("ПОВТОРЫ / НА 100 СЛОВ")
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(p.fillersPer100.map { String(format: "%.1f", $0) } ?? "—")
                            .font(.system(size: 46, weight: .semibold)).foregroundStyle(Design.main)
                        Text("потенциальных заполнителей на 100 слов")
                            .font(.system(size: 11)).foregroundStyle(Design.subtle)
                    }
                    if values.count >= 2 {
                        SpeechTrend(values: values).frame(height: 130)
                        Text("Линия показывает только дни с пригодной расшифровкой; пропущенные дни не равны нулю.")
                            .font(.system(size: 11)).foregroundStyle(Design.subtle)
                    } else {
                        emptyHint("Пока недостаточно данных", "Нужны хотя бы два дня с пригодными результатами.")
                    }
                    Rectangle().fill(Design.stroke).frame(height: 1)
                    Text(p.change.map { String(format: "Изменение: %+.1f п.п.", $0) } ?? "Изменение пока не рассчитывается")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Design.main)
                    Text(p.comparisonNote).font(.system(size: 11)).foregroundStyle(Design.subtle)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 15) {
                    sectionTitle("ЛИЧНАЯ ЦЕЛЬ")
                    Text("Частота заполнителей").font(.system(size: 19, weight: .semibold)).foregroundStyle(Design.main)
                    Text("Выбери ориентир, а не универсальную норму.")
                        .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    HStack {
                        Text("Цель").foregroundStyle(Design.main)
                        Spacer()
                        Text(String(format: "%.1f на 100 слов", progressGoalFillersPer100))
                            .foregroundStyle(Design.main).monospacedDigit()
                    }.font(.system(size: 12))
                    Slider(value: $progressGoalFillersPer100, in: 0...10, step: 0.5)
                        .tint(Design.acid)
                    if let rate = p.fillersPer100 {
                        Text(rate <= progressGoalFillersPer100 ? "По этому периоду ориентир достигнут." : "Пока выше выбранного ориентира.")
                            .font(.system(size: 12)).foregroundStyle(Design.main)
                    } else {
                        Text("Нет достаточных данных для сравнения с целью.")
                            .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    }
                    Text("Цель сохраняется на этом Mac. Результат не учитывает точность распознавания и смысловую уместность всех выражений.")
                        .font(.system(size: 11)).foregroundStyle(Design.subtle)
                }
                .padding(22).frame(width: 290, alignment: .topLeading)
                .background(Design.panel, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 20) {
            if studio.batchActive || !studio.batchSummary.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label(studio.batchActive ? "Пакетная обработка" : "Пакетная обработка завершена",
                              systemImage: studio.batchActive ? "waveform" : "checkmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("\(studio.batchProcessed) / \(studio.batchTotal)")
                            .monospacedDigit().foregroundStyle(Design.acid)
                    }
                    ProgressView(value: Double(studio.batchProcessed),
                                 total: Double(max(1, studio.batchTotal)))
                        .tint(Design.acid)
                    if studio.batchActive {
                        Text("Сейчас: \(studio.batchCurrentFile)")
                            .font(.system(size: 12)).foregroundStyle(Design.subtle).lineLimit(2)
                    } else {
                        Text(studio.batchSummary)
                            .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    }
                    Text("Файлы обрабатываются по очереди. При ошибке остальные продолжат обработку.")
                        .font(.system(size: 11)).foregroundStyle(Design.subtle)
                }
                .padding(18).background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
            }
            Text("История голоса")
                .font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-1.5)
            Text("Твои записи и тренировки остаются на этом Mac.")
                .font(.system(size: 14)).foregroundStyle(Design.subtle)
            if studio.sessions.isEmpty { emptyHint("История пуста", "Запиши первый разговор, чтобы увидеть динамику.") }
            else {
                ForEach(studio.sessions) { session in
                    HStack(spacing: 14) {
                        Image(systemName: session.isPractice ? "graduationcap" : "waveform")
                            .foregroundStyle(Design.acid).frame(width: 30)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.title).font(.system(size: 14, weight: .semibold))
                            Text("\(session.durationLabel) · \(session.report == nil ? "Ожидает анализа" : "Проанализировано")")
                                .font(.system(size: 11)).foregroundStyle(Design.subtle)
                        }
                        Spacer()
                        Button("Открыть") { studio.selectedID = session.id; page = .analysis }
                            .buttonStyle(.plain).foregroundStyle(Design.acid)
                        Button { studio.reveal(session.id) } label: { Image(systemName: "folder") }
                            .buttonStyle(.plain).foregroundStyle(Design.subtle).help("Показать в Finder")
                        Button { toDelete = session.id } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).foregroundStyle(Design.subtle).help("Удалить")
                    }
                    .padding(16).background(Design.panel, in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
    }

    private var picker: some View {
        HStack(spacing: 12) {
            Text("Запись:").foregroundStyle(Design.subtle)
            Picker("Запись", selection: $studio.selectedID) {
                Text("Выбери запись").tag(UUID?.none)
                ForEach(studio.sessions) { session in
                    Text(session.title).tag(Optional(session.id))
                }
            }
            .labelsHidden().frame(maxWidth: 340)
            Spacer()
            if let session = studio.selected { Text(session.durationLabel).font(.system(size: 13)).foregroundStyle(Design.subtle) }
        }
    }

    private func sessionRow(_ session: SpeechSession) -> some View {
        Button {
            studio.selectedID = session.id
            page = .analysis
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "waveform").foregroundStyle(Design.acid)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Design.main).lineLimit(1)
                    Text("\(session.durationLabel) · \(session.report == nil ? "Нужен анализ" : "Разбор готов")")
                        .font(.system(size: 11)).foregroundStyle(Design.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Design.subtle)
            }.padding(12)
                .background(Design.panel, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func stat(_ label: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label).font(.system(size: 10, weight: .bold))
                    .tracking(0.5).foregroundStyle(Design.subtle)
                Spacer(minLength: 2)
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(Design.main)
                    .frame(width: 25, height: 25)
                    .overlay(Circle().stroke(Design.stroke, lineWidth: 1))
            }
            Text(value)
                .font(.system(size: 35, weight: .semibold, design: .rounded))
                .tracking(-1.5).foregroundStyle(Design.main)
                .monospacedDigit()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 20))
    }
    private func metric(_ title: String, _ value: String, _ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(Design.subtle)
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).foregroundStyle(Design.main)
            Text(explanation).font(.system(size: 10)).foregroundStyle(Design.subtle)
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 14))
    }
    private func step(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number).font(.system(size: 20, weight: .medium)).foregroundStyle(Design.acid)
            Text(label).font(.system(size: 12)).foregroundStyle(Design.main)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func emptyHint(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(text).font(.system(size: 13)).foregroundStyle(Design.subtle)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .bold)).tracking(1.8).foregroundStyle(Design.subtle)
    }
    private func play(_ session: SpeechSession, from seconds: Double) {
        // Precise local replay instead of opening an external player.
        do {
            let sound = try AVAudioPlayer(contentsOf: SessionStore.shared.audioURL(session))
            sound.currentTime = seconds
            sound.play()
            player = sound
        } catch { studio.message = "Не удалось воспроизвести фрагмент: \(error.localizedDescription)" }
    }
}

private func timeString(_ value: TimeInterval) -> String {
    let seconds = max(0, Int(value))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Design.inverse)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Design.main.opacity(configuration.isPressed ? 0.77 : 1), in: Capsule())
    }
}
private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Design.main.opacity(configuration.isPressed ? 0.7 : 1))
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Design.panel, in: Capsule())
            .overlay(Capsule().stroke(Design.stroke, lineWidth: 1))
    }
}


private struct SpeechTrend: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            if values.count < 2 {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
            } else {
                Path { path in
                    let low = values.min() ?? 0
                    let high = values.max() ?? 1
                    let scale = max(0.5, high - low)
                    let w = proxy.size.width
                    let h = proxy.size.height
                    for (index, value) in values.enumerated() {
                        let x = w * CGFloat(index) / CGFloat(values.count - 1)
                        let y = h * (0.85 - CGFloat((value - low) / scale) * 0.70)
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.black.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
