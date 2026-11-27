const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { Pool } = require('pg');

test('HTTP API with isolated PostgreSQL database', { skip: !process.env.TEST_DATABASE_URL }, async t => {
  const admin = new Pool({ connectionString: process.env.TEST_DATABASE_URL });
  const database = 'trackos_test_' + Date.now();
  const url = new URL(process.env.TEST_DATABASE_URL);
  url.pathname = '/' + database;
  let pool, server;
  await admin.query('CREATE DATABASE ' + database);
  try {
    process.env.DATABASE_URL = url.toString();
    process.env.DEMO_SIMULATION = 'true';
    pool = require('../src/config/database');
    await pool.query(await fs.readFile(path.join(__dirname,'../init.sql'),'utf8'));
    await pool.query('UPDATE users SET password=$1 WHERE email=$2', ['$2a$10$YvlQVWvCzC0gON.OmC3oJOBvfM5kxFiJgm.rPMEMR8hFGHKMJWNou','demo@test.com']);
    const migrate = require('../src/database/migrate');
    await migrate();
    await migrate(); // Existing installations can start repeatedly without data loss.
    const app = require('../src/app');
    server = app.listen(0,'127.0.0.1');
    await new Promise(resolve => server.once('listening',resolve));
    let base = 'http://127.0.0.1:' + server.address().port;
    const request = async (method, endpoint, token, body) => {
      const res = await fetch(base + endpoint, { method, headers: { 'Content-Type':'application/json', ...(token ? {Authorization:'Bearer '+token} : {}) }, ...(body === undefined ? {} : {body:JSON.stringify(body)}) });
      return { status:res.status, body:await res.json() };
    };
    const signup = email => request('POST','/api/auth/register',null,{name:'Demo',email,password:'123456',phone:'999000001',address:'Trujillo'});
    const user = (await signup('owner@test.local')).body;
    const other = (await signup('other@test.local')).body;
    const products = (await request('GET','/api/products')).body;
    const product = products.find(p => p.stock >= 2);
    const create = async () => {
      assert.equal((await request('POST','/api/cart/add',user.token,{productId:product.id})).status,200);
      const result = await request('POST','/api/orders',user.token);
      assert.equal(result.status,201);
      assert.equal(result.body.status,'pending');
      return result.body;
    };
    const first = await create();
    const second = await create();
    const endpoint = '/api/orders/' + first.id;
    const get = () => request('GET',endpoint+'/tracking',user.token);
    const mutate = (action,version,token=user.token) => request('POST',endpoint+'/simulation/'+action,token,{expectedVersion:version});
    await t.test('authentication, ownership and request validation', async () => {
      assert.equal((await request('POST','/api/auth/login',null,{email:'demo@test.com',password:'123456'})).status,200);
      assert.equal((await request('GET',endpoint+'/tracking')).status,401);
      assert.equal((await request('GET',endpoint+'/tracking','invalid')).status,401);
      assert.equal((await request('GET',endpoint+'/tracking',other.token)).status,404);
      assert.equal((await mutate('advance',0,other.token)).status,404);
      assert.equal((await mutate('reset',0,other.token)).status,404);
      assert.equal((await mutate('advance','0')).status,400);
      assert.equal((await request('POST','/api/cart/add',user.token,{productId:product.id,quantity:-1})).status,400);
      const initial = (await get()).body;
      assert.equal(initial.simulation.currentNodeIndex,0);
      assert.equal(initial.events.length,1);
    });
    await t.test('concurrent duplicate advances only commit one node', async () => {
      const result = await Promise.all([mutate('advance',0),mutate('advance',0)]);
      assert.deepEqual(result.map(r=>r.status).sort(),[200,409]);
      const state = (await get()).body;
      assert.equal(state.simulation.currentNodeIndex,1);
      assert.equal(state.events.length,2);
      const otherOrder = (await request('GET','/api/orders/'+second.id+'/tracking',user.token)).body;
      assert.equal(otherOrder.simulation.currentNodeIndex,0);
    });
    await t.test('repeated in-transit events, delivery and terminal boundary', async () => {
      assert.equal((await mutate('advance',1)).status,200);
      let state = (await get()).body;
      assert.equal(state.status,'in_transit');
      assert.equal(state.events.filter(e=>e.status==='in_transit').length,2);
      assert.equal((await mutate('advance',2)).body.status,'out_for_delivery');
      assert.equal((await mutate('advance',3)).body.status,'delivered');
      state = (await get()).body;
      assert.ok(state.shipment.delivered_at);
      assert.equal((await mutate('advance',4)).status,409);
      assert.equal((await get()).body.events.length,5);
    });
    await t.test('API restart restores persisted delivery', async () => {
      await new Promise(resolve=>server.close(resolve));
      server = app.listen(0,'127.0.0.1');
      await new Promise(resolve=>server.once('listening',resolve));
      base = 'http://127.0.0.1:' + server.address().port;
      assert.equal((await get()).body.simulation.currentNodeIndex,4);
    });
    await t.test('reset preserves purchase, inventory and past run', async () => {
      const before = (await pool.query('SELECT stock FROM products WHERE id=$1',[product.id])).rows[0].stock;
      const oldRun = (await get()).body.simulation.runId;
      const reset = await mutate('reset',4);
      assert.equal(reset.status,200);
      assert.equal(reset.body.status,'pending');
      assert.equal(reset.body.shipment.delivered_at,null);
      assert.equal(reset.body.events.length,1);
      assert.notEqual(reset.body.simulation.runId,oldRun);
      assert.equal(reset.body.simulation.version,5);
      assert.equal((await pool.query('SELECT COUNT(*)::int AS count FROM tracking_events WHERE order_id=$1',[first.id])).rows[0].count,6);
      assert.equal((await pool.query('SELECT stock FROM products WHERE id=$1',[product.id])).rows[0].stock,before);
      const orders = (await request('GET','/api/orders',user.token)).body;
      assert.equal(orders.length,2);
      assert.equal(orders.find(o=>o.id===first.id).total,first.total);
      assert.equal((await mutate('advance',4)).status,409);
    });
    await t.test('old orders keep their tracking without being reset implicitly', async () => {
      const legacy='ORD-LEGACY';
      await pool.query("INSERT INTO orders (id,user_id,total,status) VALUES ($1,$2,10,'in_transit')",[legacy,user.user.id]);
      const result = await request('GET','/api/orders/'+legacy+'/tracking',user.token);
      assert.equal(result.body.simulation,null);
      assert.equal(result.body.status,'in_transit');
      assert.equal((await request('POST','/api/orders/'+legacy+'/simulation/reset',user.token,{expectedVersion:0})).status,409);
    });
    await t.test('server flag blocks controls without altering persisted tracking', async () => {
      require('../src/config/env').simulationEnabled = false;
      // Controller reads configuration at module initialization, so use a new controller instance.
      delete require.cache[require.resolve('../src/controllers/tracking.controller')];
      const controller = require('../src/controllers/tracking.controller');
      let error;
      await controller.advance({params:{id:first.id},user:{user_id:user.user.id},body:{expectedVersion:5}}, {}, err=>{error=err;});
      assert.equal(error.status,403);
      require('../src/config/env').simulationEnabled = true;
    });
  } finally {
    if (server) await new Promise(resolve=>server.close(resolve));
    if (pool) await pool.end();
    await admin.query('DROP DATABASE ' + database + ' WITH (FORCE)');
    await admin.end();
  }
});
