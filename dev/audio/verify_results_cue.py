"""Compare decoded AAC/Opus opening samples with original Sacrifices at 164 s."""
import json, os, subprocess
from pathlib import Path
import numpy as np

root=Path(__file__).resolve().parent
manifest=json.loads((root/'music-manifest.json').read_text(encoding='utf-8'))
entry=manifest['tracks']['results'];exe=os.environ['FFMPEG']
def pcm(path,start=0):
    args=[exe,'-hide_banner','-loglevel','error','-i',str(path)]
    if start:args+=['-ss',str(start)]
    data=subprocess.check_output([*args,'-t','6','-map','0:a:0','-vn','-ac','1','-ar','12000','-f','f32le','-'])
    return np.frombuffer(data,dtype='<f4').astype('float64')
original=pcm(entry['source'],164);results={}
for ext in ['m4a','ogg']:
    decoded=pcm(root/f'results.{ext}')
    # Check a full six-second audible segment, including encoder-delay tolerance.
    length=min(len(original),len(decoded));a=original[:length]-np.mean(original[:length]);b=decoded[:length]-np.mean(decoded[:length])
    size=1<<(2*length-1).bit_length();corr=np.fft.irfft(np.fft.rfft(a,size)*np.conj(np.fft.rfft(b,size)),size)
    shifts=np.arange(-600,601);best=int(shifts[np.argmax(corr[shifts%size])]);
    aa=a[max(best,0):length+min(best,0)];bb=b[max(-best,0):length-min(best,0)];score=float(np.corrcoef(aa,bb)[0,1])
    assert abs(best)<=24 and score>.98,(ext,best,score)
    results[ext]={'sourceCueSeconds':164,'offsetMilliseconds':best/12,'decodedCorrelation':score,'samplesCompared':len(aa)}
output=Path('dev/test/out/results-cue.json');output.write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8');print(json.dumps(results))
