import {GOAL,BOARDS,createDemo,getTile,cartItems,cartTotal,addToCart,removeFromCart,clearCart,beginHold,release,expireHolds,confirmHold,simulateAvailabilityChange,pageInfo,pageTiles,setPage,jumpAmount,spinCandidate} from './state.mjs';
const $=id=>document.getElementById(id);
const money=value=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(value);
let config=BOARDS[0],demo=createDemo(Date.now(),config),spinId=null,opener=null,dialogStage='cart',confirmation=null;
const dialog=$('reservation');
function announce(text){$('status').textContent=text;}
function element(tag,className,text){const node=document.createElement(tag);if(className)node.className=className;if(text!==undefined)node.textContent=text;return node;}
function focusTile(id){document.querySelector(`[data-tile="${id}"]`)?.focus();}
function renderGrid(){
  const focused=document.activeElement?.dataset.tile;
  $('tiles').replaceChildren(...pageTiles(demo).map(tile=>{
    const selected=demo.cart.has(tile.id),state=tile.state==='available'&&selected?'selected':tile.state;
    const button=element('button','tile');button.type='button';button.dataset.tile=tile.id;button.dataset.state=state;if(money(tile.amount).length>6)button.classList.add('large-amount');
    button.setAttribute('aria-pressed',String(selected));button.setAttribute('aria-disabled',String(tile.state!=='available'));
    button.setAttribute('aria-label',`${money(tile.amount)}, ${state}${selected?', remove from cart':tile.state==='claimed'?`, ${tile.donor}`:''}`);
    const description=state==='selected'?'✓ Selected':state==='reserved'?'◷ Reserved':state==='claimed'?'✓ Claimed':'Available';
    const attribution=state==='selected'?'In your cart':state==='claimed'?tile.donor:state==='reserved'?(tile.owner===demo.hold?.id?'Your group hold':'Held elsewhere'):'Tap to select';
    button.append(element('span','tile-amount',money(tile.amount)),element('span','tile-state',description),element('span','tile-attribution',attribution));
    button.addEventListener('click',()=>selectTile(tile.id));return button;
  }));
  if(focused)focusTile(focused);
}
function renderNavigation(){
  const info=pageInfo(demo);
  $('tile-count').textContent=`${demo.board.count.toLocaleString()} tiles`;
  $('amount-range').textContent=`${money(info.start)}–${money(info.end)}`;
  $('page-caption').textContent=`Page ${info.page+1} of ${info.pages.toLocaleString()}`;
  $('page-input').value=String(info.page+1);$('page-input').max=String(info.pages);$('page-total').textContent=`/ ${info.pages.toLocaleString()}`;
  $('first').disabled=$('previous').disabled=info.page===0;$('last').disabled=$('next').disabled=info.page===info.pages-1;
  // Direct range selection stays bounded even for thousands of pages.
  const pages=new Set([0,info.pages-1]);if(info.pages<=20){for(let page=0;page<info.pages;page++)pages.add(page);}else for(let page=Math.max(0,info.page-3);page<=Math.min(info.pages-1,info.page+3);page++)pages.add(page);
  $('range').replaceChildren(...[...pages].sort((a,b)=>a-b).map(page=>{const range=pageInfo(demo,page);const option=element('option','',`${money(range.start)}–${money(range.end)}`);option.value=String(page);option.selected=page===demo.page;return option;}));
}
function removeButton(tile,location){const button=element('button','remove','×');button.type='button';button.setAttribute('aria-label',`Remove ${money(tile.amount)} from ${location}`);button.addEventListener('click',()=>{removeFromCart(demo,tile.id);render();if(dialog.open){renderReview();$('release').focus();}announce(`${money(tile.amount)} removed. ${demo.cart.size} tiles remain; subtotal ${money(cartTotal(demo))}.`);});return button;}
function renderCart(){
  const items=cartItems(demo),total=cartTotal(demo),count=items.length,label=`${count} ${count===1?'tile':'tiles'} selected`;
  $('cart-count').textContent=$('sticky-count').textContent=label;$('cart-subtotal').textContent=$('sticky-total').textContent=money(total);
  $('cart-empty').hidden=count>0;$('sticky-cart').hidden=count===0;
  $('panel-review').disabled=$('panel-clear').disabled=count===0;
  $('cart-preview').replaceChildren(...items.slice(0,8).map(tile=>{const li=element('li');li.append(element('strong','',money(tile.amount)),removeButton(tile,'cart'));return li;}));
  $('cart-preview-note').hidden=count<=8;$('cart-preview-note').textContent=`${count-8} more in your cart. Review Cart shows every tile.`;
}
function renderActivity(){
  $('activity-list').replaceChildren(...demo.activity.map(item=>{const li=element('li');const avatar=element('span','avatar',item.donor==='Anonymous'?'A':'DS');avatar.setAttribute('aria-hidden','true');const supporter=element('span','supporter',item.donor);supporter.append(element('small','',item.count?`${item.count} tiles · simulated support`:'Simulated support'));li.append(avatar,supporter,element('strong','',money(item.amount)));return li;}));
}
function render(){const funded=(demo.raised/GOAL*100).toFixed(1);$('raised').textContent=money(demo.raised);$('percent').textContent=`${funded}% funded`;$('progress').value=Math.min(GOAL,demo.raised);$('progress').textContent=`${funded}%`;$('remaining').textContent=demo.raised>=GOAL?'Demo goal reached!':`${money(GOAL-demo.raised)} to go`;renderGrid();renderNavigation();renderCart();renderActivity();}
function selectTile(id){
  const tile=getTile(demo,id);
  if(demo.cart.has(id)&&tile.state==='available'){removeFromCart(demo,id);render();focusTile(id);announce(`${money(tile.amount)} removed from cart.`);return;}
  if(!addToCart(demo,id)){announce(`${money(tile.amount)} is unavailable or already selected. Your cart was preserved.`);return;}
  render();focusTile(id);$('added').hidden=false;$('added-title').textContent='Tile Added to Cart';$('added-detail').textContent=`${money(tile.amount)} selected · ${demo.cart.size} ${demo.cart.size===1?'tile':'tiles'} · ${money(cartTotal(demo))} subtotal`;
  announce(`${money(tile.amount)} added to cart. ${demo.cart.size} selected. Subtotal ${money(cartTotal(demo))}.`);
}
function movePage(page){if(!setPage(demo,page)){announce('Choose a whole page number.');return;}renderGrid();renderNavigation();$('range').focus();$('board').scrollIntoView({block:'start'});announce(`Showing ${$('amount-range').textContent}, page ${demo.page+1} of ${demo.board.pages}. Cart preserved.`);}
function showJump(){const result=jumpAmount(demo,$('jump').value);$('jump-result').hidden=false;if(!result.ok){$('jump-result').textContent=result.reason;announce(result.reason);return;}renderGrid();renderNavigation();$('jump-result').textContent=result.exact?`Showing ${money(result.amount)}. ${result.state}.`:`That amount is not configured. Nearest configured tile: ${money(result.amount)} (${result.state}).`;focusTile(result.id);const tile=document.querySelector(`[data-tile="${result.id}"]`);tile.dataset.jump='true';tile.scrollIntoView({block:'center'});announce(`${$('jump-result').textContent} Your cart is preserved.`);}
function showSearch(){ $('jump-row').hidden=false;$('jump-toggle').setAttribute('aria-expanded','true');$('jump').focus(); }
function mode(value){demo.mode=value;$('donate-mode').setAttribute('aria-pressed',String(value==='donate'));$('spin-mode').setAttribute('aria-pressed',String(value==='spin'));$('spin-panel').hidden=value!=='spin';$('mode-help').textContent=value==='spin'?'Spin picks an eligible available tile. Add it to your cart when you choose.':'Pick available tiles. Your cart stays with you.';announce(value==='spin'?'Spin mode. Your cart is preserved.':'Donate mode. Your cart is preserved.');}
function spin(){spinId=spinCandidate(demo);$('spin-add').disabled=spinId===null;$('spin-result').textContent=spinId===null?'No eligible tiles':money(getTile(demo,spinId).amount);announce(spinId===null?'No eligible tiles remain. Your cart is preserved.':`${$('spin-result').textContent} is available. Add to Cart or Spin Again. Nothing was held or claimed.`);}
function renderReview(){
  const held=dialogStage==='checkout'&&demo.hold;
  const items=dialogStage==='confirmed'?confirmation.items:held?demo.hold.items.map(id=>getTile(demo,id)):cartItems(demo);
  const total=items.reduce((sum,t)=>sum+t.amount,0);
  $('dialog-stage').textContent=dialogStage==='confirmed'?'SIMULATION COMPLETE':held?'DEMO CHECKOUT REVIEW':'YOUR DEMO CART';
  $('reservation-title').textContent=dialogStage==='confirmed'?'Thank you, demo supporter.':held?'Your group is on hold.':'Review your cart.';
  $('review-items').replaceChildren(...items.map(tile=>{const li=element('li');const text=element('span','',money(tile.amount));if(held&&tile.owner!==demo.hold.id)text.append(element('small','inline-note',' · unavailable'));li.append(text);if(dialogStage==='confirmed')li.append(element('span','tile-state','✓ Simulated'));else if(demo.cart.has(tile.id))li.append(removeButton(tile,'review'));return li;}));
  $('review-count').textContent=`${items.length} ${items.length===1?'tile':'tiles'} ${dialogStage==='confirmed'?'simulated':'selected'}`;$('review-subtotal').textContent=money(total);$('review-total').textContent=`Total ${money(total)}`;
  $('hold').hidden=$('attribution').hidden=$('claim').hidden=!held;$('continue').hidden=Boolean(held)||dialogStage==='confirmed';$('continue').disabled=!items.length;$('claim').disabled=!held;$('conflict-demo').hidden=!held;$('review-clear').hidden=Boolean(held)||dialogStage==='confirmed';$('review-clear').disabled=!items.length;
  $('release').textContent=dialogStage==='confirmed'?'Back to the Board':'Choose More Tiles';
  if(held)updateTimer();
}
function review(source){if(!demo.cart.size){announce('Choose an available tile first.');return;}opener=source;dialogStage='cart';confirmation=null;$('checkout-status').textContent='Selected tiles are not yet held.';renderReview();dialog.showModal();$('continue').focus();}
function closeReview(){release(demo);dialog.close();dialogStage='cart';render();if(opener?.isConnected&&opener.getClientRects().length)opener.focus();else $('range').focus();announce('Back to the board. Any demo hold was released; your remaining selections are preserved.');}
function checkout(){const result=beginHold(demo);if(!result.ok){$('checkout-status').textContent=result.reason==='availability'?'Some selections became unavailable. No group hold was created. Review the remaining tiles.':'Select available tiles before continuing.';render();renderReview();announce($('checkout-status').textContent);return;}dialogStage='checkout';$('checkout-status').textContent='One coordinated simulated hold. All tiles will be checked again before confirmation.';render();renderReview();$('claim').focus();announce(`${demo.hold.items.length} tiles on one accelerated 90-second demo hold. No payment is collected.`);}
function confirm(){const holdId=demo.hold?.id,items=demo.hold?.items.map(id=>({...getTile(demo,id)}))??[];$('claim').disabled=true;const donor=document.querySelector('input[name="attribution"]:checked').value;const result=confirmHold(demo,holdId,donor);if(result.ok){confirmation={items,total:result.total,donor};dialogStage='confirmed';$('checkout-status').textContent=`${result.count} tiles simulated for ${donor}. ${money(result.total)} added exactly once. No money was collected.`;}else{dialogStage='cart';$('checkout-status').textContent=result.reason==='availability'?'Availability changed. Nothing was confirmed; no progress was added. Eligible selections are preserved.':'The demo hold expired or was already confirmed. No progress was added.';}render();renderReview();$('release').focus();announce($('checkout-status').textContent);}
function updateTimer(){if(!demo.hold)return;const seconds=Math.max(0,Math.ceil((demo.hold.endsAt-Date.now())/1000));$('countdown').textContent=`${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;}
function tick(){const before=demo.hold?.id;if(expireHolds(demo,Date.now())){render();if(before&&!demo.hold){dialogStage='cart';$('checkout-status').textContent='The entire demo hold expired. No donation occurred. Eligible selections remain in your cart.';if(dialog.open){renderReview();$('continue').focus();}announce($('checkout-status').textContent);}}updateTimer();}
function reset(){release(demo);dialog.close();demo=createDemo(Date.now(),config);spinId=null;confirmation=null;dialogStage='cart';$('added').hidden=true;$('jump-result').hidden=true;$('checkout-status').textContent='';$('spin-result').textContent='Ready to spin?';$('spin-add').disabled=true;mode('donate');render();announce('Demonstration reset. All changes were browser-local.');}
function applyBoard(next){try{const nextDemo=createDemo(Date.now(),next);config=next;demo=nextDemo;spinId=null;confirmation=null;dialogStage='cart';$('added').hidden=true;$('jump-result').hidden=true;mode('donate');render();$('config-error').textContent='';announce(`Demo reset with ${demo.board.count.toLocaleString()} tiles. At most 50 tiles render per page.`);}catch(error){$('config-error').textContent=error.message;announce(error.message);}}
$('donate-mode').addEventListener('click',()=>mode('donate'));$('spin-mode').addEventListener('click',()=>{mode('spin');if(spinId===null)spin();});$('spin').addEventListener('click',spin);
$('spin-add').addEventListener('click',()=>{if(spinId===null)return;const id=spinId;if(!addToCart(demo,id)){announce('That pick is no longer eligible. Spin Again; your cart is preserved.');spin();return;}jumpAmount(demo,getTile(demo,id).amount);render();$('added').hidden=false;$('added-title').textContent='Tile Added to Cart';$('added-detail').textContent=`${money(getTile(demo,id).amount)} selected · ${money(cartTotal(demo))} subtotal`;$('spin-add').disabled=true;spinId=null;announce('Spin pick added to cart. No hold or payment.');});
$('spin-more').addEventListener('click',()=>{mode('donate');$('donate-mode').focus();});$('added-more').addEventListener('click',()=>{$('added').hidden=true;$('range').focus();});
for(const id of ['panel-review','added-review','sticky-review'])$(id).addEventListener('click',event=>review(event.currentTarget));
$('panel-clear').addEventListener('click',()=>{clearCart(demo);render();announce('Entire cart cleared. No donation was made.');});$('review-clear').addEventListener('click',()=>{clearCart(demo);dialogStage='cart';render();renderReview();$('release').focus();announce('Entire cart cleared; all demo holds released.');});
$('close').addEventListener('click',closeReview);$('release').addEventListener('click',closeReview);dialog.addEventListener('cancel',event=>{event.preventDefault();closeReview();});
// Trap focus using current visible controls, including dynamic checkout stages.
 dialog.addEventListener('keydown',event=>{if(event.key!=='Tab')return;const controls=[...dialog.querySelectorAll('button,input,summary')].filter(node=>!node.disabled&&!node.hidden&&node.getClientRects().length&&(node.type!=='radio'||node.checked));const first=controls[0],last=controls.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}});
$('continue').addEventListener('click',checkout);$('claim').addEventListener('click',confirm);$('conflict').addEventListener('click',()=>{if(!demo.hold)return;const id=demo.hold.items.find(item=>getTile(demo,item).owner===demo.hold.id);if(id===undefined)return;simulateAvailabilityChange(demo,id);$('checkout-status').textContent=`Demo availability changed for ${money(getTile(demo,id).amount)}. Confirmation will recheck the complete group.`;render();renderReview();$('claim').focus();announce($('checkout-status').textContent);});
for(const id of ['reset','menu-reset','footer-reset'])$(id).addEventListener('click',reset);
$('range').addEventListener('change',event=>movePage(Number(event.target.value)));$('first').addEventListener('click',()=>movePage(0));$('last').addEventListener('click',()=>movePage(demo.board.pages-1));$('previous').addEventListener('click',()=>movePage(demo.page-1));$('next').addEventListener('click',()=>movePage(demo.page+1));$('page-input').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();const page=Number(event.target.value);if(!Number.isInteger(page)||page<1||page>demo.board.pages){announce(`Use a page number from 1 to ${demo.board.pages}.`);return;}movePage(page-1);}});
// Cancel Enter's default activation before transferring focus to a tile.
$('search-toggle').addEventListener('click',showSearch);$('jump-toggle').addEventListener('click',showSearch);$('show-amount').addEventListener('click',showJump);$('jump').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();showJump();}});
$('board-config').addEventListener('change',event=>{$('custom-config').hidden=event.target.value!=='custom';if(event.target.value!=='custom')applyBoard(BOARDS[Number(event.target.value)]);});$('apply-config').addEventListener('click',()=>applyBoard({name:'Custom demo board',start:Number($('custom-start').value),end:Number($('custom-end').value),step:Number($('custom-step').value)}));
$('menu-toggle').addEventListener('click',()=>{const open=$('preview-menu').hidden;$('preview-menu').hidden=!open;$('menu-toggle').setAttribute('aria-expanded',String(open));});document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!$('preview-menu').hidden){$('preview-menu').hidden=true;$('menu-toggle').setAttribute('aria-expanded','false');$('menu-toggle').focus();}});
document.querySelectorAll('.bottom-nav a').forEach(link=>link.addEventListener('click',()=>{document.querySelectorAll('.bottom-nav a').forEach(item=>item.removeAttribute('aria-current'));link.setAttribute('aria-current','page');}));
render();setInterval(tick,1000);
