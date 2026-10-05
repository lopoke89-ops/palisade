// Keeps a copy of the game on the phone so solo works with no signal.
// The version below changes every time the game is rebuilt, which swaps in the new copy.
const V='palisade-6480bdf07b';
const FILES=['./','index.html','peerjs.min.js','manifest.webmanifest','icon-192.png','icon-512.png','apple-touch-icon.png','big-shoulders-stencil-display-600.woff2','big-shoulders-stencil-display-800.woff2','big-shoulders-stencil-display-900.woff2','ibm-plex-mono-400.woff2','ibm-plex-mono-600.woff2'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
// music is big and rarely changes, so it lives in its own cache that survives game updates (saved the first time it plays)
const M='palisade-media-2',MEDIA_NOW=["between_raids.m4a?v=aa9a8665", "between_raids.ogg?v=a1f1b62d", "main_menu.m4a?v=ca29f3ba", "main_menu.ogg?v=67d3ca9a", "raid_attitude.m4a?v=c7e80c9f", "raid_attitude.ogg?v=a2b2066d", "raid_cool.m4a?v=997e86b1", "raid_cool.ogg?v=4bde7713", "raid_express.m4a?v=b05411fb", "raid_express.ogg?v=256dd5bb", "final_blitz.m4a?v=d0c14f25", "final_blitz.ogg?v=34e120e0", "results.m4a?v=4b3e1a44", "results.ogg?v=2c93f237"];
// a replaced track (v0.9.7.2: the new main menu music) gets a new ?v= hash; the old copy is dropped here, the rest stay
const pruneMedia=()=>caches.open(M).then(c=>c.keys().then(rs=>Promise.all(rs.filter(r=>{const u=new URL(r.url);return /\.(m4a|ogg)$/.test(u.pathname)&&!MEDIA_NOW.includes(u.pathname.split('/').pop()+u.search)}).map(r=>c.delete(r)))));
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&k!==M).map(k=>caches.delete(k)))).then(pruneMedia).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  const r=e.request;if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;
  // the page itself: try the network so updates land, but on a slow or dead connection
  // open the saved copy after 2.5 s instead of waiting (the download still finishes and is saved for next time)
  if(r.mode==='navigate'){
    let save;const net=fetch(r).then(res=>{if(res.ok){const c=res.clone();save=caches.open(V).then(k=>k.put('index.html',c))}return res});
    e.waitUntil(net.then(()=>save,()=>{}).catch(()=>{}));
    const saved=caches.match('index.html');
    e.respondWith(new Promise(done=>{
      let over=false;const give=x=>{if(!over&&x){over=true;done(x)}};
      net.then(give,()=>saved.then(s=>give(s||Response.error())));
      setTimeout(()=>saved.then(give),2500);
    }));return}
  if(/\.(m4a|ogg)$/.test(new URL(r.url).pathname)){e.respondWith(caches.open(M).then(c=>c.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok){c.put(r,res.clone());c.keys().then(ks=>ks.forEach(k=>{const u=new URL(k.url);if(u.pathname===new URL(r.url).pathname&&k.url!==r.url)c.delete(k)}))}return res}))));return}
  e.respondWith(caches.match(r).then(hit=>hit||fetch(r)));
});
