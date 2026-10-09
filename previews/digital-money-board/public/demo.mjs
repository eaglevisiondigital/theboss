import {GOAL,createDemo,expireHolds,reserve,release,claim,spinCandidate} from './state.mjs';
const $ = id => document.getElementById(id);
const money = value => new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(value);
let demo = createDemo();
let returnId = null;
const dialog = $('reservation');
function announce(text) { $('status').textContent = text; }
function render() {
  const funded = (demo.raised / GOAL * 100).toFixed(1);
  $('raised').textContent = money(demo.raised);
  $('remaining').textContent = demo.raised >= GOAL ? 'Demo goal reached!' : `${money(GOAL - demo.raised)} to go`;
  $('percent').textContent = `${funded}% funded`;
  $('progress').value = Math.min(GOAL,demo.raised); $('progress').textContent = `${funded}%`;
  $('tiles').replaceChildren(...demo.tiles.map(tile => {
    const button = document.createElement('button'); button.type = 'button'; button.className = 'tile'; button.dataset.state = tile.state; button.dataset.tile = tile.id;
    button.setAttribute('aria-disabled',String(tile.state !== 'available'));
    button.setAttribute('aria-label',`${money(tile.amount)}, ${tile.state}${tile.state === 'claimed' ? `, ${tile.donor}` : ''}`);
    const amount = document.createElement('span'); amount.className = 'tile-amount'; amount.textContent = money(tile.amount);
    const state = document.createElement('span'); state.className = 'tile-state'; state.textContent = tile.state === 'claimed' ? '✓ Claimed' : tile.state === 'reserved' ? '◷ Reserved' : 'Available';
    const attribution = document.createElement('span'); attribution.className = 'tile-attribution'; attribution.textContent = tile.state === 'claimed' ? tile.donor : tile.state === 'reserved' ? 'Temporary demo hold' : 'Make it yours';
    button.append(amount,state,attribution); button.addEventListener('click',() => select(tile.id)); return button;
  }));
  $('activity-list').replaceChildren(...demo.activity.map(item => {
    const li = document.createElement('li'); const avatar = document.createElement('span'); avatar.className = 'avatar'; avatar.setAttribute('aria-hidden','true'); avatar.textContent = item.donor === 'Anonymous' ? 'A' : 'DS';
    const supporter = document.createElement('span'); supporter.className = 'supporter'; supporter.textContent = item.donor;
    const detail = document.createElement('small'); detail.textContent = 'Simulated support'; supporter.append(detail);
    const value = document.createElement('strong'); value.textContent = money(item.amount); li.append(avatar,supporter,value); return li;
  }));
}
function restoreFocus() { if(returnId !== null) document.querySelector(`[data-tile="${returnId}"]`)?.focus(); returnId = null; }
function cancel() { release(demo); dialog.close(); render(); restoreFocus(); announce('Demo reservation released. No donation was made.'); }
function select(id) {
  const tile = demo.tiles.find(tile => tile.id === id);
  if (!reserve(demo,id,Date.now())) { announce(`${money(tile.amount)} is ${tile.state}. Choose an available tile.`); return; }
  returnId = id; render(); $('selected-amount').textContent = money(tile.amount);
  document.querySelector('input[value="Demo Supporter"]').checked = true;
  tick(); dialog.showModal(); $('claim').focus(); announce(`${money(tile.amount)} reserved for 90 seconds in this demo.`);
}
function mode(value) {
  demo.mode = value;
  $('donate-mode').setAttribute('aria-pressed',String(value === 'donate')); $('spin-mode').setAttribute('aria-pressed',String(value === 'spin'));
  $('spin-panel').hidden = value !== 'spin'; $('mode-help').textContent = value === 'spin' ? 'Try a random available tile. This is only a simulation.' : 'Choose an available amount to preview a donation.';
  announce(value === 'spin' ? 'Spin mode selected.' : 'Donate mode selected.');
}
function tick() {
  const now = Date.now(); const selectedBefore = demo.selected;
  if (expireHolds(demo,now)) {
    const activeTile = document.activeElement?.dataset.tile; render();
    if (activeTile) document.querySelector(`[data-tile="${activeTile}"]`)?.focus();
    if (selectedBefore !== null && demo.selected === null) { dialog.close(); restoreFocus(); announce('Your demo hold expired. The tile is available again.'); }
  }
  const selected = demo.tiles.find(tile => tile.id === demo.selected);
  if (selected) { const seconds = Math.max(0,Math.ceil((selected.endsAt-now)/1000)); $('countdown').textContent = `${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`; }
}
$('donate-mode').addEventListener('click',() => mode('donate'));
$('spin-mode').addEventListener('click',() => mode('spin'));
$('spin').addEventListener('click',() => { expireHolds(demo,Date.now()); const id = spinCandidate(demo); if(id === null) announce('All demo tiles are claimed. Reset to try again.'); else select(id); });
$('close').addEventListener('click',cancel); $('release').addEventListener('click',cancel);
dialog.addEventListener('cancel',event => { event.preventDefault(); cancel(); });
// Keep Tab inside the preview dialog, including browsers that otherwise tab to chrome.
dialog.addEventListener('keydown',event => {
  if(event.key !== 'Tab') return;
  const first = $('close'), last = $('release');
  if(event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
  else if(!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
});
$('claim').addEventListener('click',() => {
  const tile = demo.tiles.find(tile => tile.id === demo.selected); const donor = document.querySelector('input[name="attribution"]:checked').value;
  const succeeded = claim(demo,donor,Date.now()); dialog.close(); render(); restoreFocus();
  announce(succeeded ? `${money(tile.amount)} simulated for ${donor}. Demo total is ${money(demo.raised)}. No payment occurred.` : 'Demo hold expired. No donation was made.');
});
$('reset').addEventListener('click',() => { dialog.close(); demo = createDemo(); returnId = null; mode('donate'); render(); announce('Demo reset. All changes were local and have been cleared.'); });
document.querySelectorAll('.bottom-nav a').forEach(link => link.addEventListener('click',() => { document.querySelectorAll('.bottom-nav a').forEach(item => item.removeAttribute('aria-current')); link.setAttribute('aria-current','page'); }));
render(); setInterval(tick,1000);
