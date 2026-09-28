/* ================= particles & floating text ================= */
// emitThin < 1 (set by killFx when the screen is already full of particles) drops that share of a kill
// effect's loose particles; the painted finisher always shows, so every kill still reads the same
let emitThin=1;
function emit(x,y,z,kind,mat){
  if(emitThin<1&&rnd()>emitThin&&!kind.startsWith('finish:'))return;
  rec(['e',r2(x),r2(y),Math.round(z/u),kind,mat|0]);
  const p={x,y,z,vx:(rnd()-.5)*2,vy:(rnd()-.5)*2,vz:rnd()*60,life:.5,max:.5,kind,size:2,col:'#fff',grav:220};
  if(kind.startsWith('finish:')&&FINISH_LIFE[kind.slice(7)]){
    p.vx=p.vy=p.vz=p.grav=0;p.life=p.max=FINISH_LIFE[kind.slice(7)];
    let n=0,first=-1;for(let i=0;i<parts.length;i++)if(parts[i].kind.charCodeAt(0)===102&&parts[i].kind.startsWith('finish:')){if(first<0)first=i;n++}if(n>=24)parts.splice(first,1);
  }
  switch(kind){
    case'splinter':p.col=rnd()<.5?'#c99a5e':'#7a5530';p.life=p.max=.45;break;
    case'dust':p.col=mat===1?'rgba(170,110,85,':mat===2?'rgba(150,155,155,':'rgba(150,120,85,';p.vx*=.4;p.vy*=.4;p.vz=10+rnd()*20;p.grav=-8;p.life=p.max=.9+rnd()*.5;p.size=7;break;
    case'spark':p.col=rnd()<.5?'#ffe39a':'#ffb14a';p.vx*=3;p.vy*=3;p.vz=40+rnd()*90;p.life=p.max=.3;p.size=1.6;break;
    case'chunk':p.col=MAT[mat].top;p.vx*=2;p.vy*=2;p.vz=50+rnd()*80;p.life=p.max=.9;p.size=3.2;break;
    case'blood':p.col='#7d231b';p.vz=20+rnd()*40;p.size=2.2;break;
    case'fire':p.col=rnd()<.5?'#ffcf6a':'#e8662d';p.vx*=2.4;p.vy*=2.4;p.vz=30+rnd()*120;p.grav=60;p.life=p.max=.5+rnd()*.3;p.size=3.5;break;
    case'flame':p.col=rnd()<.5?'#ffb347':'#e8552a';p.vx*=.3;p.vy*=.3;p.vz=25+rnd()*25;p.grav=-30;p.life=p.max=.5+rnd()*.3;p.size=3;break;
    case'smoke':p.col='rgba(60,56,50,';p.vx*=.5;p.vy*=.5;p.vz=15+rnd()*15;p.grav=-12;p.life=p.max=1.4+rnd();p.size=9;break;
    case'confetti':p.col=['#ff5a8a','#ffd24a','#5ad8ff','#8aff6a','#c78aff'][Math.floor(rnd()*5)];p.vx*=1.8;p.vy*=1.8;p.vz=70+rnd()*80;p.grav=110;p.life=p.max=1.1;p.size=2.6;break;
    case'ember':p.col=rnd()<.5?'#ff8a3a':'#ffd06a';p.vx*=.8;p.vy*=.8;p.vz=20+rnd()*30;p.grav=-25;p.life=p.max=.9+rnd()*.4;p.size=2;break;
    case'bolt':p.col=rnd()<.5?'#e8f6ff':'#8fd4ff';p.vx=(rnd()-.5)*.3;p.vy=(rnd()-.5)*.3;p.vz=0;p.grav=0;p.life=p.max=.32;p.size=3.2;break;
    case'shell':p.col=rnd()<.5?'#d8b25a':'#b8913e';p.vx=(rnd()-.5)*1.4;p.vy=(rnd()-.5)*1.4;p.vz=80+rnd()*50;p.grav=300;p.life=p.max=.7;p.size=1.8;break;
    case'glint':p.col=rnd()<.5?'#bfe9ff':'#ffffff';p.vx*=3.2;p.vy*=3.2;p.vz=60+rnd()*90;p.life=p.max=.4;p.size=1.8;break;
    case'hull':p.col=rnd()<.5?'#b8322a':'#8e2620';p.vx=(rnd()-.5)*1.4;p.vy=(rnd()-.5)*1.4;p.vz=80+rnd()*50;p.grav=300;p.life=p.max=.8;p.size=2.4;break;
    case'star':p.col=rnd()<.6?'#fffbe8':'#ffe9a0';p.vx*=.4;p.vy*=.4;p.vz=8+rnd()*10;p.grav=0;p.life=p.max=.55+rnd()*.3;p.size=2;break;
    case'cosmic':p.col=['#c07aff','#6a8aff','#ff8ad8','#ffffff'][Math.floor(rnd()*4)];p.vx*=.5;p.vy*=.5;p.vz=4+rnd()*10;p.grav=-6;p.life=p.max=.7;p.size=1.8;break;
    case'rock':p.col=rnd()<.5?'#8a7e70':'#6a5e52';p.vx*=1.2;p.vy*=1.2;p.vz=18+rnd()*20;p.grav=160;p.life=p.max=.6;p.size=2.4;break;
    case'void2':p.col=rnd()<.5?'#b06aff':'#5a1a9a';p.vx*=.3;p.vy*=.3;p.vz=0;p.grav=0;p.life=p.max=.45;p.size=1.8;break;
    case'goldsp':p.col=['#ffe066','#fff6c8','#ffd24a'][Math.floor(rnd()*3)];p.vx*=1.4;p.vy*=1.4;p.vz=25+rnd()*40;p.grav=45;p.life=p.max=.7;p.size=2;break;
    case'pix':p.col=['#ff3a6a','#3affd8','#ffe03a','#6a8aff'][Math.floor(rnd()*4)];p.vx*=2.2;p.vy*=2.2;p.vz=60+rnd()*70;p.grav=190;p.life=p.max=.8;p.size=3.4;break;
    case'ice':p.col=rnd()<.5?'#f2fbff':'#9fd8f0';p.vx*=2.6;p.vy*=2.6;p.vz=40+rnd()*70;p.grav=210;p.life=p.max=.6;p.size=2.2;break;
    case'grad1':p.c1='#e0a0ff';p.c2='#3a6aff';p.vx*=2.4;p.vy*=2.4;p.vz=40+rnd()*70;p.grav=80;p.life=p.max=.95;p.size=3;break;
    case'grad2':p.c1='#ff5ad8';p.c2='#ffb03a';p.vx*=2.4;p.vy*=2.4;p.vz=40+rnd()*70;p.grav=80;p.life=p.max=.95;p.size=3;break;
    case'toxic':p.col=rnd()<.5?'#b6ff3a':'#7adf2a';p.vx*=1.6;p.vy*=1.6;p.vz=50+rnd()*50;p.grav=230;p.life=p.max=.8;p.size=3;break;
    case'nova':p.c1='#ffffff';p.c2='#6a8aff';p.vx*=3.6;p.vy*=3.6;p.vz=15+rnd()*50;p.grav=0;p.life=p.max=.75;p.size=2.4;break;
    case'glitch':p.col=['#ff3a6a','#3affd8','#6a8aff','#ffffff'][Math.floor(rnd()*4)];p.vx*=1.2;p.vy*=1.2;p.vz=10+rnd()*40;p.grav=0;p.life=p.max=.25+rnd()*.25;p.size=3+rnd()*4;break;
    case'void':{const an=rnd()*6.283,r=.5+rnd()*.45;p.x+=Math.cos(an)*r;p.y+=Math.sin(an)*r;p.vx=-Math.cos(an)*r*3.2;p.vy=-Math.sin(an)*r*3.2;p.vz=0;p.grav=0;p.col=rnd()<.5?'#b06aff':'#3a1060';p.life=p.max=.42;p.size=2.4;break}
    case'neon':p.col=rnd()<.5?'#2af5ff':'#ff3ad0';p.vx*=3;p.vy*=3;p.vz=30+rnd()*50;p.grav=60;p.life=p.max=.6;p.size=2.2;break;
    case'bubble':p.vx*=.55;p.vy*=.55;p.vz=15+rnd()*35;p.grav=-38;p.life=p.max=1.2+rnd()*.7;p.size=2.4+rnd()*4.2;p.h=rnd()*360;break;
    case'heal':p.col=rnd()<.5?'#8fe0a0':'#e8fff0';p.vx*=.6;p.vy*=.6;p.vz=30+rnd()*30;p.grav=-40;p.life=p.max=.8;p.size=2.4;break;
    // Halloween Case: green flame (Ghostfire, Soul Harvest), bats, a spider on a thread, rising souls (the last three are drawn as shapes)
    case'gflame':p.col=rnd()<.5?'#b8ff8a':'#2ae86a';p.vx*=.3;p.vy*=.3;p.vz=25+rnd()*25;p.grav=-30;p.life=p.max=.5+rnd()*.3;p.size=3;break;
    case'bat':p.vx*=1.6;p.vy*=1.6;p.vz=45+rnd()*45;p.grav=-15;p.life=p.max=1+rnd()*.5;p.size=5+rnd()*2.2;p.h=rnd()*9;break;
    case'spider':p.vx=0;p.vy=0;p.z=WH*2.6;p.vz=-WH*3.2/u;p.grav=0;p.life=p.max=1.6;p.size=7;p.h=rnd()*9;break;
    case'soul':p.vx*=.35;p.vy*=.35;p.vz=26+rnd()*18;p.grav=-4;p.life=p.max=1.5+rnd()*.5;p.size=6.5+rnd()*2;p.h=rnd()*9;break;
    case'arc':p.col=rnd()<.5?'#e8f6ff':'#7fd8ff';p.vx*=2.6;p.vy*=2.6;p.vz=20+rnd()*60;p.grav=0;p.life=p.max=.25;p.size=2;break;
  }
  parts.push(p);if(parts.length>600)parts.splice(0,parts.length-600);
}
function hitFx(x,y,mat){
  if(mat===0){for(let n=0;n<4;n++)emit(x,y,WH*.5,'splinter')}
  else if(mat===1){emit(x,y,WH*.5,'dust',1);for(let n=0;n<2;n++)emit(x,y,WH*.5,'chunk',1)}
  else{for(let n=0;n<6;n++)emit(x,y,WH*.5,'spark')}
}
function flt(x,y,t,col='#dcd2ba'){rec(['f',r2(x),r2(y),t,col]);floats.push({x,y,t,col,life:1.3,max:1.3});if(floats.length>12)floats.shift()}

