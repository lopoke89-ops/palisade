import test from 'node:test';
import assert from 'node:assert/strict';
import {serviceMetrics} from '../metrics.js';
test('capacity measurements use process CPU time and a bounded recent tick window',()=>{
 let at=0,user=0;const m=serviceMetrics({clock:()=>at,cpu:()=>({user,system:0})});
 at=1000;user=50000;m.sample();assert.equal(m.stats.cpuCorePercent,5);assert.equal(m.stats.cpuSeconds,.05);
 // Old startup work must not contaminate steady-state percentiles indefinitely.
 for(let i=0;i<3000;i++)m.tick(100);for(let i=0;i<3000;i++)m.tick(1);
 at=2000;user=70000;m.sample();assert.equal(m.stats.tickP95Ms,1);assert.equal(m.stats.tickSamples,6000);assert.equal(m.stats.cpuCoreMaxPercent,5);
 assert.deepEqual(Object.keys(m.stats).sort(),['cpuCoreMaxPercent','cpuCorePercent','cpuSeconds','tickP95Ms','tickSamples'].sort());
});
