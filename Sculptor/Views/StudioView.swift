import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

private enum Design {
    static let bg = Color(hex: 0x090F13)
    static let side = Color(hex: 0x10191D)
    static let panel = Color(hex: 0x172226)
    static let panel2 = Color(hex: 0x1D2A2E)
    static let main = Color(hex: 0xEDF3EF)
    static let subtle = Color(hex: 0x91A19F)
    static let acid = Color(hex: 0xD2F36E)
    static let stroke = Color(hex: 0x354447)
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
    var symbol: String {
        switch self {
        case .home: "square.grid.2x2"
        case .analysis: "waveform.path.ecg"
        case .training: "sparkle.magnifyingglass"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct StudioView: View {
    @EnvironmentObject private var studio: StudioController
    @AppStorage("allowAppleCloud") private var allowAppleCloud = false
    @AppStorage("aiProvider") private var providerRaw = AIProvider.none.rawValue
    @AppStorage("aiModel") private var selectedModel = "qwen3:4b"
    @State private var page: StudioPage = .home
    @State private var showImport = false
    @State private var showPreferences = false
    @State private var toDelete: UUID?
    @State private var player: AVAudioPlayer?

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
                    }
                }
                .padding(.horizontal, 43)
                .padding(.vertical, 35)
                .frame(maxWidth: 1130, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Design.bg)
        }
        .background(Design.bg)
        .sheet(isPresented: $showPreferences) { StudioSettings().environmentObject(studio) }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Design.acid).frame(width: 38, height: 38)
                    Image(systemName: "waveform").foregroundStyle(Design.bg).font(.title3.weight(.bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("скульптор").font(.system(size: 17, weight: .bold))
                    Text("речи").font(.system(size: 15, weight: .semibold)).foregroundStyle(Design.acid)
                }
            }.padding(.bottom, 45)
            Text("СТУДИЯ").font(.system(size: 10, weight: .bold)).tracking(2.3).foregroundStyle(Design.subtle).padding(.horizontal, 12)
            ForEach(StudioPage.allCases, id: \.self) { item in
                Button { page = item } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.symbol).frame(width: 24)
                        Text(item.rawValue)
                        Spacer()
                    }
                    .font(.system(size: 14, weight: page == item ? .semibold : .medium))
                    .foregroundStyle(page == item ? Design.acid : Design.subtle)
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(page == item ? Design.panel : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            Spacer()
            Button { showPreferences = true } label: {
                Label("Настройки ИИ", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13)).foregroundStyle(Design.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }.buttonStyle(.plain)
            Text("v0.3 · локально по умолчанию")
                .font(.system(size: 10)).foregroundStyle(Design.subtle.opacity(0.68)).padding(.horizontal, 12)
        }
        .padding(20)
        .frame(width: 235)
        .background(Design.side)
        .overlay(alignment: .trailing) { Rectangle().fill(Design.stroke.opacity(0.5)).frame(width: 1) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(page.rawValue.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(3.0)
                .foregroundStyle(Design.subtle)
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(studio.isRecording ? Color.red : Design.acid).frame(width: 7, height: 7)
                Text(studio.isRecording ? "ИДЁТ ЗАПИСЬ" : "ГОТОВО К ЗАПИСИ")
                    .font(.system(size: 10, weight: .bold)).tracking(1.0)
                    .foregroundStyle(Design.subtle)
            }
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Твой голос.\nТвоя форма.")
                        .font(.system(size: 48, weight: .bold, design: .rounded)).tracking(-2.2)
                        .foregroundStyle(Design.main)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Записывай, замечай привычки и тренируй выразительность.")
                        .font(.system(size: 15)).foregroundStyle(Design.subtle)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                stat("ЗАПИСЕЙ", value: "\(studio.totalRecordings)", symbol: "mic")
                stat("СЛОВ-ПАРАЗИТОВ", value: "\(studio.totalFillers)", symbol: "quote.bubble")
                stat("УРОКОВ ЗАВЕРШЕНО", value: "\(studio.completedLessons)", symbol: "graduationcap")
            }
            capturePanel
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("ПОСЛЕДНИЕ ЗАПИСИ")
                    if studio.sessions.filter({ !$0.isPractice }).isEmpty {
                        Text("Пока нет записей. Начни с короткого рассказа на 1–2 минуты.")
                            .font(.system(size: 14)).foregroundStyle(Design.subtle)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(studio.sessions.filter({ !$0.isPractice }).prefix(4)) { session in
                            sessionRow(session)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 15) {
                    sectionTitle("СЛЕДУЮЩИЙ ШАГ")
                    Image(systemName: "waveform.path")
                        .font(.system(size: 29)).foregroundStyle(Design.acid)
                    Text(studio.latestReport?.issues.first?.heading ?? "Первый разбор")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(Design.main)
                    Text("Одна цель. Одно короткое упражнение. Сравнение результата.")
                        .font(.system(size: 12)).foregroundStyle(Design.subtle)
                    Button("Перейти к практике →") { page = .training }
                        .buttonStyle(.plain).font(.system(size: 13, weight: .semibold)).foregroundStyle(Design.acid)
                }
                .padding(20)
                .frame(maxWidth: 280, alignment: .leading)
                .background(Design.panel, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var capturePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle(studio.currentIsPractice && studio.isRecording ? "УПРАЖНЕНИЕ" : "НОВАЯ ЗАПИСЬ")
                    Text(studio.isRecording ? "Микрофон записывает" : "Начни, когда будешь готов")
                        .font(.system(size: 23, weight: .semibold)).foregroundStyle(Design.main)
                    Text("Очный разговор или свободный рассказ. Звук хранится на Mac.")
                        .font(.system(size: 13)).foregroundStyle(Design.subtle)
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 69, weight: .ultraLight)).foregroundStyle(Design.acid)
            }
            HStack(spacing: 12) {
                Button {
                    Task {
                        if studio.isRecording {
                            if let id = await studio.stop() {
                                page = .analysis
                                await studio.analyze(id, allowAppleCloud: allowAppleCloud)
                            }
                        } else { await studio.start() }
                    }
                } label: {
                    Label(studio.isRecording ? "Завершить и разобрать" : "Начать запись", systemImage: studio.isRecording ? "stop.fill" : "record.circle")
                        .frame(minWidth: 190)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(studio.isBusy || studio.processingID != nil)
                Button { showImport = true } label: { Label("Загрузить аудиофайлы", systemImage: "square.and.arrow.down.on.square") }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(studio.isRecording)
                Spacer()
                Text(studio.isRecording ? timeString(studio.elapsed) : "00:00")
                    .font(.system(size: 24, weight: .medium, design: .monospaced)).foregroundStyle(Design.main)
            }
            Text("Перед записью диалога предупреди собеседников и получи необходимые разрешения.")
                .font(.system(size: 11)).foregroundStyle(Design.subtle)
        }
        .padding(25)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 22))
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
        VStack(alignment: .leading, spacing: 22) {
            sectionTitle("ПЕРСОНАЛЬНАЯ ПРАКТИКА")
            Text("Не просто заметить.\nИзменить привычку.")
                .font(.system(size: 43, weight: .bold, design: .rounded)).tracking(-1.5)
            let issue = studio.latestReport?.issues.first
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "target").foregroundStyle(Design.acid); sectionTitle("СЕГОДНЯШНЯЯ ЦЕЛЬ") }
                Text(issue?.heading ?? "Ясная формулировка мысли")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(Design.main)
                Text(issue?.exercise ?? "За 45 секунд расскажи об одной идее по схеме: проблема → предложение → результат.")
                    .font(.system(size: 16)).foregroundStyle(Design.subtle).lineSpacing(5)
                Rectangle().fill(Design.stroke).frame(height: 1)
                HStack(spacing: 10) {
                    step("01", "Выбери одну мысль")
                    step("02", "Произнеси её заново")
                    step("03", "Сравни результаты")
                }
                HStack(spacing: 15) {
                    Button {
                        Task {
                            if studio.isRecording {
                                if let id = await studio.stop() {
                                    await studio.analyze(id, allowAppleCloud: allowAppleCloud)
                                }
                            } else { await studio.start(practice: true) }
                        }
                    } label: {
                        Label(studio.isRecording ? "Завершить упражнение" : "Записать попытку", systemImage: studio.isRecording ? "stop.fill" : "mic")
                    }.buttonStyle(PrimaryButtonStyle()).disabled(studio.isBusy || studio.processingID != nil)
                    if studio.isRecording { Text(timeString(studio.elapsed)).monospacedDigit().foregroundStyle(Design.acid) }
                    if studio.processingID != nil { ProgressView().tint(Design.acid) }
                }
            }
            .padding(25).background(Design.panel, in: RoundedRectangle(cornerRadius: 18))
            sectionTitle("ПОСЛЕДНИЕ ПОПЫТКИ")
            let attempts = studio.sessions.filter { $0.isPractice && $0.report != nil }
            if attempts.isEmpty {
                emptyHint("Пока нет выполненных упражнений", "После записи попытки появятся её измерения. Прогресс оценивай по нескольким занятиям, а не по одному повтору.")
            } else {
                if let before = studio.latestReport, let after = attempts.first?.report,
                   before.metrics.words > 0, after.metrics.words > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("СРАВНЕНИЕ С ПОСЛЕДНЕЙ ОБЫЧНОЙ ЗАПИСЬЮ")
                        HStack {
                            metric("БЫЛО", String(format: "%.1f", before.metrics.fillersPer100), "потенциальных паразитов / 100 слов")
                            metric("ПОСЛЕ", String(format: "%.1f", after.metrics.fillersPer100), "потенциальных паразитов / 100 слов")
                        }
                        Text("Сравнение ориентировочное: упражнение и обычный разговор различаются по содержанию и длительности.")
                            .font(.system(size: 11)).foregroundStyle(Design.subtle)
                    }.padding(15).background(Design.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                ForEach(attempts.prefix(5)) { session in
                    HStack {
                        Text(session.createdAt, format: .dateTime.day().month().hour().minute())
                        Spacer()
                        Text("\(session.report?.metrics.fillerCount ?? 0) повторов").foregroundStyle(Design.subtle)
                        Button("Разбор") { studio.selectedID = session.id; page = .analysis }
                            .buttonStyle(.plain).foregroundStyle(Design.acid)
                    }.padding(15).background(Design.panel, in: RoundedRectangle(cornerRadius: 12))
                }
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
        VStack(alignment: .leading, spacing: 17) {
            HStack { Text(label).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Design.subtle); Spacer(); Image(systemName: symbol).foregroundStyle(Design.acid) }
            Text(value).font(.system(size: 39, weight: .semibold, design: .rounded)).foregroundStyle(Design.main).monospacedDigit()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.panel, in: RoundedRectangle(cornerRadius: 15))
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
            .foregroundStyle(Design.bg)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Design.acid.opacity(configuration.isPressed ? 0.74 : 1), in: RoundedRectangle(cornerRadius: 11))
    }
}
private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Design.main.opacity(configuration.isPressed ? 0.7 : 1))
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Design.panel2, in: RoundedRectangle(cornerRadius: 11))
    }
}
