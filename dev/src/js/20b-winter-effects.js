/* Shared winter finish painters: fixed geometry, no unbounded particle emitters. */
Object.assign(FINISH_LIFE,{snowpuff:.8,frostfracture:.85,ornamentpop:.9,winterbloom:1,borealiscollapse:1.1,solsticenova:1.1});
function winterFlake(c,x,y,r,col,rotation=0){
  c.save();c.translate(x,y);c.rotate(rotation);c.strokeStyle=col;c.lineWidth=Math.max(.5,r*.075);c.beginPath();
  for(let i=0;i<6;i++){const a=i*Math.PI/3,dx=Math.cos(a),dy=Math.sin(a);c.moveTo(0,0);c.lineTo(dx*r,dy*r);for(const side of[-1,1]){const b=a+side*.7;c.moveTo(dx*r*.65,dy*r*.65);c.lineTo(dx*r*.65-Math.cos(b)*r*.28,dy*r*.65-Math.sin(b)*r*.28)}}c.stroke();c.restore();
}
function paintWinterFinish(c,key,p,s,x,y){
  const n=WINTER_FX.findIndex(v=>v[0]===key);if(n<0)return false;if(p<0||p>=1)return true;
  const e=1-(1-p)**3,fade=Math.min(1,p*12,(1-p)*3),ice='#d9f8ff',gold='#ffdc89';c.save();c.translate(x,y);c.scale(s,s);c.globalAlpha*=fade;
  if(n===0){for(let i=0;i<7;i++){const a=i*2.4;c.fillStyle=i%2?'#d9ecf2':'#98bdcc';c.beginPath();c.arc(Math.cos(a)*e*12,Math.sin(a)*e*7-e*8,4+e*5,0,Math.PI*2);c.fill()}}
  if(n===1||n===2){for(let i=0;i<10;i++){const a=i*Math.PI/5,r=5+e*22,xx=Math.cos(a)*r,yy=Math.sin(a)*r+p*p*10;c.save();c.translate(xx,yy);c.rotate(a+p*2);c.fillStyle=n===1?(i%2?'#91d7eb':ice):['#cf5364','#d4b66b','#7ca797'][i%3];c.strokeStyle='#244957';c.lineWidth=.6;c.beginPath();if(n===1){c.moveTo(0,-5);c.lineTo(2,0);c.lineTo(0,5);c.lineTo(-2,0)}else{c.arc(0,0,3,0,Math.PI*2)}c.closePath();c.fill();c.stroke();c.fillStyle='#effaff';c.fillRect(-1,-3,1,2);c.restore()}}
  if(n>=3){const r=n===4?31*(1-e)+e*12:6+e*29;cosmeticGlow(c,0,0,35,n===5?gold:'#92e8dc',.25);winterFlake(c,0,0,r,n===5?gold:ice,p*.4);c.strokeStyle=n===5?gold:'#89dfdb';c.lineWidth=1.2;c.beginPath();c.ellipse(0,0,5+e*29,(5+e*29)*.55,0,0,Math.PI*2);c.stroke();if(n===4){for(let j=0;j<3;j++){c.strokeStyle=['#93efd5','#ae96ee','#8ecde9'][j];c.beginPath();c.ellipse(0,0,11+e*17,5+e*7,p*3+j,0,Math.PI*1.65);c.stroke()}}for(let i=0;i<8;i++){const a=i*Math.PI/4+.2,rr=10+e*29;winterFlake(c,Math.cos(a)*rr,Math.sin(a)*rr,2+(1-p)*3,n===5?(i%2?ice:gold):ice,a)}}
  c.restore();return true;
}
