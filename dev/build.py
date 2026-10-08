import os,shutil,json,hashlib,base64
from PIL import Image,ImageDraw
# Builds the playable site into the repo root (the folder above dev/), from the pieces in dev/src
# (page.html + style.css + js/*.js, joined in file-name order by assemble.py).
# Usage: python3 dev/build.py            (needs Python 3 + Pillow for the icons)
DEV=os.path.dirname(os.path.abspath(__file__))
SITE=os.environ.get('PALISADE_BUILD_OUTPUT') or os.path.dirname(DEV)
os.makedirs(SITE,exist_ok=True)
import sys;sys.path.insert(0,DEV)
from assemble import assemble
src=assemble(f'{DEV}/src')
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
# music: each file name carries its content hash, so a new track reaches players instead of the cached old one
MUSIC_FILES=['between_raids','main_menu','raid_attitude','raid_cool','raid_express','final_blitz','results',*(f'casino_{n}' for n in range(1,12))]   # v0.10.1: the casino playlist
# Only obsolete generated release files are removed; original masters are preserved.
for old in ('locker.m4a','locker.ogg','raid.m4a','raid.ogg'):
    p=os.path.join(SITE,old)
    if os.path.isfile(p):os.remove(p)
MEDIA_NOW=[]   # v0.9.7.2: the current music URLs; the service worker drops cached music that isn't one of them
for name in MUSIC_FILES:
    for ext in ('m4a','ogg'):
        mh=hashlib.sha1(open(f'{DEV}/audio/{name}.{ext}','rb').read()).hexdigest()[:8];MEDIA_NOW.append(f'{name}.{ext}?v={mh}')
        assert f"'{name}.{ext}'" in src,f'{name}.{ext} not referenced in the game'
        src=src.replace(f"'{name}.{ext}'",f"'{name}.{ext}?v={mh}'",1)
        shutil.copy(f'{DEV}/audio/{name}.{ext}',f'{SITE}/{name}.{ext}')
# two copies of the page: debug.html keeps the test hooks (?debug) and profiler marks, for dev/test only
# (never published: it's in .gitignore); index.html, the one players get, has both stripped
import re,subprocess
debug_src=src
DEBUG_LINE=re.compile(r"^if\(new URLSearchParams\(location\.search\)\.has\('debug'\)\)window\.__pal=.*$\n",re.M)
assert len(DEBUG_LINE.findall(src))==1,'debug hook line not found'
src=DEBUG_LINE.sub('',src)
src=re.sub(r"\bPM\('\w+'\);?",'',src)
# minify the game's script when terser is installed (npm install in dev/test brings it); otherwise ship it as is
def find_terser():
    local=f'{DEV}/test/node_modules/terser/bin/terser'
    if os.path.exists(local):return [shutil.which('node') or 'node',local]
    for c in [os.environ.get('TERSER'),shutil.which('terser'),'/tmp/tools/node_modules/.bin/terser']:
        if c and os.path.exists(c):return [c]
def minify(page):
    t=find_terser()
    if not t:print('note: terser not found, game script not minified');return page
    a=page.index('<script>\n(()=>{')+len('<script>\n');e=page.index('</script>',a)
    r=subprocess.run([*t,'--compress','passes=2','--mangle','--ecma','2020'],input=page[a:e],capture_output=True,text=True,encoding='utf-8')
    if r.returncode:raise SystemExit('terser failed: '+r.stderr[:500])
    return page[:a]+r.stdout+page[e:]
src=minify(src)
# NOMIN=1 leaves debug.html unminified (readable names in a profiler); index.html is always minified
if not os.environ.get('NOMIN'):debug_src=minify(debug_src)
def add_csp(page,debug=False):
    scripts=re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>',page,re.S)
    assert len(scripts)==2,'CSP hashes require both inline scripts'
    hashes=['\'sha256-'+base64.b64encode(hashlib.sha256(s.encode('utf-8')).digest()).decode('ascii')+'\'' for s in scripts]
    connect=["'self'",'https://puvjfhwxigxjpsvdwrwf.supabase.co',
             'https://palisade-turn.lopoke89.workers.dev','https://0.peerjs.com','wss://0.peerjs.com']
    casino_config=json.load(open(os.environ.get('PALISADE_CASINO_CONFIG') or f'{DEV}/render/client.json',encoding='utf-8'))
    if casino_config.get('supabaseUrl'):connect += [casino_config['supabaseUrl']]
    if casino_config.get('url'):
        from urllib.parse import urlparse
        endpoint=casino_config['url'].rstrip('/')
        assert urlparse(endpoint).scheme=='https' and urlparse(endpoint).hostname,'Casino URL must use HTTPS'
        connect += [endpoint,endpoint.replace('https://','wss://',1)]
    if debug:connect+=['http://127.0.0.1:9000','ws://127.0.0.1:9000','http://localhost:9000','ws://localhost:9000']
    if debug:connect+=['http://127.0.0.1:10000','ws://127.0.0.1:10000']
    policy='; '.join(["default-src 'self'","base-uri 'none'","object-src 'none'",
        'script-src '+' '.join(hashes+["'strict-dynamic'"]),"style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob:","font-src 'self'","media-src 'self' blob:",
        'connect-src '+' '.join(connect),"worker-src 'self' blob:","frame-src 'none'"])
    return page.replace('<head>','<head>\n<meta http-equiv="Content-Security-Policy" content="'+policy+'">',1)
src=add_csp(src)
debug_src=add_csp(debug_src,True)
open(f'{SITE}/index.html','w',encoding='utf-8').write(src)
open(f'{SITE}/debug.html','w',encoding='utf-8').write(debug_src)
shutil.copy(f'{DEV}/vendor/peerjs.min.js',f'{SITE}/peerjs.min.js')
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
const M='palisade-media-2',MEDIA_NOW={json.dumps(MEDIA_NOW)};
// a replaced track (v0.9.7.2: the new main menu music) gets a new ?v= hash; the old copy is dropped here, the rest stay
const pruneMedia=()=>caches.open(M).then(c=>c.keys().then(rs=>Promise.all(rs.filter(r=>{{const u=new URL(r.url);return /\.(m4a|ogg)$/.test(u.pathname)&&!MEDIA_NOW.includes(u.pathname.split('/').pop()+u.search)}}).map(r=>c.delete(r)))));
self.addEventListener('activate',e=>{{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&k!==M).map(k=>caches.delete(k)))).then(pruneMedia).then(()=>self.clients.claim()))}});
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
