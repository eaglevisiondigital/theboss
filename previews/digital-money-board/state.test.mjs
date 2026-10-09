import test from 'node:test';
import assert from 'node:assert/strict';
import {createDemo,HOLD_MS,reserve,release,expireHolds,claim,spinCandidate} from './public/state.mjs';
test('a reservation changes neither totals nor activity and can be released',()=>{
  const demo=createDemo(1000); const before=demo.raised;
  assert.equal(reserve(demo,'0',1000),true); assert.equal(demo.raised,before);
  assert.equal(demo.tiles[0].endsAt,1000+HOLD_MS); release(demo);
  assert.equal(demo.tiles[0].state,'available'); assert.equal(demo.selected,null);
});
test('claimed, reserved and missing tiles cannot be claimed through selection',()=>{
  const demo=createDemo(1000);
  for(const id of ['2','8','missing']) assert.equal(reserve(demo,id,1000),false);
  assert.equal(claim(demo,'Anonymous',1000),false); assert.equal(demo.raised,6840);
});
test('only one pending demo selection is allowed',()=>{
  const demo=createDemo(1000); reserve(demo,'0',1000);
  assert.equal(reserve(demo,'1',1000),false); assert.equal(demo.tiles[1].state,'available');
});
test('a simulated claim increments once and prevents replay',()=>{
  const demo=createDemo(1000); reserve(demo,'0',1000);
  assert.equal(claim(demo,'Anonymous',1001),true);
  assert.equal(demo.raised,6865); assert.equal(demo.tiles[0].donor,'Anonymous');
  assert.equal(claim(demo,'Anonymous',1002),false); assert.equal(demo.raised,6865);
  assert.equal(reserve(demo,'0',1002),false);
});
test('the expiry boundary prevents late claims and frees selected and seeded holds',()=>{
  const demo=createDemo(1000); reserve(demo,'0',1000);
  assert.equal(claim(demo,'Demo Supporter',1000+HOLD_MS),false);
  assert.equal(demo.tiles[0].state,'available'); assert.equal(demo.tiles[8].state,'available');
  assert.equal(demo.selected,null); assert.equal(demo.raised,6840);
});
test('expiry does not release a hold before its deadline',()=>{
  const demo=createDemo(1000); reserve(demo,'0',1000);
  assert.equal(expireHolds(demo,1000+HOLD_MS-1),false);
  assert.equal(demo.tiles[0].state,'reserved');
});
test('spin selects only available tiles, including its random boundary values',()=>{
  const demo=createDemo(1000);
  for(const random of [0,.1,.5,.99,1]) {
    const id=spinCandidate(demo,random); assert.equal(demo.tiles.find(t=>t.id===id).state,'available');
  }
  demo.tiles.forEach(t=>t.state='claimed'); assert.equal(spinCandidate(demo,.5),null);
});
test('attribution accepts only fictional choices and reset creates independent state',()=>{
  const demo=createDemo(1000); reserve(demo,'0',1000);
  assert.equal(claim(demo,'Arbitrary person',1001),false);
  assert.equal(claim(demo,'Demo Supporter',1001),true);
  const reset=createDemo(2000); assert.equal(reset.raised,6840); assert.equal(reset.tiles[0].state,'available');
});
