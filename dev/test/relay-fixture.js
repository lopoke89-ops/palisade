// Identity fixtures only. Browser game tests still call the real table request handler.
exports.start=async(users,tok)=>{
 const {createRelay}=await import('../render/relay.js');
 const relay=createRelay({origins:['http://localhost:8080'],identity:{
  verify:async token=>{const u=Object.values(users).find(u=>tok(u)===token);if(!u||u.anon)throw new Error('Saved account required');return {uid:u.id,name:u.name,expires:4e12}},
  restore:async()=>true
 }});await relay.start(10000);return relay;
};
