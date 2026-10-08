import {recoverTable} from '../supabase/functions/tables/handler.js';
import {commit} from '../supabase/functions/tables/storage.js';
export class RecoveryWorker {
 constructor(D,owner,{log=console.log}={}){this.D=D;this.owner=owner;this.log=log;this.epoch=0;this.busy=false;this.lastBooks=0;this.lastRepair=0;this.stopped=false;this.stats={steps:0,errors:0,lagMs:0,repaired:0};}
 async cycle(){
  if(this.busy||this.stopped)return;this.busy=true;
  try{
   const cfg=await this.D.world({action:'config'});if(cfg.revision!==1)throw new Error('Unsupported storage revision');if(!cfg.recovery)return;
   const l=await this.D.world({action:'lease',name:'worker',owner:this.owner});if(l.standby){this.epoch=0;return}const changed=this.epoch!==l.epoch;this.epoch=l.epoch;
   if(changed||Number(l.now)-this.lastRepair>60000){this.stats.repaired+=await this.D.rpc('casino_recovery_repair',{p_owner:this.owner,p_epoch:l.epoch});this.lastRepair=Number(l.now);}
   const D={...this.D,now:()=>Number(l.now),commit:a=>commit(this.D.rpc,a,{worker:true,owner:this.owner,epoch:l.epoch})};
   const due=await this.D.rows('casino_tables',{select:'id,next_due_at',open:'eq.true',next_due_at:'lte.'+new Date(Number(l.now)).toISOString(),order:'next_due_at.asc,id.asc',limit:10});
   for(const t of due){if(this.stopped)break;this.stats.lagMs=Math.max(0,Number(l.now)-Date.parse(t.next_due_at));
    try{const r=await recoverTable(D,t.id);if(r.status!==200)throw new Error(r.body.error);this.stats.steps++;
     await this.D.rpc('casino_recovery_idle',{p_table:t.id,p_owner:this.owner,p_epoch:l.epoch});
    }catch(e){this.stats.errors++;this.log(JSON.stringify({event:'recovery_error',table:t.id,error:e.message}));await this.D.rpc('casino_recovery_backoff',{p_table:t.id,p_owner:this.owner,p_epoch:l.epoch,p_error:String(e.message).slice(0,240)});}
   }
   if(Number(l.now)-this.lastBooks>60000){await this.D.books();this.lastBooks=Number(l.now);}
  }catch(e){this.stats.errors++;this.log(JSON.stringify({event:'worker_unavailable',error:e.message}));}finally{this.busy=false;}
 }
 async stop(){this.stopped=true;if(this.epoch)await this.D.world({action:'release',name:'worker',owner:this.owner,epoch:this.epoch}).catch(()=>{});}
}
