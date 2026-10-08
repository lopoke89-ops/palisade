import {performance} from 'node:perf_hooks';

// Fixed-size samples and aggregate counters only: no account, request or credential data.
export function serviceMetrics({clock=()=>performance.now(),cpu=()=>process.cpuUsage()}={}){
 const times=new Float64Array(3000);let count=0,index=0,at=clock(),usage=cpu();
 const stats={cpuCorePercent:0,cpuCoreMaxPercent:0,cpuSeconds:0,tickP95Ms:0,tickSamples:0};
 return {stats,
  tick(ms){times[index]=ms;index=(index+1)%times.length;count=Math.min(count+1,times.length);stats.tickSamples++;},
  sample(){const now=clock(),next=cpu(),used=(next.user-usage.user+next.system-usage.system)/1e6,elapsed=(now-at)/1000;
   if(elapsed>0){stats.cpuCorePercent=100*used/elapsed;stats.cpuCoreMaxPercent=Math.max(stats.cpuCoreMaxPercent,stats.cpuCorePercent);stats.cpuSeconds+=used;}
   usage=next;at=now;if(count){const sorted=Array.from(times.subarray(0,count)).sort((a,b)=>a-b);stats.tickP95Ms=sorted[Math.ceil(count*.95)-1];}
  }
 };
}
