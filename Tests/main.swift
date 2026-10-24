import Foundation

func require(_ ok: Bool, _ reason: String) {
    if !ok { fputs("FAILED: \(reason)\n", stderr); exit(1) }
}
require(Scoring.countWords("Ну, я хотел... сказать") == 4, "words counted")
let a = Scoring.fillers("Ну, как бы, вот. Ну и типа.")
require(a["ну"] == 2 && a["как бы"] == 1 && a["вот"] == 1 && a["типа"] == 1, "fillers counted")
require(Scoring.fillers("вот это вот")["вот это вот"] == 1, "longest match")
require(Scoring.fillers("буквот")["вот"] == nil, "word boundary")
let report = Scoring.makeReport(text: "Ну, я как бы хочу предложить такую идею. Вот.", segments: [], duration: 6, acoustic: AcousticValues(speechSeconds: 5, pauses: 1, pitchRange: 2, pitchSamples: 22))
require(report.metrics.words > 0, "words")
require(report.metrics.fillerCount == 3, "metric")
require(!report.issues.isEmpty, "at least one coaching tip")
print("7/7 core tests passed")
