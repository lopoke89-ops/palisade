"""Original, deterministic synth effects for the nine Understrip weapons. Run with Python 3."""
import math, random, struct, wave
from pathlib import Path
RATE=44100
OUT=Path(__file__).resolve().parent.parent/'sfx'
def render(name, seconds, recipe):
    rng=random.Random(name)
    values=[]
    low=0.0
    phase=0.0
    for i in range(int(RATE*seconds)):
        t=i/RATE
        noise=rng.uniform(-1,1)
        low+=.12*(noise-low)
        high=noise-low
        # Frequency sweeps are integrated, avoiding discontinuous chirps.
        if name=='sawnoff':
            v=.65*noise*math.exp(-t*36)+.65*math.sin(2*math.pi*70*t)*math.exp(-t*15)+.18*low*math.exp(-t*9)
        elif name=='taser':
            phase+=2*math.pi*(1500+500*math.sin(t*95))/RATE
            v=(.42*math.sin(phase)+.22*high)*math.exp(-t*19)*(1 if math.sin(t*620)>-.4 else .15)
        elif name=='nailgun':
            v=.6*high*math.exp(-t*150)+.30*math.sin(2*math.pi*680*t)*math.exp(-t*55)
            if t>.025: v+=.25*noise*math.exp(-(t-.025)*170)
        elif name=='smg':
            v=.70*noise*math.exp(-t*95)+.40*math.sin(2*math.pi*155*t)*math.exp(-t*60)
        elif name=='flare':
            v=.65*math.sin(2*math.pi*95*t)*math.exp(-t*23)+.45*low*math.exp(-t*6)+.16*high*math.exp(-t*28)
        elif name=='riot':
            v=.75*noise*math.exp(-t*47)+.6*math.sin(2*math.pi*90*t)*math.exp(-t*18)
            if t>.065: v+=.22*high*math.exp(-(t-.065)*65)
        elif name=='laser':
            phase+=2*math.pi*(2200*math.exp(-t*17)+210)/RATE
            v=(.65*math.sin(phase)+.16*math.sin(phase*2.01))*math.exp(-t*17)+.10*high*math.exp(-t*120)
        elif name=='alien':
            phase+=2*math.pi*(780*math.exp(-t*8)+95)/RATE
            v=(.50*math.sin(phase)+.23*math.sin(phase*.503)+.18*math.sin(phase*1.51))*math.exp(-t*8)+.09*low*math.exp(-t*14)
        else:  # anti-grav: low pressure thump with a rising, beating coil tail
            phase+=2*math.pi*(130+700*t)/RATE
            v=.60*math.sin(2*math.pi*48*t)*math.exp(-t*8)+.34*math.sin(phase)*math.sin(t*45)*math.exp(-t*7)+.25*low*math.exp(-t*14)
        fade=min(1,t/.0008)*min(1,(seconds-t)/.015)
        values.append(v*fade)
    peak=max(abs(v) for v in values)
    data=b''.join(struct.pack('<h',round(v/peak*.5*32767)) for v in values)
    with wave.open(str(OUT/('us_'+name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data)
    print(name,len(values),'samples')
if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    for name,seconds in [('sawnoff',.38),('taser',.23),('nailgun',.12),('smg',.10),('flare',.55),('riot',.34),('laser',.24),('alien',.48),('antigrav',.65)]:
        render(name,seconds,None)
