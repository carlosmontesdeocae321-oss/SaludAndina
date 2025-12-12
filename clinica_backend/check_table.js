const pool = require('./config/db');
(async ()=>{
  try{
    const [rows] = await pool.query("SHOW TABLES LIKE 'idempotency_keys'");
    console.log('Result:', rows);
  }catch(e){
    console.error('Error:', e && e.message ? e.message : e);
  }finally{
    await pool.end();
  }
})();