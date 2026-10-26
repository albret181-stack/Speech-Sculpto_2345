#!/usr/bin/env python3
"""Offline WER and filler scoring. Reads LOCAL JSON; does not upload any audio or text."""
import argparse, json, re
from pathlib import Path

def tokens(s):
    return re.findall(r"[^\W_]+(?:[-’'][^\W_]+)*",s.casefold(),re.UNICODE)
def edits(ref,hyp):
    row=list(range(len(hyp)+1))
    for i,a in enumerate(ref,1):
        nxt=[i]+[0]*len(hyp)
        for j,b in enumerate(hyp,1):
            nxt[j]=min(row[j]+1,nxt[j-1]+1,row[j-1]+(a!=b))
        row=nxt
    return row[-1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("input",help="Private local JSON: array with id, reference, recognized")
    p.add_argument("--report",help="Optional local report path")
    args=p.parse_args()
    source=json.loads(Path(args.input).read_text(encoding="utf-8"))
    if not isinstance(source,list): raise ValueError("Expected JSON array")
    total_words=total_edits=0
    per=[]
    for item in source:
        ref=tokens(item["reference"]);hyp=tokens(item["recognized"])
        dist=edits(ref,hyp)
        total_words+=len(ref);total_edits+=dist
        per.append({"id":item["id"],"reference_words":len(ref),"edit_distance":dist,"wer":(dist/len(ref) if ref else None)})
    result={"files":len(per),"total_reference_words":total_words,"total_errors":total_edits,
            "micro_wer":total_edits/total_words if total_words else None,"items":per}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if args.report: Path(args.report).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
if __name__=="__main__": main()
