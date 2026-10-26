import Foundation
@main struct AcousticQualityTests {
 static func check(_ ok:Bool,_ name:String) {
   if !ok { fputs("FAIL: \(name)\n",stderr); exit(1) }
   print("PASS: \(name)")
 }
 static func main() throws {
   let base=URL(fileURLWithPath:"build/acoustic-fixtures")
   let silence=try AudioAnalyzer.inspect(base.appendingPathComponent("silence.wav"))
   let constant=try AudioAnalyzer.inspect(base.appendingPathComponent("continuous_180hz.wav"))
   let two=try AudioAnalyzer.inspect(base.appendingPathComponent("two_bursts.wav"))
   let variable=try AudioAnalyzer.inspect(base.appendingPathComponent("variable_pitch.wav"))
   print("ACOUSTICS silence=\(silence) constant=\(constant) two=\(two) variable=\(variable)")
   check(silence.speechSeconds < 0.5,"Silence not classified as active sound")
   check(constant.speechSeconds > 8,"Sustained periodic signal recognized as active sound")
   check(two.pauses >= 1,"One-second gap detected")
   check(variable.pitchSamples >= 15,"Sufficient stable periodic pitch samples")
   check((variable.pitchRange ?? 0) > 2,"Changing fundamental frequency yields nonzero pitch span")
 }
}
