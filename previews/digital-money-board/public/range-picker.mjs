// Keep the same small-board ranges and nearby-page shortcuts for large boards.
export function rangePages(current,total){
  const pages=new Set([0,total-1]);
  if(total<=20){for(let page=0;page<total;page++)pages.add(page);}
  else for(let page=Math.max(0,current-3);page<=Math.min(total-1,current+3);page++)pages.add(page);
  return [...pages].sort((a,b)=>a-b);
}

// Menu-button pattern: one tab stop; arrow keys move focus without changing page.
export function createRangePicker({trigger,value,panel,options,hint,next,onSelect,document:doc=globalThis.document,window:win=globalThis.window}){
  let choices=[],current=0,buttons=[];
  const contains=node=>trigger.contains(node)||panel.contains(node);
  function close(restore=false){panel.hidden=true;trigger.setAttribute('aria-expanded','false');if(restore)trigger.focus({preventScroll:true});}
  function position(){
    if(panel.hidden)return;
    const anchor=trigger.getBoundingClientRect(),gutter=12;
    const bars=[...doc.querySelectorAll('.bottom-nav,#sticky-cart')].filter(node=>!node.hidden&&node.getClientRects().length);
    const bottom=Math.min(win.innerHeight-gutter,...bars.map(node=>node.getBoundingClientRect().top-gutter));
    if(anchor.bottom<gutter||anchor.top>bottom){close(panel.contains(doc.activeElement));return;}
    const width=Math.min(win.innerWidth-2*gutter,win.innerWidth<=600?win.innerWidth-2*gutter:360);
    panel.style.width=`${width}px`;panel.style.left=`${Math.max(gutter,Math.min(anchor.left,win.innerWidth-width-gutter))}px`;
    const below=bottom-anchor.bottom-8,above=anchor.top-gutter-8;
    const useBelow=below>=220||below>=above,space=Math.max(80,useBelow?below:above);
    panel.style.maxHeight=`${Math.min(390,space)}px`;
    panel.style.top=`${useBelow?anchor.bottom+8:Math.max(gutter,anchor.top-8-panel.getBoundingClientRect().height)}px`;
  }
  function focus(index){
    index=Math.max(0,Math.min(buttons.length-1,index));
    buttons.forEach((button,i)=>button.tabIndex=i===index?0:-1);
    const button=buttons[index];if(!button)return;
    button.focus({preventScroll:true});
    // Scroll only the menu, never its underlying tile board.
    const item=button.getBoundingClientRect(),menu=panel.getBoundingClientRect();
    if(item.top<menu.top+6)panel.scrollTop-=menu.top+6-item.top;
    else if(item.bottom>menu.bottom-6)panel.scrollTop+=item.bottom-menu.bottom+6;
  }
  function open(edge){
    if(!buttons.length)return;
    panel.hidden=false;trigger.setAttribute('aria-expanded','true');position();
    focus(edge==='last'?buttons.length-1:choices.findIndex(choice=>choice.page===current));
  }
  trigger.addEventListener('click',()=>panel.hidden?open():close(true));
  trigger.addEventListener('keydown',event=>{
    if(['ArrowDown','ArrowUp'].includes(event.key)){event.preventDefault();open(event.key==='ArrowUp'?'last':undefined);}
    else if(event.key==='Escape'&&!panel.hidden){event.preventDefault();close(true);}
  });
  panel.addEventListener('keydown',event=>{
    const index=buttons.indexOf(doc.activeElement),columns=win.innerWidth>600?2:1;
    if(event.key==='Escape'){event.preventDefault();close(true);}
    else if(event.key==='Tab'){event.preventDefault();close();(event.shiftKey?trigger:next).focus();}
    else if(['ArrowDown','ArrowUp','ArrowLeft','ArrowRight','Home','End'].includes(event.key)){
      event.preventDefault();
      focus(event.key==='Home'?0:event.key==='End'?buttons.length-1:index+({ArrowDown:columns,ArrowUp:-columns,ArrowLeft:-1,ArrowRight:1}[event.key]));
    }
  });
  doc.addEventListener('pointerdown',event=>{if(!panel.hidden&&!contains(event.target))close();});
  doc.addEventListener('focusin',event=>{if(!panel.hidden&&!contains(event.target))close();});
  win.addEventListener('resize',position);
  win.addEventListener('scroll',event=>{if(!panel.contains(event.target))position();},true);
  return {update({items,selected,total}){
    const focusedPage=choices[buttons.indexOf(doc.activeElement)]?.page,wasFocused=buttons.includes(doc.activeElement);
    choices=items;current=selected;
    const label=choices.find(choice=>choice.page===current)?.label??'';
    value.textContent=label;trigger.setAttribute('aria-label',`Amount range: ${label}. Choose a range`);
    hint.textContent=total>20?'Nearby ranges + first and last. Jump to any amount.':`${total} ${total===1?'range':'ranges'} · choose your next impact`;
    buttons=choices.map(choice=>{
      const button=doc.createElement('button');button.type='button';button.className='range-option';button.textContent=choice.label;
      button.setAttribute('role','menuitemradio');button.setAttribute('aria-checked',String(choice.page===current));button.tabIndex=-1;
      button.addEventListener('click',()=>{close(true);onSelect(choice.page);});return button;
    });
    options.replaceChildren(...buttons);
    if(!panel.hidden){position();if(wasFocused)focus(Math.max(0,choices.findIndex(choice=>choice.page===(focusedPage??current))));}
  }};
}
