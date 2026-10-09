// Synthetic, browser-local state. These holds are not authoritative reservations.
export const GOAL = 10000;
export const HOLD_MS = 90000;
export const ORIGINAL_AMOUNTS = [25,35,50,60,75,85,100,125,150,175,200,225,250,275,300,325,350,375,400,425,450,475,500,550];
export const BOARDS = [
  {name:'$5–$500 · $1 steps',start:5,end:500,step:1},
  {name:'Original small collection · 24 tiles',amounts:ORIGINAL_AMOUNTS},
  {name:'$25–$2,500 · $5 steps',start:25,end:2500,step:5},
  {name:'$100–$10,000 · $10 steps',start:100,end:10000,step:10},
  {name:'$250–$50,000 · $25 steps',start:250,end:50000,step:25}
];
export function configureBoard(config) {
  if(config.amounts) {
    if(!config.amounts.length || config.amounts.some(n=>!Number.isSafeInteger(n)||n<=0) || new Set(config.amounts).size!==config.amounts.length) throw new Error('Use unique positive whole-dollar amounts.');
    const amounts=[...config.amounts].sort((a,b)=>a-b);
    return {...config,amounts,count:amounts.length,pages:Math.ceil(amounts.length/50)};
  }
  const {start,end,step}=config;
  if(![start,end,step].every(n=>Number.isSafeInteger(n)&&n>0)||end<start||!Number.isSafeInteger(step*50)) throw new Error('Use positive whole-dollar amounts, an end at or above the start, and a valid increment.');
  const count=Math.floor((end-start)/step)+1;
  const last=start+(count-1)*step,span=step*50,base=Math.floor((start-1)/span)*span;
  return {...config,end:last,count,span,base,pages:Math.ceil((last-base)/span)};
}
function seed(index,amount,now) {
  return {id:String(index),amount,state:[2,6,11,17,22].includes(index)?'claimed':index===8?'reserved':'available',donor:[2,11,22].includes(index)?'Anonymous':'Demo Supporter',endsAt:index===8?now+HOLD_MS:null,owner:index===8?'external':null};
}
export function createDemo(now=Date.now(),config={amounts:ORIGINAL_AMOUNTS}) {
  const board=configureBoard(config);
  const demo={board,createdAt:now,raised:6840,selected:null,mode:'donate',page:0,cart:new Set(),hold:null,holdSequence:0,confirmed:new Set(),overrides:new Map(),tiles:[],activity:[{donor:'Anonymous',amount:500},{donor:'Demo Supporter',amount:375},{donor:'Anonymous',amount:225}]};
  if(board.amounts) demo.tiles=board.amounts.map((amount,index)=>seed(index,amount,now));
  else for(const index of [2,6,8,11,17,22]) if(index<board.count) getTile(demo,String(index));
  return demo;
}
export function getTile(demo,id) {
  if(!/^\d+$/.test(String(id))) return null;
  const index=Number(id);
  if(!Number.isSafeInteger(index)||index<0||index>=demo.board.count||String(index)!==String(id)) return null;
  if(demo.board.amounts) return demo.tiles[index];
  if(!demo.overrides.has(String(id))) demo.overrides.set(String(id),seed(index,demo.board.start+index*demo.board.step,demo.createdAt));
  return demo.overrides.get(String(id));
}
export function cartItems(demo) {return [...demo.cart].map(id=>getTile(demo,id)).filter(Boolean);}
export function cartTotal(demo) {return cartItems(demo).reduce((sum,t)=>sum+t.amount,0);}
export function addToCart(demo,id,now=Date.now()) {
  id=String(id);
  expireHolds(demo,now);
  const tile=getTile(demo,id);
  if(demo.hold||!tile||tile.state!=='available'||demo.cart.has(id)||!Number.isSafeInteger(cartTotal(demo)+tile.amount)) return false;
  demo.cart.add(id); return true;
}
export function removeFromCart(demo,id) {
  id=String(id);
  if(!demo.cart.has(id)) return false;
  const tile=getTile(demo,id);
  if(demo.hold&&tile?.owner===demo.hold.id) {tile.state='available';tile.endsAt=null;tile.owner=null;demo.hold.items=demo.hold.items.filter(item=>item!==id);}
  demo.cart.delete(id);
  if(demo.hold&&!demo.hold.items.length) release(demo);
  return true;
}
export function clearCart(demo) {release(demo);demo.cart.clear();}
export function beginHold(demo,now=Date.now(),ids=[...demo.cart]) {
  ids=ids.map(String);
  expireHolds(demo,now);
  if(demo.hold) return {ok:false,reason:'busy',conflicts:[]};
  if(!ids.length||new Set(ids).size!==ids.length) return {ok:false,reason:'empty',conflicts:[]};
  const conflicts=ids.filter(id=>getTile(demo,id)?.state!=='available');
  if(conflicts.length) {conflicts.forEach(id=>demo.cart.delete(id));return {ok:false,reason:'availability',conflicts};}
  const id=`demo-hold-${++demo.holdSequence}`;
  demo.hold={id,items:[...ids],endsAt:now+HOLD_MS};demo.selected=ids[0];
  for(const item of ids) {const tile=getTile(demo,item);tile.state='reserved';tile.endsAt=demo.hold.endsAt;tile.owner=id;}
  return {ok:true,id,total:ids.reduce((sum,item)=>sum+getTile(demo,item).amount,0)};
}
export function release(demo) {
  if(demo.hold) for(const id of demo.hold.items) {
    const tile=getTile(demo,id);
    if(tile?.owner===demo.hold.id) {tile.state='available';tile.endsAt=null;tile.owner=null;}
  }
  demo.hold=null;demo.selected=null;
}
export function expireHolds(demo,now) {
  let changed=false;
  if(demo.hold&&demo.hold.endsAt<=now) {release(demo);changed=true;}
  const tiles=demo.board.amounts?demo.tiles:[...demo.overrides.values()];
  for(const tile of tiles) if(tile.state==='reserved'&&tile.endsAt<=now) {tile.state='available';tile.endsAt=null;tile.owner=null;changed=true;}
  return changed;
}
export function confirmHold(demo,holdId,donor,now=Date.now()) {
  if(demo.confirmed.has(holdId)) return {ok:false,reason:'replay'};
  expireHolds(demo,now);
  if(!demo.hold||demo.hold.id!==holdId) return {ok:false,reason:'expired'};
  if(!['Anonymous','Demo Supporter'].includes(donor)) return {ok:false,reason:'attribution'};
  const hold=demo.hold;
  const conflicts=hold.items.filter(id=>{const tile=getTile(demo,id);return tile?.state!=='reserved'||tile.owner!==holdId;});
  if(conflicts.length) {release(demo);conflicts.forEach(id=>demo.cart.delete(id));return {ok:false,reason:'availability',conflicts};}
  const total=hold.items.reduce((sum,id)=>sum+getTile(demo,id).amount,0);
  if(!Number.isSafeInteger(demo.raised+total)) return {ok:false,reason:'numeric-range'};
  for(const id of hold.items) {const tile=getTile(demo,id);tile.state='claimed';tile.endsAt=null;tile.owner=null;tile.donor=donor;demo.cart.delete(id);}
  demo.raised+=total;demo.confirmed.add(holdId);
  demo.activity.unshift({donor,amount:total,count:hold.items.length});demo.activity=demo.activity.slice(0,3);
  demo.hold=null;demo.selected=null;return {ok:true,total,count:hold.items.length};
}
export function simulateAvailabilityChange(demo,id,now=Date.now()) {
  const tile=getTile(demo,id);
  if(!tile||tile.state==='claimed') return false;
  tile.state='reserved';tile.owner='external';tile.endsAt=now+HOLD_MS;demo.cart.delete(id);return true;
}
// Retain original single-tile hold API/regressions; cart selection is independently multi-tile.
export function reserve(demo,id,now) {return beginHold(demo,now,[id]).ok;}
export function claim(demo,donor,now) {return confirmHold(demo,demo.hold?.id,donor,now).ok;}
export function pageInfo(demo,page=demo.page) {
  const {board}=demo;
  const clamped=Math.min(board.pages-1,Math.max(0,Math.trunc(page)));
  let first,last;
  if(board.amounts) {first=clamped*50;last=Math.min(board.count-1,first+49);}
  else {
    first=clamped===0?0:Math.floor((board.base+clamped*board.span-board.start)/board.step)+1;
    last=Math.min(board.count-1,Math.floor((board.base+(clamped+1)*board.span-board.start)/board.step));
  }
  const amount=index=>board.amounts?board.amounts[index]:board.start+index*board.step;
  return {page:clamped,pages:board.pages,first,last,start:amount(first),end:amount(last),count:last-first+1};
}
export function pageTiles(demo) {const info=pageInfo(demo);return Array.from({length:info.count},(_,i)=>getTile(demo,String(info.first+i)));}
export function setPage(demo,page) {if(!Number.isInteger(page)) return false;demo.page=pageInfo(demo,page).page;return true;}
export function jumpAmount(demo,input) {
  const text=String(input).trim().replace(/^\$/,'').replaceAll(',','');
  if(!/^\d+(\.\d+)?$/.test(text)||!Number.isFinite(Number(text))||Number(text)<=0) return {ok:false,reason:'Enter a positive dollar amount.'};
  const requested=Number(text),{board}=demo;let index;
  if(board.amounts) {index=board.amounts.reduce((best,n,i)=>Math.abs(n-requested)<Math.abs(board.amounts[best]-requested)?i:best,0);}
  else index=Math.min(board.count-1,Math.max(0,Math.round((requested-board.start)/board.step)));
  const tile=getTile(demo,String(index));
  demo.page=board.amounts?Math.floor(index/50):Math.floor((tile.amount-board.base-1)/board.span);
  return {ok:true,id:tile.id,amount:tile.amount,exact:tile.amount===requested,state:tile.state,page:demo.page};
}
export function spinCandidate(demo,random=Math.random(),now=Date.now()) {
  expireHolds(demo,now);
  const tiles=demo.board.amounts?demo.tiles:[...demo.overrides.values()];
  const blocked=new Set([...demo.cart,...tiles.filter(t=>t.state!=='available').map(t=>t.id)]);
  const count=demo.board.count-blocked.size;
  if(count<=0) return null;
  let index=Math.min(count-1,Math.max(0,Math.floor(random*count)));
  for(const skip of [...blocked].map(Number).sort((a,b)=>a-b)) {if(skip<=index) index++;else break;}
  return String(index);
}
