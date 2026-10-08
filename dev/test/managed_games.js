const {spawnSync}=require('node:child_process'),path=require('node:path');
const r=spawnSync(process.execPath,['--test',path.join(__dirname,'../render/test/games.test.js')],{encoding:'utf8',windowsHide:true});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.status)process.exit(r.status);console.log('errors: none');
