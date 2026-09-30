// Keeps a copy of the game on the phone so solo works with no signal.
// The version below changes every time the game is rebuilt, which swaps in the new copy.
const V='palisade-1fb302aa9c';
const FILES=['./','index.html','peerjs.min.js','manifest.webmanifest','icon-192.png','icon-512.png','apple-touch-icon.png','big-shoulders-stencil-display-600.woff2','big-shoulders-stencil-display-800.woff2','big-shoulders-stencil-display-900.woff2','ibm-plex-mono-400.woff2','ibm-plex-mono-600.woff2'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
// music is big and rarely changes, so it lives in its own cache that survives game updates (saved the first time it plays)
const M='palisade-media-1';
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&k!==M).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
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
