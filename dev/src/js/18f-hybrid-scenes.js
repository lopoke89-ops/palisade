/* v0.9.6.4 Hybrid Theory backgrounds: advanced 8-bit block skylines. The buildings, windows and signs are one cached layer;
   each frame only adds a few slow neon streaks and a window flicker (no per-frame allocation beyond the streak loop). */
const hyTone=(c,k)=>k>1?mix(c,'#ffffff',Math.min(1,(k-1)*.45)):mix(c,'#000000',1-k);   // lighter (k>1) or darker (k<1)
function paintHybridBackground(c,w,h,t,n,pal,moving){
  const [ground,acc,acc2]=pal;
  bgBlit(c,bgLayer('hybrid'+n,w,h,(x,w,h)=>{
    const night=n!==7;
    vgrad(x,w,h,[[0,ground],[.62,night?hyTone(ground,1.5):'#3a2a1c'],[1,hyTone(ground,.8)]]);
    // a pixel grid keeps it chunky: every shape snaps to a block
    const B=Math.max(4,Math.round(h/90)),snap=v=>Math.round(v/B)*B;
    // far skyline: flat blocks in a darker tone
    for(let i=0;i<14;i++){const bw=snap(w*(.05+hash(i,n+3)*.06)),bx=snap(i*w/13-w*.03),bh=snap(h*(.18+hash(i,n+7)*.22));x.fillStyle=hyTone(ground,1.35);x.fillRect(bx,snap(h*.62)-bh,bw,bh)}
    // near towers with lit windows in the accent colours
    for(let i=0;i<9;i++){const bw=snap(w*(.07+hash(i,n+11)*.07)),bx=snap(i*w/8.5-w*.02),bh=snap(h*(.28+hash(i,n+13)*.34)),by=snap(h*.78)-bh;
      x.fillStyle=n===7?'#6B4A32':hyTone(ground,1.7);x.fillRect(bx,by,bw,bh);x.fillStyle='rgba(0,0,0,.35)';x.fillRect(bx+bw-B,by,B,bh);
      for(let yy=by+B;yy<by+bh-B;yy+=B*2)for(let xx=bx+B;xx<bx+bw-B*1.5;xx+=B*2)if(hash(xx*7+yy,n+i)>.45){x.fillStyle=hash(xx+yy*3,n)>.7?acc2:acc;x.globalAlpha=.55+hash(xx,yy)*.45;x.fillRect(xx,yy,B,B)}
      x.globalAlpha=1;if(i%3===1){x.fillStyle=acc;x.fillRect(bx,by-B,bw,B)}}
    // street: a dark band with a neon curb line
    x.fillStyle=hyTone(ground,.7);x.fillRect(0,snap(h*.78),w,h);x.fillStyle=acc;x.fillRect(0,snap(h*.78),w,Math.max(2,B/2));
    if(n===4){x.strokeStyle=acc;x.lineWidth=Math.max(1,B/3);for(let i=0;i<4;i++){x.beginPath();x.moveTo(0,h*(.3+i*.06));x.quadraticCurveTo(w*.5,h*(.38+i*.06),w,h*(.3+i*.06));x.stroke()}}
    if(n===3){x.fillStyle=acc;for(let i=0;i<5;i++){const cx=snap(w*(.18+i*.16)),cy=snap(h*.2);x.fillRect(cx-B*2,cy,B*4,B);for(const k of[-2,0,2])x.fillRect(cx+k*B,cy-B*2,B,B*2)}}
    // the foreground stays dark enough for names and menu text
    vgrad(x,w,h,[[0,'rgba(5,8,14,0)'],[.6,'rgba(5,8,14,.08)'],[1,'rgba(5,8,14,.7)']]);
  }),w,h);
  if(!moving)return;
  c.save();c.globalCompositeOperation='lighter';
  // slow neon streaks sliding across the sky and along the street
  for(let i=0;i<4;i++){const y=h*(.12+i*.13+(i===3?.4:0)),len=w*.22,xx=((t*w*.05*(1+i*.3)+hash(i,n)*w)%(w+len))-len;
    c.globalAlpha=.35;c.fillStyle=i%2?pal[2]:pal[1];c.fillRect(xx,y,len,Math.max(2,h/160));c.globalAlpha=.15;c.fillRect(xx-len*.3,y-1,len*1.6,Math.max(4,h/80))}
  if(n===5){c.globalAlpha=.16;for(let j=0;j<3;j++){c.strokeStyle=['#78BE20','#4fd3b8','#9fe7a0'][j];c.lineWidth=h*.035;c.beginPath();for(let q=0;q<=16;q++){const xx=q/16*w,yy=h*(.14+j*.04)+Math.sin(q*.4+t*.25+j)*h*.03;q?c.lineTo(xx,yy):c.moveTo(xx,yy)}c.stroke()}}
  c.restore();
}
