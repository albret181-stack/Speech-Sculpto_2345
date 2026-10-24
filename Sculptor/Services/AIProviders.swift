import Foundation
import Security

/// Only runs after a user clicks the corresponding analyze-with-AI button.
enum AIProvider: String, CaseIterable, Identifiable {
    case none = "Без внешней LLM"
    case ollama = "Локальная Ollama"
    case openai = "OpenAI API"
    var id: String { rawValue }
}

enum APISecret {
    static let service = "studio.speechsculptor.openai"
    static func read() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data,
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
    static func save(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        let fields: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecValueData as String: Data(key.utf8)]
        SecItemAdd(fields as CFDictionary, nil)
    }
}

enum AIReview {
    enum RequestError: LocalizedError {
        case missingKey, badResponse(String), missingText, noProvider
        var errorDescription: String? {
            switch self {
            case .missingKey: return "Добавь API-ключ OpenAI в настройках."
            case .badResponse(let text): return "ИИ недоступен: \(text)"
            case .missingText: return "ИИ вернул пустой ответ."
            case .noProvider: return "Выбери ИИ в настройках."
            }
        }
    }
    static func generate(report: SpeechReport, provider: AIProvider, model: String) async throws -> String {
        guard provider != .none else { throw RequestError.noProvider }
        let prompt = """
        Ты — аккуратный русскоязычный тренер речи. Ниже есть расшифровка и измеренные показатели.
        Не выдавай гипотезу за факт. Не делай выводов о личности, состоянии здоровья, интеллекте.
        Напиши: 1) резюме (2 предложения), 2) 2–3 конкретные речевые проблемы с короткими цитатами из расшифровки,
        3) одно упражнение на ближайшую тренировку. Если нет обоснования, скажи, что данных недостаточно.
        Часть текста может принадлежать другим людям. Не оценивай их отдельно.
        Метрики: слов \(report.metrics.words); возможных паразитов \(report.metrics.fillerCount); на 100 слов \(String(format: "%.1f", report.metrics.fillersPer100));
        темп \(String(format: "%.0f", report.metrics.wordsPerMinute)) слов/мин в измеренной речи;
        пауз \(report.metrics.pauseCount); интонационный диапазон \(report.metrics.pitchRangeSemitones.map { String(format: "%.1f", $0) } ?? "не определён") полутона.
        Расшифровка (обрезана до 9000 символов):
        \(String(report.transcript.prefix(9000)))
        """
        let url: URL
        var request: URLRequest
        if provider == .ollama {
            url = URL(string: "http://127.0.0.1:11434/api/chat")!
            request = URLRequest(url: url)
            let payload: [String: Any] = ["model": model.isEmpty ? "qwen3:4b" : model,
                                          "stream": false,
                                          "messages": [["role": "user", "content": prompt]]]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } else {
            let key = APISecret.read()
            guard !key.isEmpty else { throw RequestError.missingKey }
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let payload: [String: Any] = ["model": model.isEmpty ? "gpt-4.1-mini" : model,
                                          "messages": [["role": "user", "content": prompt]],
                                          "temperature": 0.3]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw RequestError.badResponse("HTTP \(code). Проверь настройки модели и подключение.")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RequestError.missingText }
        let reply: String?
        if provider == .ollama {
            reply = (obj["message"] as? [String: Any])?["content"] as? String
        } else {
            reply = ((obj["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        }
        guard let reply, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RequestError.missingText }
        return reply
    }
}
