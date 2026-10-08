// Managed casino contracts shared by the Edge API and the Render worker.
import * as E from './engine.js';
export const REVISION=1;
export const isManaged=room=>typeof room==='string'&&room.startsWith('C:');
const FIELDS=['op','id','room','game','station','seat','amt','side','yes','a','on','kind','k','flags','seed','bets','lim','expected'];
const canon=x=>Array.isArray(x)?'['+x.map(canon).join(',')+']':x&&typeof x==='object'?'{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canon(x[k])).join(',')+'}':JSON.stringify(x===undefined?null:x);
export const managedHash=b=>E.sha256hex(canon(Object.fromEntries(FIELDS.filter(k=>b[k]!==undefined).map(k=>[k,b[k]]))));
export const decision=st=>({session:st.tid,rules:st.rulesRevision||`${E.FV}:${E.RV[st.game]}`,round:st.handNo,phase:st.phase,step:st.hand?.step||0});
export const expectedOk=(st,e)=>!!e&&canon(decision(st))===canon(e);
export function autoStart(st){if(isManaged(st.room)&&st.started===false&&E.humansAt(st).length>=(st.game==='he'?2:1))st.started=true}
export function exactSit(st,a,ctx){if(!Number.isInteger(a.seat)||a.seat<0||a.seat>=st.seats.length||st.seats[a.seat])return 'That seat is occupied';return E.sit(st,a,ctx)}
// Persist every relevant wakeup. Seen expires strictly AFTER 60s in the existing engine.
export function nextDue(st,now){
  const times=[];
  for(const s of st.seats)if(s&&!s.bot&&!s.gone&&!s.leaving)times.push(s.seen+E.AWAY_MS+1);
  if(st.deadline>0)times.push(st.phase==='done'?Math.max(st.deadline,st.minAt||0):st.deadline);
  if(st.phase==='done'&&st.minAt>now)times.push(st.minAt);
  const h=st.hand;if(st.game==='he'&&st.phase==='play'&&h?.players[h.cur]?.bot)times.push(h.botAt||now);
  if(st.game==='cr'&&st.seats.some(s=>s?.gone)&&!st.seats.some(s=>s&&!s.bot&&!s.gone))times.push(now+100);
  return times.length?Math.max(now,Math.min(...times)):null;
}
