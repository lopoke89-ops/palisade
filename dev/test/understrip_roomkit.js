// THE UNDERSTRIP room kits (dev/data/understrip/rooms-r*.json): every piece is a grid of whole 8 x 8 cells whose edges are
// wall except doorways in pairs at the shared slots (so any two pieces join), uses only the legend, has all its open ground
// connected, keeps corridors to two tiles wide, carries the markers its role needs, and a shortcut door really splits its
// piece until it opens. The kit as a whole has every role the generator places. No browser.
// node understrip_roomkit.js            check every kit
// node understrip_roomkit.js --print    and draw each piece
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const DIR=process.env.UNDERSTRIP_KIT_DIR||path.join(__dirname,'../data/understrip'),PRINT=process.argv.includes('--print');
const SOLID=new Set(['#','%','o']),DOORS=new Set(['D','G']),SIDES=['N','E','S','W'];
// what each role must carry: [marker, min, max]
const NEEDS={entrance:[['P',6,6]],exit:[['E',1,1]],breather:[['S',1,1],['A',0,0]],merchant:[['M',1,1]],cache:[['C',1,9]],
  boss_ante:[['S',1,1],['G',2,2]],boss_arena:[['B',1,1],['E',1,1],['S',1,1]],shortcut:[['K',1,4]]};
const ROLES_NEEDED=['corridor','junction','room','cache','breather','merchant','entrance','exit','shortcut','boss_ante','boss_arena'];
let pieces=0,kits=0;
const files=fs.readdirSync(DIR).filter(f=>/^rooms-r\d+\.json$/.test(f)).sort();
assert.ok(files.length>0,'no room kits found in '+DIR);
for(const f of files){
  const kit=JSON.parse(fs.readFileSync(path.join(DIR,f),'utf8'));kits++;
  assert.equal(kit.schema,'understrip-room-kit/1',f+': schema');
  const C=kit.cell,[s0,s1]=kit.doorSlots,legend=new Set(Object.keys(kit.legend));
  assert.ok(C===8&&s0===3&&s1===4,f+': cells are 8 x 8 with door slots at 3 and 4');
  const ids=new Set(),roles=new Set();
  for(const p of kit.pieces){
    const at=`${f} ${p.id}`;pieces++;
    assert.ok(!ids.has(p.id),at+': duplicate id');ids.add(p.id);roles.add(p.role);
    const [cw,ch]=p.size,W=cw*C,H=ch*C,g=p.grid;
    assert.equal(g.length,H,at+`: ${g.length} rows, want ${H}`);
    g.forEach((r,j)=>assert.equal(r.length,W,at+`: row ${j} is ${r.length} wide, want ${W}`));
    const t=(i,j)=>i<0||j<0||i>=W||j>=H?'#':g[j][i];
    for(let j=0;j<H;j++)for(let i=0;i<W;i++)assert.ok(legend.has(t(i,j)),at+`: '${t(i,j)}' at ${i},${j} isn't in the legend`);
    // edges: wall, or a doorway pair at a slot; doorways nowhere else
    const doors=[];   // {side, cell}
    const edge=(side,n,tile)=>{for(let c=0;c<n;c++)for(let k=0;k<C;k++){const v=tile(c*C+k),slot=k===s0||k===s1;
      if(DOORS.has(v)){assert.ok(slot,at+`: doorway off the slots on the ${side} edge, cell ${c} tile ${k}`);
        if(k===s0){assert.equal(tile(c*C+s1),v,at+`: half a doorway on the ${side} edge, cell ${c}`);doors.push({side,cell:c,kind:v})}}
      else assert.equal(v,'#',at+`: the ${side} edge has '${v}' at cell ${c} tile ${k} (edges are wall or doorway)`)}};
    edge('N',cw,x=>t(x,0));edge('S',cw,x=>t(x,H-1));edge('W',ch,y=>t(0,y));edge('E',ch,y=>t(W-1,y));
    for(let j=1;j<H-1;j++)for(let i=1;i<W-1;i++)assert.ok(!DOORS.has(t(i,j)),at+`: doorway tile inside the piece at ${i},${j}`);
    assert.ok(doors.length>0,at+': no doorway');
    // every doorway opens onto open ground
    const inward={N:[0,1],S:[0,-1],W:[1,0],E:[-1,0]};
    const doorTiles=d=>{const o=d.cell*C;return d.side==='N'?[[o+s0,0],[o+s1,0]]:d.side==='S'?[[o+s0,H-1],[o+s1,H-1]]:d.side==='W'?[[0,o+s0],[0,o+s1]]:[[W-1,o+s0],[W-1,o+s1]]};
    // counts
    const n={};for(const r of g)for(const v of r)n[v]=(n[v]|0)+1;
    for(const[m,lo,hi]of NEEDS[p.role]||[]){const k=n[m]|0;assert.ok(k>=lo&&k<=hi,at+`: ${p.role} needs ${lo}-${hi} '${m}', has ${k}`)}
    if(p.role!=='boss_ante')assert.ok(!(n.G>0),at+': only the antechamber has a boss gate');
    if(p.role!=='shortcut')assert.ok(!(n.K>0),at+': only shortcut pieces have shortcut doors');
    if(p.role==='breather'||p.role==='entrance'||p.role==='exit')assert.ok(!(n.A>0),at+': no ambushes in a safe room');
    // open ground, connected (shortcut doors open)
    const open=(i,j,kOpen)=>{const v=t(i,j);return v==='K'?kOpen:!SOLID.has(v)};
    const fill=(i0,j0,kOpen)=>{const seen=new Set([i0+','+j0]),q=[[i0,j0]];
      while(q.length){const[i,j]=q.pop();for(const[a,b]of[[1,0],[-1,0],[0,1],[0,-1]]){const x=i+a,y=j+b,k=x+','+y;
        if(!seen.has(k)&&x>=0&&y>=0&&x<W&&y<H&&open(x,y,kOpen)){seen.add(k);q.push([x,y])}}}return seen};
    const d0=doorTiles(doors[0])[0],all=fill(d0[0],d0[1],true);
    let openN=0;for(let j=0;j<H;j++)for(let i=0;i<W;i++)if(open(i,j,true)){openN++;assert.ok(all.has(i+','+j),at+`: open tile ${i},${j} can't be reached`)}
    for(const d of doors)for(const[i,j]of doorTiles(d)){const[a,b]=inward[d.side];assert.ok(open(i+a,j+b,true),at+`: the ${d.side} doorway opens onto a wall`)}
    // corridors and junctions: never a 3 x 3 open square, so never more than two wide
    if(p.role==='corridor'||p.role==='junction')for(let j=0;j+2<H;j++)for(let i=0;i+2<W;i++){
      let all9=true;for(let b=0;b<3;b++)for(let a=0;a<3;a++)if(!open(i+a,j+b,true))all9=false;
      assert.ok(!all9,at+`: wider than two tiles at ${i},${j}`)}
    // a shortcut splits its piece until it opens, and its opening side has a doorway
    if(p.role==='shortcut'){
      assert.ok(SIDES.includes(p.opensFrom),at+': opensFrom must be N, E, S or W');
      const from=doors.filter(d=>d.side===p.opensFrom),other=doors.filter(d=>d.side!==p.opensFrom);
      assert.ok(from.length&&other.length,at+': a shortcut needs doorways on its opening side and another side');
      const f0=doorTiles(from[0])[0],shut=fill(f0[0],f0[1],false);
      for(const d of other)for(const[i,j]of doorTiles(d))assert.ok(!shut.has(i+','+j),at+`: the ${d.side} doorway is reachable with the shortcut shut`)}
    for(const k of['rotate','weight','max','light'])assert.ok(k in p,at+': missing '+k);
    assert.ok(p.light>=0&&p.light<=1,at+': light is 0-1');
    if(PRINT)console.log(`\n${p.id}  ${p.role}  ${cw}x${ch} cells  doors ${doors.map(d=>d.side+(cw>1||ch>1?d.cell:'')).join(' ')}  open ${openN}\n  `+g.join('\n  '));
  }
  for(const r of ROLES_NEEDED)assert.ok(roles.has(r),`${f}: the kit has no ${r} piece`);
}
console.log(`PASS understrip_roomkit: ${kits} kit(s), ${pieces} pieces; errors: none`);
