// Every Armory category fits the viewport, including Sniper slots and 44px touch targets.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({viewport:{width:390,height:844},hasTouch:true,isMobile:true}),errors=[],layouts=[];
  p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/debug.html?debug=1');await p.evaluate(()=>document.fonts.ready);
  const reset=async(cls,pvp='')=>{await p.evaluate(({cls,pvp})=>{const P=__pal;P.demo=false;P.pick.mode='10';P.newGame([{id:'solo',name:'Tester',cls,cos:'',sk:''},...(pvp?[{id:'b',name:'Rival',cls:'soldier',cos:'',sk:''}]:[])],pvp);P.player.sal=1000;P.enterGameHook();document.getElementById('armory').hidden=true}, {cls,pvp});
    // FFA has no playable Armory; render its disabled state only to verify ammo stays hidden.
    if(pvp==='ffa')await p.evaluate(()=>{document.getElementById('armory').hidden=false;__pal.renderArmory()});else await p.keyboard.press('e');await p.click('#armUpTab')};
  const check=async(label)=>{const r=await p.evaluate(()=>{const ov=document.getElementById('armory'),card=ov.querySelector('.card'),cr=card.getBoundingClientRect();
    const buttons=[...ov.querySelectorAll('button')].filter(b=>!b.hidden&&!b.closest('[hidden]'));
    return{w:innerWidth,h:innerHeight,top:cr.top,bottom:cr.bottom,left:cr.left,right:cr.right,scrollHeight:ov.scrollHeight,clientHeight:ov.clientHeight,scrollWidth:ov.scrollWidth,clientWidth:ov.clientWidth,rows:ov.querySelectorAll('.arow').length,
      badButtons:buttons.filter(b=>{const r=b.getBoundingClientRect();return r.height<43.9||r.width<43.9||r.top<0||r.bottom>innerHeight+1||b.scrollWidth>b.clientWidth+1}).map(b=>b.textContent),
      clippedDescriptions:[...ov.querySelectorAll('.arow i')].filter(i=>i.scrollWidth>i.clientWidth+1).map(i=>i.textContent)}});
    assert.ok(r.top>=0&&r.bottom<=r.h+1&&r.left>=0&&r.right<=r.w+1&&r.scrollHeight<=r.clientHeight+1&&r.scrollWidth<=r.clientWidth+1, label+' '+JSON.stringify(r));assert.deepEqual(r.badButtons,[],label+' touch targets');assert.deepEqual(r.clippedDescriptions,[],label+' descriptions');layouts.push({label,...r})};
  for(const [w,h] of [[320,480],[320,568],[360,640],[390,844],[430,932],[568,320],[667,375],[740,360],[844,390],[1280,800]]){
    await p.setViewportSize({width:w,height:h});await p.waitForFunction(()=>document.getElementById('armory').getBoundingClientRect().height<=innerHeight+1);
    for(const cls of ['soldier','sniper']){await reset(cls);await check(cls+' upgrades '+w+'x'+h);await p.click('#armAmmoTab');await check(cls+' ammo '+w+'x'+h);
      if(cls==='sniper'){await p.click('[data-arm-slot="1"]');await check('sniper slot 2 '+w+'x'+h)}
      if(cls==='sniper'&&[[390,844],[844,390],[1280,800]].some(v=>v[0]===w&&v[1]===h)){await p.click('#armUpTab');await p.screenshot({path:__dirname+`/out/armory_${w}x${h}_upgrades.png`});await p.click('#armAmmoTab');await p.screenshot({path:__dirname+`/out/armory_${w}x${h}_ammo.png`})}
      if(cls==='sniper'){await p.evaluate(()=>{const P=__pal,p=P.player;p.sk=P.skillStr({ammo_ap:4,ammo_fire:4,ammo_blast:4,ammo_shock:4});for(const k in p.up)p.up[k]=8;p.upS='88888';P.game.dellLv=8;p.ammoEq=['ap','shock'];P.kitUp(p);P.renderArmory()});await check('maxed sniper ammo '+w+'x'+h);await p.click('#armUpTab');await check('maxed upgrades '+w+'x'+h)}
    }
  }
  await p.setViewportSize({width:390,height:844});await reset('sniper');await p.click('#armAmmoTab');await p.click('[data-arm-slot="0"]');await p.click('[data-arm-ammo="fire"]');await p.click('[data-arm-slot="1"]');await p.click('[data-arm-ammo="blast"]');
  assert.equal(await p.locator('[data-arm-ammo="fire"]').textContent(),'OTHER SLOT');assert.equal(await p.locator('[data-arm-ammo="fire"]').isDisabled(),true);
  await p.click('[data-arm-slot="0"]');await p.click('[data-arm-ammo="shock"]');const buy=await p.evaluate(()=>({sal:__pal.player.sal,ammo:__pal.player.ammoEq.slice()}));assert.deepEqual(buy,{sal:625,ammo:['shock','blast']});
  await p.click('#armUpTab');await p.locator('#armRows .arow button').first().click();assert.equal(await p.evaluate(()=>__pal.player.up.d),1);await p.click('#armAmmoTab');assert.equal(await p.locator('[data-arm-ammo="shock"]').textContent(),'EQUIPPED');await check('after purchases');
  for(const pvp of ['base','ffa']){await reset('soldier',pvp);assert.equal(await p.locator('#armAmmoTab').isVisible(),false);await check(pvp+' upgrades')}
  assert.deepEqual(errors,[]);fs.writeFileSync(__dirname+'/out/armory_layout.json',JSON.stringify({layouts,buy},null,2));console.log(JSON.stringify({checks:layouts.length,buy}));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
