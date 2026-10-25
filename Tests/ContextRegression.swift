import Foundation
@main struct ContextTests {
 static func main() {
  func check(_ yes: Bool,_ label: String) { if !yes { fatalError(label) } }
  let cases = [
   ("Вот это решение.",0),
   ("Ну, мне нужно, ну, поработать.",2),
   ("Маршрут стал короче.",0),
   ("Оборудование такого типа.",0),
   ("Это, то есть, другой вариант.",0),
   ("Короче, давай начнём.",1)
  ]
  for (text, expected) in cases {
   let count=SpeechContext.likelyBreakdown(text).values.reduce(0,+)
   check(count == expected, "\(text): got \(count), expected \(expected)")
  }
  let cues=SpeechContext.analyze("Ну, давай начнём.",segments:[SpeechSegment(word:"Ну",start:1.25,duration:0.3),SpeechSegment(word:"давай",start:1.8,duration:0.3)])
  check(abs((cues.first?.timestamp ?? -10)-1.25)<0.01,"timestamp match")
  check(Scoring.makeReport(text:"Вот это решение.",segments:[],duration:3,acoustic:AcousticValues()).metrics.fillerCount == 0,"context counts")
  print("PASS: context-aware analysis regression")
 }
}
