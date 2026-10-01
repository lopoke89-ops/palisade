/* Winter scenes: one bounded cached landscape plus four small motion overlays. */
function paintWinterBackground(c,w,h,t,n,moving){
  bgBlit(c,bgLayer('winter'+n,w,h,(x,w,h)=>{
    const night=n===5||n>=6,sky=night?'#102332':'#355d73';vgrad(x,w,h,[[0,sky],[.65,night?'#304b5f':'#8bb9cd'],[1,'#bccfda']]);
    const poly=(p,col)=>{x.fillStyle=col;x.beginPath();p.forEach((q,i)=>i?x.lineTo(q[0]*w,q[1]*h):x.moveTo(q[0]*w,q[1]*h));x.closePath();x.fill()};
    for(let j=0;j<3;j++){const y=.45+j*.13;poly([[0,y+.12],[.16,y-.08],[.29,y+.06],[.47,y-.19],[.68,y+.03],[.82,y-.1],[1,y+.1],[1,1],[0,1]],['#587b91','#7396a9','#aecbd8'][j]);poly([[.4,y-.105],[.47,y-.19],[.55,y-.075],[.48,y-.095],[.45,y-.07]],'#eaf3f6')}
    bgTrees(x,w,h,h*.81,'#294958',84+n);poly([[0,.88],[.35,.8],[.64,.87],[1,.78],[1,1],[0,1]],'#bed6e0');
    const hut=(a,b,ww,hh,col)=>{x.fillStyle=col;x.fillRect(a*w,b*h,ww*w,hh*h);poly([[a-.015,b],[a+ww*.5,b-.06],[a+ww+.015,b],[a+ww,b+.018],[a,b+.018]],'#dfedf2');x.fillStyle=night?'#e9b868':'#426b7e';for(let i=0;i<3;i++)x.fillRect((a+.02+i*ww*.27)*w,(b+.035)*h,ww*w*.16,hh*h*.28);x.fillStyle='#274553';x.fillRect((a+ww*.68)*w,(b+hh*.42)*h,ww*w*.2,hh*h*.58)};
    if(n===0||n===5||n===6){hut(.12,.66,.25,.18,'#3b5663');hut(.71,.71,.15,.12,'#455c68');x.strokeStyle='#4c626a';x.lineWidth=3;x.beginPath();x.moveTo(w*.48,h*.8);x.lineTo(w*.48,h*.51);x.stroke();poly([[.48,.53],[.58,.55],[.48,.58]],'#b2504b')}
    if(n===1){poly([[0,.87],[.33,.7],[.44,.73],[1,.87],[1,.94],[.43,.79],[.34,.77],[0,.95]],'#6599ad');x.strokeStyle='#c5e6ee';x.lineWidth=2;for(let i=0;i<8;i++){x.beginPath();x.moveTo(w*(i/8),h*.88);x.lineTo(w*(i/8+.12),h*.87);x.stroke()}hut(.74,.65,.19,.16,'#4b626e')}
    if(n===2){for(let i=0;i<4;i++)poly([[.03+i*.12,.78-i*.03],[.38+i*.1,.73-i*.035],[.47+i*.1,.77-i*.035],[.07+i*.12,.83-i*.03]],i%2?'#8198a5':'#526d7d');hut(.71,.7,.19,.15,'#536670');x.strokeStyle='#344c5c';x.lineWidth=5;x.beginPath();x.moveTo(w*.16,h*.7);x.lineTo(w*.16,h*.36);x.lineTo(w*.63,h*.5);x.stroke()}
    if(n===3){hut(.12,.69,.34,.18,'#5b665e');x.strokeStyle='#324a5a';x.lineWidth=2;x.beginPath();x.moveTo(0,h*.39);x.lineTo(w,h*.55);x.stroke();for(let i=0;i<4;i++){const a=.14+i*.21,b=.41+i*.03;x.fillStyle='#496274';x.fillRect(a*w,b*h,w*.055,h*.06);x.strokeRect(a*w,b*h,w*.055,h*.06)}}
    if(n===4){hut(.65,.63,.23,.22,'#546676');for(let i=0;i<5;i++){x.fillStyle=i%2?'#6e806f':'#637281';x.fillRect(w*(.1+i*.08),h*(.82-i%2*.04),w*.07,h*.075);x.fillStyle='#d9e9ef';x.fillRect(w*(.1+i*.08),h*(.82-i%2*.04),w*.07,3)}}
    if(n===7){x.fillStyle='#334e5f';x.fillRect(w*.2,h*.43,w*.14,h*.34);poly([[.15,.43],[.39,.43],[.35,.4],[.19,.4]],'#d7e9f1');x.fillStyle='#99c1cf';x.fillRect(w*.225,h*.45,w*.09,h*.09);hut(.69,.75,.15,.12,'#536674')}
    if(n===8){hut(.09,.58,.38,.29,'#5d5056');poly([[.12,.85],[.44,.85],[.44,.67],[.12,.67]],'#1a303b');x.fillStyle='#6c9c91';x.fillRect(w*.76,h*.69,w*.1,h*.18);poly([[.72,.74],[.81,.59],[.9,.74]],'#467f6b');x.strokeStyle='#bd6860';x.lineWidth=3;x.beginPath();x.moveTo(w*.12,h*.65);x.lineTo(w*.44,h*.65);x.stroke()}
    if(n===9){hut(.73,.7,.17,.15,'#3b4e60');x.strokeStyle='#e2bd65';x.lineWidth=2;x.beginPath();x.ellipse(w*.33,h*.87,w*.13,h*.025,0,0,Math.PI*2);x.stroke();x.fillStyle='#30434e';x.fillRect(w*.65,h*.36,w*.13,h*.03);x.strokeStyle='#6e8c9b';x.beginPath();x.moveTo(w*.6,h*.345);x.lineTo(w*.83,h*.345);x.stroke()}
    // The foreground stays dark enough for character names and menu text.
    vgrad(x,w,h,[[0,'rgba(7,18,29,0)'],[.6,'rgba(7,18,29,.05)'],[1,'rgba(7,18,29,.72)']]);
  }),w,h);
  if(!moving)return;c.save();
  if(n===6){for(let j=0;j<3;j++){c.strokeStyle=['#83e8c1','#73cddf','#ad9ce8'][j];c.globalAlpha=.2;c.lineWidth=h*.045;c.beginPath();for(let q=0;q<=20;q++){const xx=q/20*w,yy=h*(.18+j*.045)+Math.sin(q*.25+t*.2+j)*h*.045;q?c.lineTo(xx,yy):c.moveTo(xx,yy)}c.stroke()}}
  if(n===7||n===9){c.globalAlpha=.12;c.fillStyle='#e6f7ff';const xx=w*(n===7?.27:.73),yy=h*(n===7?.47:.74),a=Math.sin(t*.25)*.7;c.beginPath();c.moveTo(xx,yy);c.lineTo(xx+Math.cos(a)*w*.65,yy+Math.sin(a)*h*.35-h*.35);c.lineTo(xx+Math.cos(a+.22)*w*.65,yy+Math.sin(a+.22)*h*.35-h*.35);c.fill()}
  if(n===8){for(let i=0;i<9;i++){c.globalAlpha=.6+.2*Math.sin(t*.8+i);cosmeticGlow(c,w*(.13+i*.038),h*.65,5,['#ffb96d','#9de5d5','#dd849d'][i%3],.6)}for(let i=0;i<4;i++){c.globalAlpha=.12;c.fillStyle='#e5edf1';c.beginPath();c.ellipse(w*(.2+i*.025)+Math.sin(t+i)*3,h*(.64-((t*.03+i*.1)% .2)),w*.03,h*.04,0,0,Math.PI*2);c.fill()}}
  c.globalAlpha=.45;for(let i=0;i<24;i++){const xx=(hash(i,n+30)*w+t*(n===7?32:7))%(w+12)-6,yy=(hash(i,n+51)*h+t*(n===7?18:11))%h;c.fillStyle='#dcf5ff';c.fillRect(xx,yy,i%5?1.5:2.5,1.5)}c.restore();
}
