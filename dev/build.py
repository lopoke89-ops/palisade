import os,shutil,json,hashlib
from PIL import Image,ImageDraw
# Builds the playable site into the repo root (the folder above dev/), from dev/src/palisade.html.
# Usage: python3 dev/build.py            (needs Python 3 + Pillow for the icons)
DEV=os.path.dirname(os.path.abspath(__file__))
SITE=os.path.dirname(DEV)
os.makedirs(SITE,exist_ok=True)
src=open(f'{DEV}/src/palisade.html',encoding='utf-8').read()
head='''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">
<meta name="theme-color" content="#141210">
<meta name="description" content="Co-op isometric siege game. Build walls, hold the stake, survive five raids.">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Palisade">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
'''
src=src.replace('<title>Palisade Field Test</title>','<title>Palisade</title>',1)
# fonts live on our own site (cached for offline) instead of Google, so nothing third-party blocks the first screen
FONTS=[('Big Shoulders Stencil Display','big-shoulders-stencil-display',w) for w in (600,800,900)]+[('IBM Plex Mono','ibm-plex-mono',w) for w in (400,600)]
FSRC=DEV+'/vendor/fonts/{0}-{1}.woff2'
for fam,slug,w in FONTS: shutil.copy(FSRC.format(slug,w),f'{SITE}/{slug}-{w}.woff2')
face=''.join(f"@font-face{{font-family:'{fam}';font-style:normal;font-weight:{w};font-display:swap;src:url({slug}-{w}.woff2) format('woff2')}}\n" for fam,slug,w in FONTS)
gf=src[src.index('<link rel="preconnect" href="https://fonts.googleapis.com">'):src.index('<style>')]
src=src.replace(gf,'<link rel="preload" href="big-shoulders-stencil-display-900.woff2" as="font" type="font/woff2" crossorigin>\n<link rel="preload" href="ibm-plex-mono-400.woff2" as="font" type="font/woff2" crossorigin>\n',1)
src=src.replace('<style>','<style>\n'+face,1)
src=head+src.replace('<script>\n(()=>{','<script>window.PEER_SRC=\'peerjs.min.js\'</script>\n<script>\n(()=>{',1)+'\n</html>\n'
# swap </style>…body wrapper: the artifact file has no <body>, browsers infer it; fine.
src=src.replace('</style>\n','</style>\n</head>\n<body>\n',1)
src=src.replace('\n</html>\n','\n</body>\n</html>\n')
# the music file name carries its content hash, so a new track reaches players instead of the cached old one
for ext in ('m4a','ogg'):
    mh=hashlib.sha1(open(f'{DEV}/audio/between_raids.{ext}','rb').read()).hexdigest()[:8]
    src=src.replace(f"'between_raids.{ext}'",f"'between_raids.{ext}?v={mh}'",1)
open(f'{SITE}/index.html','w',encoding='utf-8').write(src)
shutil.copy(f'{DEV}/vendor/peerjs.min.js',f'{SITE}/peerjs.min.js')
for ext in ('m4a','ogg'):shutil.copy(f'{DEV}/audio/between_raids.{ext}',f'{SITE}/between_raids.{ext}')
def icon(n,pad=0.0,round_bg=False):
    S=512;im=Image.new('RGBA',(S,S),(20,18,16,255));d=ImageDraw.Draw(im)
    m=int(S*pad)
    # dusk sky band
    for y in range(S):
        t=y/S;c=(int(20+36*(1-t)),int(18+22*(1-t)),int(16+10*(1-t)),255);d.line([(0,y),(S,y)],fill=c)
    d.ellipse([S*.56,S*.14,S*.80,S*.38],fill=(226,180,54,255))   # low sun
    ground=S*.80
    d.rectangle([0,ground,S,S],fill=(28,24,18,255))
    n_st=6;x0=m+S*.12;x1=S-m-S*.12;w=(x1-x0)/n_st
    for k in range(n_st):
        L=x0+k*w+w*.08;R=x0+(k+1)*w-w*.08;top=S*(.30+(.05 if k%2 else 0));
        body=[(L,ground),(L,top+w*.5),((L+R)/2,top),(R,top+w*.5),(R,ground)]
        d.polygon(body,fill=(184,137,79,255),outline=(20,14,8,255))
        d.polygon([((L+R)/2,top),(R,top+w*.5),(R,ground),((L+R)/2,ground)],fill=(139,98,54,255))
        d.line([(L,top+w*.5),((L+R)/2,top),(R,top+w*.5),(R,ground),(L,ground),(L,top+w*.5)],fill=(20,14,8,255),width=6)
    for yy in (.52,.68):
        d.rectangle([x0-10,S*yy,x1+10,S*yy+S*.035],fill=(93,72,50,255),outline=(20,14,8,255),width=4)
    return im.resize((n,n),Image.LANCZOS)
icon(180).convert('RGB').save(f'{SITE}/apple-touch-icon.png')
icon(192).save(f'{SITE}/icon-192.png');icon(512).save(f'{SITE}/icon-512.png')
icon(512,pad=.1).save(f'{SITE}/icon-maskable-512.png')
json.dump({"name":"PALISADE","short_name":"Palisade","description":"Co-op isometric siege game. Build walls, hold the stake, survive five raids.",
 "start_url":"./","scope":"./","display":"fullscreen","orientation":"any","background_color":"#141210","theme_color":"#141210",
 "icons":[{"src":"icon-192.png","sizes":"192x192","type":"image/png"},{"src":"icon-512.png","sizes":"512x512","type":"image/png"},
  {"src":"icon-maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}]},open(f'{SITE}/manifest.webmanifest','w'),indent=1)
ver=hashlib.sha1((src+open(f'{SITE}/peerjs.min.js').read()).encode()).hexdigest()[:10]
FONTFILES=''.join(f",'{slug}-{w}.woff2'" for fam,slug,w in FONTS)
open(f'{SITE}/sw.js','w').write(f'''// Keeps a copy of the game on the phone so solo works with no signal.
// The version below changes every time the game is rebuilt, which swaps in the new copy.
const V='palisade-{ver}';
const FILES=['./','index.html','peerjs.min.js','manifest.webmanifest','icon-192.png','icon-512.png','apple-touch-icon.png'{FONTFILES}];
self.addEventListener('install',e=>{{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))}});
// music is big and rarely changes, so it lives in its own cache that survives game updates (saved the first time it plays)
const M='palisade-media-1';
self.addEventListener('activate',e=>{{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&k!==M).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))}});
self.addEventListener('fetch',e=>{{
  const r=e.request;if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;
  // the page itself: try the network so updates land, but on a slow or dead connection
  // open the saved copy after 2.5 s instead of waiting (the download still finishes and is saved for next time)
  if(r.mode==='navigate'){{
    let save;const net=fetch(r).then(res=>{{if(res.ok){{const c=res.clone();save=caches.open(V).then(k=>k.put('index.html',c))}}return res}});
    e.waitUntil(net.then(()=>save,()=>{{}}).catch(()=>{{}}));
    const saved=caches.match('index.html');
    e.respondWith(new Promise(done=>{{
      let over=false;const give=x=>{{if(!over&&x){{over=true;done(x)}}}};
      net.then(give,()=>saved.then(s=>give(s||Response.error())));
      setTimeout(()=>saved.then(give),2500);
    }}));return}}
  if(/\.(m4a|ogg)$/.test(new URL(r.url).pathname)){{e.respondWith(caches.open(M).then(c=>c.match(r).then(hit=>hit||fetch(r).then(res=>{{if(res.ok){{c.put(r,res.clone());c.keys().then(ks=>ks.forEach(k=>{{const u=new URL(k.url);if(u.pathname===new URL(r.url).pathname&&k.url!==r.url)c.delete(k)}}))}}return res}}))));return}}
  e.respondWith(caches.match(r).then(hit=>hit||fetch(r)));
}});
''')
print('site built',ver,os.listdir(SITE))
