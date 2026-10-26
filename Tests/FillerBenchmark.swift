import Foundation
struct Corpus: Decodable { let cases: [Sample] }
struct Sample: Decodable { let id: String; let text: String; let expected: [String] }
@main struct FillerBenchmark {
 static func main() throws {
  let path = CommandLine.arguments.dropFirst().first ?? "Tests/fixtures/ru_fillers_50.json"
  let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath:path)))
  var tp=0, fp=0, fn=0
  for c in corpus.cases {
   let expected = c.expected.reduce(into: [String:Int]()) { $0[$1,default:0]+=1 }
   let actual = SpeechContext.likelyBreakdown(c.text)
   for word in Set(expected.keys).union(actual.keys) {
    let e=expected[word,default:0], a=actual[word,default:0]
    tp+=min(e,a); fp+=max(0,a-e); fn+=max(0,e-a)
   }
   if expected != actual { print("MISMATCH \(c.id): expected=\(expected), actual=\(actual) :: \(c.text)") }
  }
  let precision = tp+fp == 0 ? 0 : Double(tp)/Double(tp+fp)
  let recall = tp+fn == 0 ? 0 : Double(tp)/Double(tp+fn)
  let f1 = precision+recall == 0 ? 0 : 2*precision*recall/(precision+recall)
  print(String(format:"CORPUS=%d TP=%d FP=%d FN=%d precision=%.4f recall=%.4f F1=%.4f",corpus.cases.count,tp,fp,fn,precision,recall,f1))
  guard corpus.cases.count == 50, f1 >= 0.80 else { exit(1) }
 }
}
