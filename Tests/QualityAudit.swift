import Foundation
@main struct QualityAuditTests {
 static func check(_ x: Bool,_ label: String) {
  guard x else { fputs("FAIL: \(label)\n", stderr); exit(1) }
  print("PASS: \(label)")
 }
 static func main() {
  check(Scoring.countWords("Привет, мир! Ёжик — 2026.") == 4, "Unicode Russian tokenization")
  check(SpeechContext.likelyBreakdown("Вот это решение.").isEmpty,"Demonstrative is not filler")
  check(SpeechContext.likelyBreakdown("Маршрут стал короче.").isEmpty,"Comparative is not filler")
  check(SpeechContext.likelyBreakdown("Оборудование такого типа.").isEmpty,"Type noun is not filler")
  check(SpeechContext.likelyBreakdown("Ну, ну, давай.").values.reduce(0,+) == 2,"Repeated fillers")
  let segments = [SpeechSegment(word:"Ну",start:2.4,duration:0.2),
                  SpeechSegment(word:"это",start:2.8,duration:0.2)]
  let cues = SpeechContext.analyze("Ну это идея.",segments:segments)
  check(abs((cues.first?.timestamp ?? -1)-2.4)<0.01,"Timestamp attached to matching word")
  check(SpeechContext.analyze("Ну, идея.").first?.timestamp == nil,"Missing timestamps not fabricated")
  let quiet = Scoring.makeReport(text:"",segments:[],duration:0,acoustic:AcousticValues())
  check(quiet.metrics.words == 0 && quiet.metrics.fillersPer100 == 0, "Empty transcript safe")
  check(quiet.metrics.wordsPerMinute.isFinite && quiet.metrics.pausesPerMinute.isFinite,"No NaN/Inf at zero duration")
  let sample = Scoring.makeReport(text:"Ну, я думаю. Ну, надо попробовать. Ну, проверим.",
                                 segments:[],duration:20,
                                 acoustic:AcousticValues(speechSeconds:15,pauses:2,pitchRange:nil,pitchSamples:0))
  check(sample.metrics.fillerCount == 3,"Three filler detections")
  check(sample.metrics.fillersPer100 > 0,"Normalized filler metric")
  check(sample.issues.count <= 3,"Report limits recommendations")
  check(sample.caveats.contains(where:{$0.contains("интонации")}),"Insufficient pitch marked")
  let original = SpeechSession(id:UUID(),title:"Example",createdAt:Date(),duration:20,
                               relativeAudioPath:"Recordings/test/audio.m4a",isPractice:false,report:sample)
  let encoded = try! JSONEncoder().encode([original])
  let decoded = try! JSONDecoder().decode([SpeechSession].self,from:encoded)
  check(decoded.first?.report?.metrics.fillerCount == 3,"Persistence serialization roundtrip")
  let kind = CoachEngine.recommendedKind(in:[original])
  check(CoachEngine.kinds.contains(kind),"Coach recommendation recognized")
  let lesson = CoachEngine.lesson(kind:kind,sessions:[original])
  check(lesson.targetSeconds > 0 && !lesson.steps.isEmpty,"Coaching lesson actionable")
  let attempt = CoachAttempt(sessionID:UUID(),kind:"filler",sourceSessionID:original.id,createdAt:Date(),reflection:nil)
  check(!CoachEngine.completed(attempt,sessions:[original]),"Missing practice is not counted")
  print("Quality audit checks passed")
 }
}
