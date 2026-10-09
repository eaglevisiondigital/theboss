// Fictional values and in-memory behavior only. No persistence or backend.
export const GOAL = 10000;
export const HOLD_MS = 90000;
const amounts = [25,35,50,60,75,85,100,125,150,175,200,225,250,275,300,325,350,375,400,425,450,475,500,550];
export function createDemo(now = Date.now()) {
  return { raised: 6840, selected: null, mode: 'donate',
    tiles: amounts.map((amount, index) => ({id: String(index), amount, state: [2,6,11,17,22].includes(index) ? 'claimed' : index === 8 ? 'reserved' : 'available', donor: [2,11,22].includes(index) ? 'Anonymous' : 'Demo Supporter', endsAt: index === 8 ? now + HOLD_MS : null})),
    activity: [{donor:'Anonymous',amount:500},{donor:'Demo Supporter',amount:375},{donor:'Anonymous',amount:225}] };
}
export function expireHolds(demo, now) {
  let changed = false;
  for (const tile of demo.tiles) if(tile.state === 'reserved' && tile.endsAt <= now) {
    tile.state = 'available'; tile.endsAt = null; changed = true;
    if (demo.selected === tile.id) demo.selected = null;
  }
  return changed;
}
export function reserve(demo, id, now) {
  expireHolds(demo, now);
  const tile = demo.tiles.find(tile => tile.id === id);
  if (!tile || tile.state !== 'available' || demo.selected !== null) return false;
  tile.state = 'reserved'; tile.endsAt = now + HOLD_MS; demo.selected = id;
  return true;
}
export function release(demo) {
  const tile = demo.tiles.find(tile => tile.id === demo.selected);
  if (tile?.state === 'reserved') { tile.state = 'available'; tile.endsAt = null; }
  demo.selected = null;
}
export function claim(demo, donor, now) {
  expireHolds(demo, now);
  const tile = demo.tiles.find(tile => tile.id === demo.selected);
  if (!tile || tile.state !== 'reserved' || !['Anonymous','Demo Supporter'].includes(donor)) return false;
  tile.state = 'claimed'; tile.endsAt = null; tile.donor = donor;
  demo.raised += tile.amount;
  demo.activity.unshift({donor,amount:tile.amount}); demo.activity = demo.activity.slice(0,3);
  demo.selected = null;
  return true;
}
export function spinCandidate(demo, random = Math.random()) {
  const available = demo.tiles.filter(tile => tile.state === 'available');
  if (!available.length) return null;
  return available[Math.min(available.length - 1, Math.max(0,Math.floor(random * available.length)))].id;
}
