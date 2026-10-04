// v0.9.8.3 Frostpeak: no cliff face paints over a staircase or ramp. Cliff faces are drawn in magenta (FROST_MARK) and
// no magenta pixel may land inside any connector's sloped top, at standard and XL sizes, with the camera on each of the
// 8 connectors. Screenshots in out/frost_conn_*.png. node frost_connectors.js
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const size of['std','xl']){
  const p=await b.newPage({viewport:{width:1366,height:820}});p.on('pageerror',e=>errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  await p.evaluate(async size=>{const P=__pal;P.pick.mode='5';P.pick.map='frost';P.pick.size=size;P.showPage('solo');document.getElementById('startBtn').click();await new Promise(r=>setTimeout(r,800));P.game.paused=true},size);
  out[size]=await p.evaluate(async()=>{const P=__pal,N=P.N,res=[],cv=document.getElementById('game'),sc=cv.width/innerWidth;
   const runs=[];for(let j=0;j<N;j++)for(const r of P.frostRuns(j))runs.push([j,...r]);
   for(const [j,i0,i1]of runs){P.player.x=(i0+i1)/2+.5;P.player.y=j+1.4;P.game.paused=false;await new Promise(r=>setTimeout(r,350));P.game.paused=true;
    P.frostMark('#ff00ff');await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
    // the sloped top of the run, shrunk a hair so edge anti-aliasing doesn't count
    const z=P.heights[j*N+i0],q=[[i0+.04,j+.04,z+.96],[i1+.96,j+.04,z+.96],[i1+.96,j+.96,z+.04],[i0+.04,j+.96,z+.04]].map(([x,y,h])=>P.iso(x,y,h));
    const x0=Math.floor(Math.min(...q.map(v=>v[0]))),x1=Math.ceil(Math.max(...q.map(v=>v[0]))),y0=Math.floor(Math.min(...q.map(v=>v[1]))),y1=Math.ceil(Math.max(...q.map(v=>v[1])));
    const ctx=cv.getContext('2d'),img=ctx.getImageData(Math.round(x0*sc),Math.round(y0*sc),Math.max(1,Math.round((x1-x0)*sc)),Math.max(1,Math.round((y1-y0)*sc)));
    const inside=(x,y)=>{let c=false;for(let a=0,bb=3;a<4;bb=a++){const [xa,ya]=q[a],[xb,yb]=q[bb];if((ya>y)!==(yb>y)&&x<(xb-xa)*(y-ya)/(yb-ya)+xa)c=!c}return c};
    let mag=0,px=0;for(let yy=0;yy<img.height;yy++)for(let xx=0;xx<img.width;xx++){const X=x0+xx/sc,Y=y0+yy/sc;if(!inside(X,Y))continue;px++;const o=(yy*img.width+xx)*4,d=img.data;if(d[o]>200&&d[o+1]<80&&d[o+2]>200)mag++}
    P.frostMark(null);res.push({row:j,cols:i0+'-'+i1,px,mag})}
   return res});
  await p.evaluate(()=>{__pal.player.x=__pal.frostRuns(__pal.N>16?7:5)[1][0]+1.5;__pal.player.y=(__pal.N>16?7:5)+1.4;__pal.game.paused=false});await p.waitForTimeout(500);
  await p.screenshot({path:`${__dirname}/out/frost_conn_${size}.png`,clip:{x:483,y:200,width:400,height:300}});await p.close()}
 fs.writeFileSync(__dirname+'/out/frost_connectors.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 for(const [size,res]of Object.entries(out)){assert.equal(res.length,4,size+': 4 connectors (a ramp and a staircase per terrace step)');for(const r of res){assert.ok(r.px>200,size+' row '+r.row+' measured '+r.px);assert.equal(r.mag,0,size+' row '+r.row+' cols '+r.cols+': a cliff face paints over the steps ('+r.mag+' px)')}}
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
