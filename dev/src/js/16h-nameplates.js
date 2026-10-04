/* ---------- v0.9.9 nameplates: health above heads (the top-left health panel is gone during matches) ---------- */
// You: a bar and your number above your head. Teammates and Delgado: their name and a bar. In PvP the other side
// shows names only. Downed players keep the revive ring and countdown instead. Teammates off screen get an edge arrow
// with their name (blinking red while downed). Drawn after the lighting so plates read at night and behind buildings.
const plateFriend=o=>!game.pvp||game.pvp==='base'&&o.team===player.team||o===player;
function plateBar(x,y,w,h,frac,col,pulse){
  g.fillStyle='rgba(10,8,6,.82)';g.fillRect(x-w/2-1,y-1,w+2,h+2);
  const low=frac<.3,c=low?(pulse?'#ff5a3a':'#d6402a'):col;g.fillStyle=c;g.fillRect(x-w/2,y,w*Math.max(0,Math.min(1,frac)),h)}
function drawNameplates(){
  if(demo||!player)return;
  const p=player,t=game.time,pulse=Math.sin(t*9)>0,bo=game.bo&&game.bo.stage==='ready',rec=drawNameplates.out=[];   // rec: what was drawn, for the tests
  const W1=Math.max(26,Math.min(44,34*u)),W0=Math.max(30,Math.min(50,40*u)),BH=Math.max(3.5,Math.min(6,4.4*u));
  for(const o of players.values()){if(!o.alive)continue;const me=o===p,friend=plateFriend(o);if(!me&&stealthed(o)&&!friend)continue;
    const c=iso(o.x,o.y),top=c[1]-46*u,alpha=o.prot>0||stealthed(o)?.55:1;g.globalAlpha=alpha;
    const tick=bo&&o.boReady?' ✓':'';
    rec.push({who:me?'me':o.name,bar:me||friend,frac:o.hp/o.max,x:c[0],y:top,num:me?Math.ceil(o.hp):null,tick:!!tick});
    if(me){plateBar(c[0],top-2*u,W0,BH*1.2,o.hp/o.max,'#e8dcc0',pulse);label(Math.ceil(o.hp)+tick,c[0],top-7*u,o.hp/o.max<.3?'#ff8a6a':'#f2ead6',10)}
    else{const col=game.pvp?teamCol(o):SLOTCOL[o.slot%6];label((o.name||'PLAYER').toUpperCase()+tick,c[0],top-(friend?7:2)*u,col,9);if(friend)plateBar(c[0],top-2*u,W1,BH,o.hp/o.max,col,pulse)}
    g.globalAlpha=1}
  if(!game.pvp&&qm.alive&&!qm.gone){const c=iso(qm.x,qm.y),top=c[1]-46*u;rec.push({who:'DELGADO',bar:true,frac:qm.hp/qm.max,x:c[0],y:top});label('DELGADO',c[0],top-7*u,'#d6c47a',9);plateBar(c[0],top-2*u,W1,BH,qm.hp/qm.max,'#d6c47a',pulse)}
  // teammates off screen: an arrow on the edge with their name; downed ones blink red
  const m=26,topM=110;
  for(const o of players.values()){if(o===p||!plateFriend(o))continue;
    const c=iso(o.x,o.y);if(c[0]>m&&c[0]<W-m&&c[1]>topM&&c[1]<H-m)continue;
    const ex=Math.max(m,Math.min(W-m,c[0])),ey=Math.max(topM+10,Math.min(H-m,c[1])),a=Math.atan2(c[1]-H/2,c[0]-W/2),down=!o.alive,col=down?(pulse?'#ff4a3a':'#7a2218'):SLOTCOL[o.slot%6];
    rec.push({arrow:o.name,down,x:ex,y:ey});
    g.save();g.translate(ex,ey);g.rotate(a);g.fillStyle=col;g.strokeStyle='rgba(10,8,6,.85)';g.lineWidth=1.5;g.beginPath();g.moveTo(11,0);g.lineTo(-6,-8);g.lineTo(-2,0);g.lineTo(-6,8);g.closePath();g.stroke();g.fill();g.restore();
    label((o.name||'PLAYER').toUpperCase()+(down?' · DOWN':''),ex,ey+(ey>H/2?-16:20),down?'#ff8a6a':col,9)}
  // your own low health: a faint red edge, pulsing
  if(p.alive&&p.hp/p.max<.3&&playing()){rec.push({lowGlow:true});const k=(.3-p.hp/p.max)/.3,al=(.18+.12*Math.sin(t*6))*Math.min(1,k*1.6+.3);
    if(!drawNameplates.v||drawNameplates.vw!==W||drawNameplates.vh!==H){const v=document.createElement('canvas');v.width=Math.ceil(W/2);v.height=Math.ceil(H/2);const x=v.getContext('2d'),gr=x.createRadialGradient(v.width/2,v.height/2,Math.min(v.width,v.height)*.3,v.width/2,v.height/2,Math.max(v.width,v.height)*.7);
      gr.addColorStop(0,'rgba(200,20,10,0)');gr.addColorStop(1,'rgba(200,20,10,1)');x.fillStyle=gr;x.fillRect(0,0,v.width,v.height);drawNameplates.v=v;drawNameplates.vw=W;drawNameplates.vh=H}
    g.globalAlpha=al;g.drawImage(drawNameplates.v,0,0,W,H);g.globalAlpha=1}
}
