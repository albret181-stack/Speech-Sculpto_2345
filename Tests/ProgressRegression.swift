import Foundation
@main struct ProgressRegression {
 static func check(_ c: Bool, _ message: String) {
   if !c { fputs("FAIL: \(message)\n",stderr); exit(1) }
   print("PASS: \(message)")
 }
 static func main() {
   let calendar=Calendar(identifier:.gregorian)
   let now=Date(timeIntervalSince1970: 1_800_000_000)
   func session(daysAgo: Int, words: Int, fillers: Int, practice: Bool = false, withReport: Bool = true) -> SpeechSession {
     let date=calendar.date(byAdding:.day,value:-daysAgo,to:now)!
     let text=Array(repeating:"слово",count:words).joined(separator:" ")
     let m=VoiceMetrics(words:words,fillerCount:fillers,fillersPer100:words>0 ? Double(fillers)*100/Double(words):0,wordsPerMinute:130,pauseCount:0,pausesPerMinute:0,pitchRangeSemitones:nil,measuredSpeechSeconds:45,reliablePitchSamples:0)
     let report=SpeechReport(createdAt:date,transcript:text,segments:[],metrics:m,fillerBreakdown:[:],issues:[],verdict:"",caveats:[],aiComment:nil)
     return SpeechSession(id:UUID(),title:"Тест",createdAt:date,duration:45,relativeAudioPath:"fixtures/example.m4a",isPractice:practice,report:withReport ? report : nil)
   }
   let input=[session(daysAgo:20,words:100,fillers:9),
              session(daysAgo:17,words:100,fillers:7),
              session(daysAgo:5,words:100,fillers:4),
              session(daysAgo:3,words:100,fillers:2),
              session(daysAgo:1,words:300,fillers:1,practice:true),
              session(daysAgo:2,words:30,fillers:10,withReport:false)]
   let month=ProgressAnalytics.window(input,days:30,now:now,calendar:calendar)
   check(month.recordings==5,"Recordings include unanalyzed, exclude exercises")
   check(month.analyzed==4,"Only valid analyzed ordinary records")
   check(month.words==400 && month.fillerCount==22,"Weighted numerator and denominator")
   check(abs((month.fillersPer100 ?? -1)-5.5)<0.0001,"Word-weighted rate")
   check(abs((month.change ?? 100)-(-5.0))<0.0001,"Conservative half-window trend")
   check(month.lessons==1,"Practice counted separately")
   let week=ProgressAnalytics.window(input,days:7,now:now,calendar:calendar)
   check(week.change==nil,"No comparison from thin data")
   check(week.analyzed==2,"Weekly filtering")
   check(ProgressAnalytics.window([],days:30,now:now,calendar:calendar).fillersPer100==nil,"No-data differs from zero")
   let days=ProgressAnalytics.daily(input,days:30,now:now,calendar:calendar)
   check(days.count==30 && days.filter{$0 != nil}.count==4,"Missing dates remain missing")
   print("Progress QA complete")
 }
}
