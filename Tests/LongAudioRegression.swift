import Foundation
import AVFoundation
@main struct LongAudioRegression {
 static func main() throws {
  for path in CommandLine.arguments.dropFirst() {
   let url=URL(fileURLWithPath:path)
   let file=try AVAudioFile(forReading:url)
   let chunkFrames=AVAudioFramePosition(file.processingFormat.sampleRate * 30)
   var pos: AVAudioFramePosition=0
   var total: AVAudioFramePosition=0
   var count=0
   while pos < file.length {
    let length=min(chunkFrames,file.length-pos)
    let chunk=try SpeechAudioChunks.makeChunk(from:file,at:pos,frameCount:length)
    let checked=try AVAudioFile(forReading:chunk)
    guard checked.length == length else { fatalError("Chunk length mismatch") }
    try FileManager.default.removeItem(at:chunk)
    total+=length;pos+=length;count+=1
   }
   guard total == file.length else { fatalError("Source frame count changed") }
   print("PASS \(url.lastPathComponent): \(count) chunks, \(total) frames")
  }
}
