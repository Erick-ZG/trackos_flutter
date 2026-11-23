const test = require('node:test');
const assert = require('node:assert/strict');
const { route, nextIndex, checkVersion } = require('../src/services/simulation.service');
test('route has valid distinct coordinates and expected lifecycle', () => {
  assert.equal(route.nodes.length, 5);
  assert.deepEqual(route.nodes.map(n => n.status), ['pending','in_transit','in_transit','out_for_delivery','delivered']);
  for (const node of route.nodes) {
    assert.ok(node.latitude > -8.2 && node.latitude < -8);
    assert.ok(node.longitude > -79.1 && node.longitude < -78.9);
  }
});
test('advance is bounded and finishes at the destination', () => {
  let index = 0;
  for (let i = 1; i < route.nodes.length; i++) { index = nextIndex(index); assert.equal(index, i); }
  assert.throws(() => nextIndex(index), { status: 409 });
  assert.throws(() => nextIndex(-1), { status: 409 });
});
test('optimistic version prevents duplicate and malformed mutations', () => {
  checkVersion(2,2);
  assert.throws(() => checkVersion(2,1), { status: 409 });
  for (const version of [undefined,null,'2',-1,1.5]) assert.throws(() => checkVersion(2,version), { status: 400 });
});
