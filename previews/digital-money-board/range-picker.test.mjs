import test from 'node:test';
import assert from 'node:assert/strict';
import {rangePages,createRangePicker} from './public/range-picker.mjs';
import {createDemo,pageInfo,setPage,addToCart,cartTotal,jumpAmount} from './public/state.mjs';

// Minimal event/element harness executes the shipping controller. Actual layout,
// native Enter/Space activation and focus are also checked in the native browser.
function fixture(width=1440){
  const doc={activeElement:null,listeners:{},querySelectorAll:()=>[],addEventListener(type,callback){this.listeners[type]=callback;}};
  class Node {
    constructor(){this.children=[];this.attrs={};this.events={};this.style={};this.hidden=false;this.scrollTop=0;}
    contains(node){return this===node||this.children.some(child=>child.contains(node));}
    addEventListener(type,callback){this.events[type]=callback;}
    setAttribute(key,value){this.attrs[key]=value;}
    replaceChildren(...children){this.children=children;}
    focus(){doc.activeElement=this;}
    getBoundingClientRect(){return {left:20,top:200,bottom:244,height:44};}
    fire(type,extra={}){const event={target:this,preventDefault(){this.prevented=true;},...extra};this.events[type]?.(event);return event;}
  }
  doc.createElement=()=>new Node();
  const win={innerWidth:width,innerHeight:1000,listeners:{},addEventListener(type,callback){this.listeners[type]=callback;}};
  const trigger=new Node(),value=new Node(),panel=new Node(),options=new Node(),hint=new Node(),next=new Node();panel.hidden=true;panel.children=[options];
  const selected=[];
  const picker=createRangePicker({trigger,value,panel,options,hint,next,document:doc,window:win,onSelect:page=>selected.push(page)});
  const update=(current=2,total=10)=>picker.update({items:rangePages(current,total).map(page=>({page,label:`range ${page}`})),selected:current,total});
  update();
  return {doc,win,trigger,value,panel,options,hint,next,selected,picker,update};
}
test('range shortcuts retain complete small boards and bound million-page boards to nine',()=>{
  assert.deepEqual(rangePages(0,1),[0]);assert.equal(rangePages(5,20).length,20);
  for(const current of [0,1,500000,999998,999999]){
    const pages=rangePages(current,1000000);assert(pages.length<=9);assert(pages.includes(current));assert.equal(pages[0],0);assert.equal(pages.at(-1),999999);assert.deepEqual(pages,[...new Set(pages)].sort((a,b)=>a-b));
  }
});
test('opening focuses selected range, exposes checked state and accessible label without changing page',()=>{
  const f=fixture();f.trigger.fire('click');assert.equal(f.panel.hidden,false);assert.equal(f.trigger.attrs['aria-expanded'],'true');assert.equal(f.doc.activeElement,f.options.children[2]);assert.equal(f.options.children[2].attrs['aria-checked'],'true');assert.match(f.trigger.attrs['aria-label'],/Amount range: range 2/);assert.deepEqual(f.selected,[]);
});
test('desktop arrows follow both columns; Home/End stay bounded and never select',()=>{
  const f=fixture();f.trigger.fire('keydown',{key:'ArrowDown'});
  f.panel.fire('keydown',{key:'ArrowDown'});assert.equal(f.doc.activeElement,f.options.children[4]);
  f.panel.fire('keydown',{key:'ArrowRight'});assert.equal(f.doc.activeElement,f.options.children[5]);
  f.panel.fire('keydown',{key:'ArrowUp'});assert.equal(f.doc.activeElement,f.options.children[3]);
  f.panel.fire('keydown',{key:'ArrowLeft'});assert.equal(f.doc.activeElement,f.options.children[2]);
  f.panel.fire('keydown',{key:'End'});assert.equal(f.doc.activeElement,f.options.children[9]);
  f.panel.fire('keydown',{key:'ArrowDown'});assert.equal(f.doc.activeElement,f.options.children[9]);
  f.panel.fire('keydown',{key:'Home'});assert.equal(f.doc.activeElement,f.options.children[0]);assert.deepEqual(f.selected,[]);
});
test('mobile arrows move one row; Escape restores trigger without submitting',()=>{
  const f=fixture(320);f.trigger.fire('click');f.panel.fire('keydown',{key:'ArrowDown'});assert.equal(f.doc.activeElement,f.options.children[3]);
  assert(f.panel.fire('keydown',{key:'Escape'}).prevented);assert(f.panel.hidden);assert.equal(f.doc.activeElement,f.trigger);assert.deepEqual(f.selected,[]);
});
test('pointer selection closes the menu before invoking page callback exactly once',()=>{
  const f=fixture();f.trigger.fire('click');f.options.children[6].fire('click');assert(f.panel.hidden);assert.equal(f.trigger.attrs['aria-expanded'],'false');assert.equal(f.doc.activeElement,f.trigger);assert.deepEqual(f.selected,[6]);
});
test('outside pointer/focus dismiss without stealing focus; internal clicks do not dismiss',()=>{
  const f=fixture();f.trigger.fire('click');f.doc.listeners.pointerdown({target:f.options.children[2]});assert(!f.panel.hidden);
  f.doc.listeners.pointerdown({target:f.next});assert(f.panel.hidden);assert.equal(f.doc.activeElement,f.options.children[2]);
  f.trigger.fire('click');f.next.focus();f.doc.listeners.focusin({target:f.next});assert(f.panel.hidden);assert.equal(f.doc.activeElement,f.next);
});
test('Tab moves to Jump to Amount, Shift+Tab returns to selector with no focus trap',()=>{
  const f=fixture();f.trigger.fire('click');assert(f.panel.fire('keydown',{key:'Tab'}).prevented);assert(f.panel.hidden);assert.equal(f.doc.activeElement,f.next);
  f.trigger.fire('click');f.panel.fire('keydown',{key:'Tab',shiftKey:true});assert.equal(f.doc.activeElement,f.trigger);
});
test('timer rerender preserves focused range, selected ARIA state and bounded shortcuts',()=>{
  const f=fixture();f.trigger.fire('click');f.panel.fire('keydown',{key:'ArrowDown'});f.update();assert.equal(f.doc.activeElement,f.options.children[4]);assert(!f.panel.hidden);
  f.update(500000,1000000);assert.equal(f.options.children.length,9);assert.equal(f.value.textContent,'range 500000');assert.match(f.hint.textContent,/Nearby ranges/);assert.equal(f.options.children.filter(node=>node.attrs['aria-checked']==='true').length,1);
});
test('picker callback integrates with real generated pages while cart and jump remain intact',()=>{
  const demo=createDemo(0,{start:5,end:1000000,step:1});assert(addToCart(demo,'0'));assert(addToCart(demo,'1'));
  const f=fixture();f.picker=createRangePicker({trigger:f.trigger,value:f.value,panel:f.panel,options:f.options,hint:f.hint,next:f.next,document:f.doc,window:f.win,onSelect:page=>setPage(demo,page)});
  const info=pageInfo(demo);f.picker.update({items:rangePages(info.page,info.pages).map(page=>({page,label:String(page)})),selected:info.page,total:info.pages});
  f.trigger.fire('click');f.options.children.at(-1).fire('click');assert.equal(demo.page,demo.board.pages-1);assert.equal(cartTotal(demo),11);
  assert(jumpAmount(demo,'175').ok);assert.equal(pageInfo(demo).start,151);assert.equal(cartTotal(demo),11);
});

test('scrolling the trigger outside the usable viewport dismisses the menu and restores focus',()=>{
  const f=fixture();f.trigger.fire('click');f.trigger.getBoundingClientRect=()=>({left:20,top:-100,bottom:-56,height:44});
  f.win.listeners.scroll({target:f.doc});assert(f.panel.hidden);assert.equal(f.trigger.attrs['aria-expanded'],'false');assert.equal(f.doc.activeElement,f.trigger);
});
