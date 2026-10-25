import Foundation
import Combine

/// Curated offline Russian vocabulary. All samples are illustrative rather than user quotes.
struct WordCard: Codable, Identifiable, Hashable {
    let term: String
    let meaning: String
    let usage: String
    let symbol: String
    let association: String
    let category: String
    var id: String { term }
}

struct WordPractice: Codable, Hashable {
    var term: String
    var ownExample: String
    var practicedOn: Date
}

enum VocabularyLibrary {
    static let words: [WordCard] = [
        WordCard(term: "Лаконичный", meaning: "Краткий и точный, без лишних подробностей.", usage: "Нужен лаконичный ответ с главным выводом.", symbol: "text.alignleft", association: "Короткая строка текста", category: "Ясность"),
        WordCard(term: "Аргумент", meaning: "Довод, который поддерживает мнение или предложение.", usage: "Главный аргумент — сокращение времени обработки.", symbol: "scale.3d", association: "Чаши весов с доводами", category: "Деловая речь"),
        WordCard(term: "Нюанс", meaning: "Небольшая, но важная особенность.", usage: "Есть нюанс: решение зависит от объёма данных.", symbol: "slider.horizontal.3", association: "Точная настройка детали", category: "Точность"),
        WordCard(term: "Существенный", meaning: "Имеющий большое значение.", usage: "Мы обнаружили существенное отличие в результатах.", symbol: "exclamationmark.circle", association: "Выделенная важная деталь", category: "Точность"),
        WordCard(term: "Обоснованный", meaning: "Подкреплённый достаточными доводами.", usage: "Это обоснованный выбор для первого этапа.", symbol: "checkmark.seal", association: "Печать проверки", category: "Деловая речь"),
        WordCard(term: "Последовательный", meaning: "Логически связанный и непротиворечивый.", usage: "Нам нужен последовательный план внедрения.", symbol: "list.number", association: "План по шагам", category: "Ясность"),
        WordCard(term: "Уместный", meaning: "Подходящий к ситуации или контексту.", usage: "Это уместный пример для обсуждения.", symbol: "checkmark.circle", association: "Точный выбор", category: "Точность"),
        WordCard(term: "Преимущество", meaning: "Качество, которое делает один вариант лучше другого.", usage: "Преимущество метода — простота проверки.", symbol: "star.circle", association: "Выделенное достоинство", category: "Деловая речь"),
        WordCard(term: "Приоритет", meaning: "То, чему уделяют внимание в первую очередь.", usage: "Сейчас приоритет — стабильная загрузка файлов.", symbol: "flag", association: "Флажок первой задачи", category: "Деловая речь"),
        WordCard(term: "Вывод", meaning: "Итог рассуждения на основании фактов.", usage: "Мой вывод: стоит начать с небольшого пилота.", symbol: "arrow.turn.down.right", association: "Итоговая стрелка", category: "Ясность"),
        WordCard(term: "Предпосылка", meaning: "Условие, создающее возможность для события.", usage: "Предпосылка успеха — надёжные исходные данные.", symbol: "point.topleft.down.curvedto.point.bottomright.up", association: "Начало цепочки", category: "Точность"),
        WordCard(term: "Компромисс", meaning: "Решение, достигнутое через взаимные уступки.", usage: "Мы нашли компромисс между сроками и качеством.", symbol: "arrow.left.arrow.right", association: "Два направления", category: "Деловая речь"),
        WordCard(term: "Альтернатива", meaning: "Другой возможный способ действия.", usage: "Есть альтернатива: обработка данных локально.", symbol: "arrow.triangle.branch", association: "Разветвлённый путь", category: "Деловая речь"),
        WordCard(term: "Контекст", meaning: "Обстоятельства, помогающие понять смысл.", usage: "Без контекста эта цифра мало что объясняет.", symbol: "rectangle.text.magnifyingglass", association: "Текст в окружении", category: "Ясность"),
        WordCard(term: "Гипотеза", meaning: "Предположение, требующее проверки.", usage: "Наша гипотеза — паузы сделают объяснение яснее.", symbol: "lightbulb", association: "Идея под проверкой", category: "Мышление"),
        WordCard(term: "Критерий", meaning: "Признак, по которому что-либо оценивают.", usage: "Первый критерий — точность распознавания.", symbol: "checklist", association: "Контрольный список", category: "Деловая речь"),
        WordCard(term: "Наблюдение", meaning: "Замеченный факт или результат.", usage: "Моё наблюдение: в длинных ответах больше повторов.", symbol: "eye", association: "Внимательный взгляд", category: "Мышление"),
        WordCard(term: "Сопоставление", meaning: "Сравнение с учётом общих признаков.", usage: "Сопоставление двух записей показало разницу.", symbol: "square.split.2x1", association: "Две части рядом", category: "Мышление"),
        WordCard(term: "Уточнение", meaning: "Дополнительная информация для точности.", usage: "Нужно уточнение по срокам выпуска.", symbol: "text.bubble", association: "Дополнительная реплика", category: "Ясность"),
        WordCard(term: "Формулировка", meaning: "Способ словесного выражения мысли.", usage: "Эта формулировка звучит точнее и спокойнее.", symbol: "quote.bubble", association: "Облачко с фразой", category: "Ясность"),
        WordCard(term: "Структура", meaning: "Порядок и связь частей целого.", usage: "У ответа простая структура: тезис, довод, вывод.", symbol: "square.grid.2x2", association: "Блоки одной системы", category: "Ясность"),
        WordCard(term: "Акцент", meaning: "Выделение важной части речи или мысли.", usage: "Сделай акцент на результате, а не на деталях.", symbol: "bold", association: "Выделенное слово", category: "Выразительность"),
        WordCard(term: "Интонация", meaning: "Изменение высоты и силы голоса, передающее смысл.", usage: "Интонация помогла подчеркнуть главный вопрос.", symbol: "waveform", association: "Волна голоса", category: "Выразительность"),
        WordCard(term: "Пауза", meaning: "Краткая остановка в речи.", usage: "Перед выводом я сделал паузу.", symbol: "pause.circle", association: "Знак паузы", category: "Выразительность"),
        WordCard(term: "Темп", meaning: "Скорость протекания действия или речи.", usage: "В конце встречи темп речи стал спокойнее.", symbol: "speedometer", association: "Шкала скорости", category: "Выразительность"),
        WordCard(term: "Ритм", meaning: "Чередование элементов во времени.", usage: "Ритм фраз помогает слушателю следить за мыслью.", symbol: "metronome", association: "Метроном", category: "Выразительность"),
        WordCard(term: "Дикция", meaning: "Чёткость произнесения звуков и слов.", usage: "Чёткая дикция помогает воспринимать сложный доклад.", symbol: "mouth", association: "Чёткое произношение", category: "Выразительность"),
        WordCard(term: "Артикуляция", meaning: "Работа органов речи при произнесении звуков.", usage: "Медленная артикуляция полезна для тренировки.", symbol: "waveform.path", association: "Работа речевого аппарата", category: "Выразительность"),
        WordCard(term: "Тезис", meaning: "Кратко сформулированная основная мысль.", usage: "Мой тезис: проверка должна быть прозрачной.", symbol: "text.quote", association: "Ключевая строка", category: "Ясность"),
        WordCard(term: "Детализация", meaning: "Уточнение с помощью частностей.", usage: "Здесь нужна детализация по каждому случаю.", symbol: "magnifyingglass", association: "Увеличенная деталь", category: "Точность"),
        WordCard(term: "Перспектива", meaning: "Возможное развитие ситуации в будущем.", usage: "В перспективе мы автоматизируем проверку.", symbol: "binoculars", association: "Взгляд вдаль", category: "Мышление"),
        WordCard(term: "Обстоятельство", meaning: "Условие, влияющее на ситуацию.", usage: "Это обстоятельство меняет наш первоначальный план.", symbol: "circle.dotted", association: "Дополнительное условие", category: "Точность"),
        WordCard(term: "Объективный", meaning: "Основанный на фактах, а не личных предпочтениях.", usage: "Для оценки нужен объективный критерий.", symbol: "viewfinder", association: "Нейтральный взгляд", category: "Мышление"),
        WordCard(term: "Субъективный", meaning: "Зависящий от личных ощущений или мнений.", usage: "Моё первое впечатление было субъективным.", symbol: "person.crop.circle", association: "Личный взгляд", category: "Мышление"),
        WordCard(term: "Тенденция", meaning: "Устойчивое направление изменений.", usage: "В данных заметна тенденция к улучшению.", symbol: "chart.line.uptrend.xyaxis", association: "Направление графика", category: "Мышление"),
        WordCard(term: "Динамика", meaning: "Характер изменений во времени.", usage: "Динамика показателей важнее одного числа.", symbol: "chart.xyaxis.line", association: "Линия во времени", category: "Деловая речь"),
        WordCard(term: "Устойчивость", meaning: "Способность сохранять состояние при воздействиях.", usage: "Нам важна устойчивость результата на новых данных.", symbol: "shield", association: "Прочная защита", category: "Точность"),
        WordCard(term: "Достоверный", meaning: "Заслуживающий доверия, соответствующий фактам.", usage: "Этот вывод опирается на достоверные данные.", symbol: "checkmark.shield", association: "Проверенные данные", category: "Точность"),
        WordCard(term: "Проверяемый", meaning: "Такой, который можно подтвердить или опровергнуть.", usage: "Нужен проверяемый показатель, а не впечатление.", symbol: "checkmark.magnifyingglass", association: "Проверка факта", category: "Деловая речь"),
        WordCard(term: "Прозрачность", meaning: "Понятность и открытость принципов работы.", usage: "Прозрачность расчёта поможет избежать споров.", symbol: "eye.circle", association: "Видимая схема", category: "Деловая речь"),
        WordCard(term: "Результативный", meaning: "Приводящий к нужному результату.", usage: "Мы выбрали результативный способ обучения.", symbol: "target", association: "Попадание в цель", category: "Деловая речь"),
        WordCard(term: "Практичный", meaning: "Удобный и полезный в реальных условиях.", usage: "Это практичный способ проверять отчёты.", symbol: "wrench.adjustable", association: "Полезный инструмент", category: "Деловая речь"),
        WordCard(term: "Рациональный", meaning: "Основанный на разумном расчёте.", usage: "Рациональный выбор зависит от сроков и ресурсов.", symbol: "brain.head.profile", association: "Обдуманное решение", category: "Мышление"),
        WordCard(term: "Эффективный", meaning: "Дающий хороший результат при разумных затратах.", usage: "Эффективный процесс требует меньше ручных действий.", symbol: "bolt.circle", association: "Быстрое достижение цели", category: "Деловая речь"),
        WordCard(term: "Компонент", meaning: "Составная часть системы или процесса.", usage: "Этот компонент отвечает за загрузку аудио.", symbol: "square.3.layers.3d", association: "Часть конструкции", category: "Точность"),
        WordCard(term: "Механизм", meaning: "Совокупность средств, обеспечивающих работу.", usage: "Механизм обновлений требует отдельной проверки.", symbol: "gearshape.2", association: "Работающие шестерёнки", category: "Точность"),
        WordCard(term: "Алгоритм", meaning: "Определённая последовательность действий.", usage: "Алгоритм сначала проверяет файл, затем анализирует.", symbol: "point.3.connected.trianglepath.dotted", association: "Цепочка шагов", category: "Мышление"),
        WordCard(term: "Сценарий", meaning: "Возможный порядок развития событий.", usage: "Рассмотрим сценарий с двумя входными файлами.", symbol: "list.bullet.rectangle", association: "План ситуации", category: "Деловая речь"),
        WordCard(term: "Этап", meaning: "Отдельная часть процесса.", usage: "На первом этапе проверим качество записи.", symbol: "circle.grid.cross", association: "Часть пути", category: "Деловая речь"),
        WordCard(term: "Прототип", meaning: "Предварительная модель для проверки идеи.", usage: "Прототип показал, какие функции действительно нужны.", symbol: "square.on.square", association: "Предварительный образец", category: "Деловая речь"),
        WordCard(term: "Пилот", meaning: "Пробное внедрение в ограниченном масштабе.", usage: "Пилот поможет проверить подход до запуска.", symbol: "paperplane", association: "Пробный запуск", category: "Деловая речь"),
        WordCard(term: "Итерация", meaning: "Повторный цикл работы с уточнениями.", usage: "Следующая итерация учитывает замечания пользователей.", symbol: "arrow.triangle.2.circlepath", association: "Повторный цикл", category: "Деловая речь"),
        WordCard(term: "Риск", meaning: "Возможность неблагоприятного исхода.", usage: "Главный риск — потерять часть данных при переносе.", symbol: "exclamationmark.triangle", association: "Сигнал внимания", category: "Мышление"),
        WordCard(term: "Ограничение", meaning: "Условие, сужающее возможности.", usage: "Основное ограничение связано с качеством аудио.", symbol: "lock", association: "Граница возможностей", category: "Точность"),
        WordCard(term: "Допущение", meaning: "Предположение, принятое для дальнейших рассуждений.", usage: "Наше допущение: микрофон записывает одного человека.", symbol: "questionmark.circle", association: "Неуточнённое условие", category: "Мышление"),
        WordCard(term: "Зависимость", meaning: "Связь, при которой одно определяется другим.", usage: "Есть зависимость между шумом и точностью.", symbol: "link", association: "Связанные звенья", category: "Мышление"),
        WordCard(term: "Противоречие", meaning: "Несовместимость двух утверждений или фактов.", usage: "В требованиях обнаружилось противоречие.", symbol: "arrow.left.arrow.right.circle", association: "Два встречных вывода", category: "Мышление"),
        WordCard(term: "Согласованность", meaning: "Соответствие частей друг другу.", usage: "Проверим согласованность целей и метрик.", symbol: "checkmark.circle.trianglebadge.exclamationmark", association: "Сочетающиеся элементы", category: "Деловая речь"),
        WordCard(term: "Обратная связь", meaning: "Сообщение о результате или качестве действия.", usage: "Обратная связь помогла улучшить объяснение.", symbol: "bubble.left.and.bubble.right", association: "Диалог и ответ", category: "Деловая речь"),
        WordCard(term: "Ориентир", meaning: "То, что помогает выбрать направление.", usage: "Ориентир на неделю — три короткие тренировки.", symbol: "location.north", association: "Направляющая стрелка", category: "Мышление"),
        WordCard(term: "Потенциал", meaning: "Возможности для развития.", usage: "У этой идеи есть потенциал для расширения.", symbol: "leaf", association: "Рост возможности", category: "Мышление"),
        WordCard(term: "Промежуточный", meaning: "Находящийся между началом и концом процесса.", usage: "Это промежуточный результат, а не окончательный вывод.", symbol: "circle.lefthalf.filled", association: "Половина пути", category: "Точность"),
        WordCard(term: "Итоговый", meaning: "Относящийся к заключительному результату.", usage: "Итоговый отчёт содержит все проверенные случаи.", symbol: "checkmark.rectangle", association: "Завершённая работа", category: "Ясность"),
        WordCard(term: "Своевременный", meaning: "Сделанный в подходящий момент.", usage: "Своевременный вопрос помог избежать ошибки.", symbol: "clock", association: "Подходящее время", category: "Деловая речь"),
        WordCard(term: "Предметный", meaning: "Конкретный, относящийся к сути вопроса.", usage: "Перейдём к предметному обсуждению причин.", symbol: "scope", association: "Фокус на сути", category: "Ясность"),
        WordCard(term: "Внятный", meaning: "Понятный и отчётливый.", usage: "Внятный ответ начинается с главной мысли.", symbol: "text.aligncenter", association: "Ясное сообщение", category: "Ясность"),
        WordCard(term: "Ёмкий", meaning: "Краткий, но насыщенный смыслом.", usage: "Ёмкий вывод помогает закончить презентацию.", symbol: "square.text.square", association: "Много смысла в малом", category: "Ясность"),
        WordCard(term: "Убедительный", meaning: "Способный вызвать доверие к доводам.", usage: "Убедительный пример подтверждает основной тезис.", symbol: "hand.thumbsup", association: "Убедительный довод", category: "Выразительность"),
        WordCard(term: "Развёрнутый", meaning: "Подробный, раскрывающий тему.", usage: "Развёрнутый ответ уместен, когда нужны детали.", symbol: "text.book.closed", association: "Подробное объяснение", category: "Ясность"),
        WordCard(term: "Нейтральный", meaning: "Не выражающий предпочтения какой-либо стороне.", usage: "Нейтральный тон помогает обсуждать ошибки.", symbol: "equal.circle", association: "Ровное отношение", category: "Выразительность"),
        WordCard(term: "Конструктивный", meaning: "Направленный на решение проблемы.", usage: "Конструктивный разговор закончился общим планом.", symbol: "hammer", association: "Создание решения", category: "Деловая речь"),
        WordCard(term: "Корректный", meaning: "Точный и соответствующий принятым нормам.", usage: "Корректный вопрос не содержит необоснованных выводов.", symbol: "checkmark.bubble", association: "Точная формулировка", category: "Ясность"),
        WordCard(term: "Оговорка", meaning: "Уточнение, которое ограничивает утверждение.", usage: "Важная оговорка: выборка пока небольшая.", symbol: "asterisk.circle", association: "Маленькое уточнение", category: "Точность"),
        WordCard(term: "Обобщение", meaning: "Вывод об общих свойствах нескольких случаев.", usage: "Раннее обобщение может скрыть исключения.", symbol: "square.stack.3d.up", association: "Несколько случаев вместе", category: "Мышление"),
        WordCard(term: "Интерпретация", meaning: "Объяснение смысла фактов или слов.", usage: "У этих цифр возможна иная интерпретация.", symbol: "text.magnifyingglass", association: "Поиск смысла", category: "Мышление"),
        WordCard(term: "Разграничение", meaning: "Чёткое разделение понятий.", usage: "Здесь важно разграничение причины и последствия.", symbol: "rectangle.split.2x1", association: "Две разные части", category: "Ясность"),
        WordCard(term: "Аргументация", meaning: "Система доводов в поддержку вывода.", usage: "Слабую аргументацию стоит дополнить примерами.", symbol: "list.bullet.clipboard", association: "Набор доводов", category: "Деловая речь"),
        WordCard(term: "Убедительность", meaning: "Способность речи вызывать доверие.", usage: "Убедительность зависит не только от темпа, но и от фактов.", symbol: "person.crop.circle.badge.checkmark", association: "Доверие к словам", category: "Выразительность"),
        WordCard(term: "Аккуратность", meaning: "Точность и внимательность в действиях или словах.", usage: "Аккуратность формулировок особенно важна в отчёте.", symbol: "pencil.tip", association: "Точная правка", category: "Ясность"),
        WordCard(term: "Диалог", meaning: "Обмен репликами между участниками.", usage: "Хороший диалог оставляет место для вопросов.", symbol: "bubble.left.and.bubble.right.fill", association: "Два собеседника", category: "Выразительность"),
        WordCard(term: "Мотив", meaning: "Причина, побуждающая действовать.", usage: "Мотив решения стоит назвать в самом начале.", symbol: "heart.text.square", association: "Причина действия", category: "Мышление"),
        WordCard(term: "Обоснование", meaning: "Объяснение причин, подтверждающее решение.", usage: "Добавим обоснование, прежде чем выбирать вариант.", symbol: "doc.text.magnifyingglass", association: "Проверка доводов", category: "Деловая речь"),
        WordCard(term: "Прояснить", meaning: "Сделать более понятным.", usage: "Хочу прояснить один момент перед обсуждением.", symbol: "sun.max", association: "Свет на вопрос", category: "Ясность"),
        WordCard(term: "Сформулировать", meaning: "Выразить мысль словами в определённой форме.", usage: "Попробуй сформулировать вывод одним предложением.", symbol: "pencil.line", association: "Записанная мысль", category: "Ясность"),
        WordCard(term: "Подытожить", meaning: "Кратко изложить главное после обсуждения.", usage: "Предлагаю подытожить встречу тремя выводами.", symbol: "checklist.checked", association: "Завершённый список", category: "Ясность"),
        WordCard(term: "Сопоставить", meaning: "Сравнить, чтобы выявить сходство и различия.", usage: "Сопоставим результаты за две недели.", symbol: "square.split.2x2", association: "Два результата рядом", category: "Мышление"),
        WordCard(term: "Разъяснить", meaning: "Объяснить так, чтобы стало понятно.", usage: "Нужно разъяснить порядок проверки сотрудникам.", symbol: "text.bubble.fill", association: "Понятное объяснение", category: "Ясность"),
        WordCard(term: "Уточнить", meaning: "Сделать информацию более точной.", usage: "Хочу уточнить, к какому периоду относится число.", symbol: "magnifyingglass.circle", association: "Поиск конкретики", category: "Точность"),
        WordCard(term: "Резюмировать", meaning: "Кратко изложить основные положения.", usage: "Позвольте резюмировать результаты обсуждения.", symbol: "text.redaction", association: "Короткий итог", category: "Ясность"),
        WordCard(term: "Охарактеризовать", meaning: "Описать главные отличительные черты.", usage: "Можно охарактеризовать этот подход как осторожный.", symbol: "square.and.pencil", association: "Описание свойств", category: "Ясность"),
        WordCard(term: "Подтвердить", meaning: "Показать, что утверждение соответствует фактам.", usage: "Нужно подтвердить вывод на новых примерах.", symbol: "checkmark.seal.fill", association: "Доказанное утверждение", category: "Точность"),
        WordCard(term: "Обозначить", meaning: "Ясно назвать или отметить.", usage: "Давайте обозначим цель на следующую неделю.", symbol: "tag", association: "Явная метка", category: "Ясность"),
        WordCard(term: "Выделить", meaning: "Отделить главное от остального.", usage: "Важно выделить три ключевые причины.", symbol: "highlighter", association: "Подсветка главного", category: "Ясность"),
        WordCard(term: "Аргументировать", meaning: "Подкреплять мнение доводами.", usage: "Предлагаю аргументировать решение цифрами.", symbol: "scale.3d", association: "Довод на весах", category: "Деловая речь"),
        WordCard(term: "Систематизировать", meaning: "Привести данные или идеи в порядок.", usage: "Полезно систематизировать замечания по темам.", symbol: "square.grid.3x3", association: "Упорядоченные блоки", category: "Мышление")
    ]
    static func word(on day: Date, calendar: Calendar = .current) -> WordCard {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? day
        let index = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference),
                                             to: calendar.startOfDay(for: day)).day ?? 0
        let count = words.count
        return words[((index % count) + count) % count]
    }
}

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var practices: [WordPractice] = []
    @Published var savingError: String?
    static let shared = VocabularyStore()
    private let file: URL

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechSculptor", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("vocabulary-progress.json")
        if let data = try? Data(contentsOf: file),
           let restored = try? JSONDecoder().decode([WordPractice].self, from: data) {
            practices = restored
        }
    }

    var dailyWord: WordCard { VocabularyLibrary.word(on: Date()) }
    var learnedCount: Int { Set(practices.map { $0.term }).count }
    var exampleCount: Int { practices.count }
    func isLearned(_ word: WordCard) -> Bool { practices.contains { $0.term == word.term } }
    func ownExample(for word: WordCard) -> String {
        practices.last(where: { $0.term == word.term })?.ownExample ?? ""
    }
    /// Records practice, but does not claim to grade semantic correctness.
    @discardableResult
    func savePractice(word: WordCard, example: String) -> Bool {
        let text = example.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 12 && text.split(whereSeparator: { $0.isWhitespace }).count >= 3 else {
            savingError = "Напиши хотя бы короткое предложение из трёх слов."
            return false
        }
        var updated = practices
        updated.append(WordPractice(term: word.term, ownExample: text, practicedOn: Date()))
        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: file, options: .atomic)
            practices = updated
            savingError = nil
            return true
        } catch {
            savingError = "Не удалось сохранить пример: \(error.localizedDescription)"
            return false
        }
    }
}
