const {spawnSync}=require('node:child_process'),path=require('node:path');
const r=spawnSync(process.execPath,['--test',path.join(__dirname,'../render/test/world.test.js'),path.join(__dirname,'../render/test/metrics.test.js')],{cwd:path.join(__dirname,'../..'),stdio:'inherit',windowsHide:true});if(r.status===0)console.log('errors: none');process.exit(r.status??1);
