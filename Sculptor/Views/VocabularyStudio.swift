import SwiftUI

struct VocabularyStudio: View {
    @EnvironmentObject private var vocabulary: VocabularyStore
    @State private var selected: WordCard = VocabularyLibrary.word(on: Date())
    @State private var ownExample = ""
    @State private var query = ""
    @State private var category = "Все"
    @State private var notice = ""
    private let ink = Color(red: 0.157, green: 0.2, blue: 0.282)
    private let accent = Color(red: 0.314, green: 0.459, blue: 0.745)
    private let muted = Color(red: 0.385, green: 0.447, blue: 0.541)
    private let panel = Color.white
    private let categories = ["Все", "Ясность", "Деловая речь", "Точность", "Мышление", "Выразительность"]

    private var filtered: [WordCard] {
        VocabularyLibrary.words.filter { word in
            (category == "Все" || word.category == category) &&
            (query.isEmpty || word.term.localizedCaseInsensitiveContains(query) ||
             word.meaning.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Словарная мастерская")
                    .font(.system(size: 37, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Spacer()
                Text("Изучено: \(vocabulary.learnedCount) / \(VocabularyLibrary.words.count)")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(muted)
            }
            Text("Узнавай слово → смотри контекст → составляй свою фразу. Каждый день появляется новое слово.")
                .font(.system(size: 13)).foregroundStyle(muted)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Слово дня", systemImage: "calendar")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    Spacer()
                    Button("Открыть") { choose(vocabulary.dailyWord) }
                        .buttonStyle(.plain).foregroundStyle(accent)
                }
                HStack(spacing: 20) {
                    Image(systemName: vocabulary.dailyWord.symbol)
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(accent)
                        .frame(width: 95, height: 95)
                        .background(Color(red: 0.865, green: 0.913, blue: 0.965), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(vocabulary.dailyWord.term)
                            .font(.system(size: 28, weight: .semibold)).foregroundStyle(ink)
                        Text(vocabulary.dailyWord.meaning)
                            .font(.system(size: 13)).foregroundStyle(muted)
                        Text("Ассоциация: \(vocabulary.dailyWord.association)")
                            .font(.system(size: 11)).foregroundStyle(accent)
                    }
                }
            }
            .padding(22).background(panel, in: RoundedRectangle(cornerRadius: 16))

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 11) {
                    Text("Библиотека слов")
                        .font(.system(size: 19, weight: .semibold)).foregroundStyle(ink)
                    TextField("Поиск по слову или значению", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Picker("Тематика", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filtered) { word in
                                Button { choose(word) } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: word.symbol).frame(width: 24)
                                        Text(word.term)
                                        Spacer(minLength: 0)
                                        if vocabulary.isLearned(word) {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                                        }
                                        Image(systemName: "chevron.right").font(.system(size: 10))
                                    }
                                    .font(.system(size: 12, weight: selected.id == word.id ? .semibold : .regular))
                                    .foregroundStyle(ink)
                                    .padding(11)
                                    .background(selected.id == word.id ? Color(red: 0.91, green: 0.94, blue: 0.99) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(minHeight: 250, maxHeight: 470)
                }
                .padding(18).frame(width: 270)
                .background(panel, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: selected.symbol)
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(accent)
                            .frame(width: 75, height: 75)
                            .background(Color(red: 0.89, green: 0.92, blue: 0.98), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selected.category.uppercased()).font(.system(size: 10, weight: .medium)).foregroundStyle(accent)
                            Text(selected.term).font(.system(size: 27, weight: .semibold)).foregroundStyle(ink)
                        }
                        Spacer()
                    }
                    Text(selected.meaning).font(.system(size: 15)).foregroundStyle(ink)
                    Divider()
                    Text("Как употреблять").font(.system(size: 13, weight: .semibold))
                    Text("«\(selected.usage)»")
                        .font(.system(size: 15)).foregroundStyle(ink)
                        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.95, green: 0.96, blue: 0.99), in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 9) {
                        Image(systemName: "lightbulb").foregroundStyle(accent)
                        Text("Запомни образ: \(selected.association)")
                            .font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Text("Теперь попробуй").font(.system(size: 14, weight: .semibold))
                    TextField("Составь собственное предложение с этим словом", text: $ownExample)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Сохранить попытку") {
                            if vocabulary.savePractice(word: selected, example: ownExample) {
                                notice = "Пример сохранён. Это тренировка, а не автоматическая проверка правильности."
                            } else {
                                notice = vocabulary.savingError ?? "Попробуй ещё раз."
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        Spacer()
                        if vocabulary.isLearned(selected) { Label("Уже изучалось", systemImage: "checkmark.circle").font(.caption).foregroundStyle(accent) }
                    }
                    if !notice.isEmpty { Text(notice).font(.system(size: 11)).foregroundStyle(muted) }
                    Spacer(minLength: 0)
                }
                .padding(23)
                .frame(maxWidth: .infinity, minHeight: 480, alignment: .topLeading)
                .background(panel, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear { choose(vocabulary.dailyWord) }
    }

    private func choose(_ word: WordCard) {
        selected = word
        ownExample = vocabulary.ownExample(for: word)
        notice = ""
    }
}
