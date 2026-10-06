// Static, illustrative marketing artwork. Keep the approved brand asset unmodified.
const C = { ink: '#18242e', muted: '#71808e', orange: '#ef580b', line: '#e5ebf0', bg: '#f4f7fa' };
const r = (x:number,y:number,w:number,h:number,fill:string,rx=0,stroke='none') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${stroke}"/>`;
const t = (x:number,y:number,text:string,size=12,fill=C.ink,weight=400) => `<text x="${x}" y="${y}" font-family="Inter, Arial, sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}">${text}</text>`;
const line = (x:number,y:number,x2:number,y2:number,color=C.line) => `<path d="M${x} ${y}L${x2} ${y2}" stroke="${color}"/>`;
const logo = (x:number,y:number,size:number) => `<image href="/brand/boss-plus-approved.png" x="${x}" y="${y}" width="${size}" height="${size}" preserveAspectRatio="xMidYMid meet"/>`;
const circle = (x:number,y:number,rad:number,fill:string) => `<circle cx="${x}" cy="${y}" r="${rad}" fill="${fill}"/>`;
const icon = (x:number,y:number,type:string,color=C.muted,size=16) => {
 const paths:Record<string,string> = {
 home:'M3 10 12 3l9 7M5 9v12h5v-7h4v7h5V9',
 grid:'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
 people:'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 4a4 4 0 0 1 0 8M22 21v-2a4 4 0 0 0-3-3M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
 calendar:'M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2ZM7 3v4M17 3v4M3 11h18M7 15h3M14 15h3',
 chat:'M21 11a8 8 0 0 1-8 8H7l-5 3 2-6a8 8 0 1 1 17-5Z',
 file:'M5 3h9l5 5v13H5zM14 3v6h5M8 13h8M8 17h6',
 search:'M16 16l5 5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0',
 bell:'M5 16h14l-2-3V9A5 5 0 0 0 7 9v4zM10 20h4',
 pin:'M19 9c0 5-7 12-7 12S5 14 5 9a7 7 0 1 1 14 0ZM14 9a2 2 0 1 1-4 0 2 2 0 0 1 4 0',
 heart:'M12 21 3 12C-3 4 8-1 12 6c4-7 15-2 9 6Z',
 check:'M5 12l4 4L19 6',
 };
 return `<g transform="translate(${x} ${y}) scale(${size/24})" fill="none" stroke="${color}" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round"><path d="${paths[type]||paths.grid}"/></g>`;
};
const pill=(x:number,y:number,w:number,label:string,active=false)=>r(x,y,w,25,active?'#fff0e6':'white',12,active?'#ffd3b8':C.line)+t(x+11,y+16,label,9,active?'#bd4205':C.muted,600);
function sidebar(active:string) {
 let s=r(0,0,160,500,'#101b23')+logo(17,19,31)+t(58,39,'THE BOSS',13,'white',750)+line(15,66,145,66,'#2a353e');
 s+=t(19,91,'WORKSPACE',8,'#7c8c99',650)+r(13,104,134,34,'#1e2b34',6)+circle(30,121,9,'#eb580d')+t(26,124,'B',9,'white',700)+t(45,125,'Boss Athletics',10,'#eef2f6',600)+t(132,125,'⌄',11,'#a6b4be');
 const nav=[['grid','Overview'],['people','Teams'],['file','Registration'],['calendar','Calendar'],['chat','Messages'],['file','Documents']];
 nav.forEach(([kind,label],i)=>{const y=163+i*38;const selected=label===active;s+=selected?r(10,y-9,140,32,'#382c24',6)+r(10,y-4,3,22,C.orange,1):'';s+=icon(21,y,kind,selected?'#ff803b':'#8193a2',15)+t(46,y+12,label,11,selected?'#ff995f':'#c6d0d8',selected?650:450);if(label==='Messages')s+=circle(133,y+7,8,'#31414e')+t(130,y+10,'3',8,'#dae4eb');});
 return s+line(15,442,145,442,'#2a353e')+circle(29,468,13,'#344550')+t(21,472,'CT',9,'white',650)+t(49,465,'Coach Taylor',10,'#f4f6f8',600)+t(49,480,'Organization admin',8,'#899ba9');
}
function desktop(mode:'overview'|'calendar') {
 let s=sidebar(mode==='overview'?'Overview':'Calendar')+r(160,0,680,500,C.bg);
 s+=r(160,0,680,56,'white')+t(183,33,'Boss Athletics',11,C.muted,550)+t(271,33,'/  '+(mode==='overview'?'Overview':'Calendar'),11)+r(562,15,176,28,C.bg,6)+icon(571,23,'search',C.muted,13)+t(591,33,'Search your workspace',9,C.muted)+icon(758,21,'bell',C.muted,16)+circle(763,20,3,C.orange)+circle(802,29,13,'#e5ecf1')+t(794,33,'CT',9,C.ink,600);
 if(mode==='overview') {
 s+=t(183,89,'Your organization, connected.',23,C.ink,700)+t(184,110,'A clear view of your teams and what comes next.',10,C.muted)+r(705,76,111,29,C.orange,7)+t(720,95,'+  Create event',10,'white',600);
 const stats=[['8','Active teams','Across 5 sports','people'],['124','Athletes','One connected roster','people'],['12','This week','Upcoming events','calendar'],['6','Registrations','Ready to review','file']];
 stats.forEach(([n,label,sub,kind],i)=>{let x=183+i*161;s+=r(x,130,149,98,'white',10,C.line)+r(x+110,144,25,25,'#fff0e5',7)+icon(x+116,150,kind,C.orange,13)+t(x+13,151,label,9,C.muted,550)+t(x+13,181,n,25,C.ink,700)+t(x+13,211,sub,8,C.muted);});
 s+=r(183,245,401,231,'white',10,C.line)+t(198,267,'Coming up next',13,C.ink,650)+t(520,267,'View all →',9,C.orange,600)+line(198,280,569,280);
 [['MON','20','Volleyball practice','Varsity volleyball · School gym','5:00 PM','#e87827'],['TUE','21','Basketball game','JV basketball · Westside court','4:30 PM','#5384d1'],['FRI','24','Football game','Varsity football · Home field','7:00 PM','#9464c7'],['SAT','25','Soccer practice','U14 soccer · Riverside fields','9:00 AM','#329b79']].forEach(([d,date,title,sub,time,col],i)=>{let y=287+i*45;s+=r(198,y,30,35,C.bg,5)+t(205,y+11,d,6,C.muted,600)+t(205,y+27,date,12,C.ink,650)+r(240,y+3,3,27,col,1)+t(252,y+13,title,10,C.ink,600)+t(252,y+28,sub,8,C.muted)+t(523,y+18,time,8,C.muted);});
 s+=r(599,245,217,109,'#15252f',10)+t(614,267,'Team pulse',12,'white',650)+t(614,287,'All your programs. In sync.',8,'#a0b3c0');
 [23,38,32,50,43,58,66,56,78,69,85,93].forEach((h,i)=>{s+=r(615+i*15,334-h*.34,9,h*.34,i>8?C.orange:'#475c6b',3);});
 s+=r(599,368,217,108,'white',10,C.line)+t(614,390,'Quick actions',12,C.ink,650)+icon(615,407,'people',C.orange,14)+t(638,418,'Invite team members',10,C.ink,550)+t(792,418,'›',15,C.muted)+line(614,430,799,430)+icon(615,442,'chat',C.orange,14)+t(638,453,'Send an announcement',10,C.ink,550)+t(792,453,'›',15,C.muted);
 } else {
 s+=t(183,89,'Organization calendar',23,C.ink,700)+t(184,110,'Every team. Every event. One shared view.',10,C.muted)+r(705,76,111,29,C.orange,7)+t(720,95,'+  Create event',10,'white',600);
 ['All teams','Football','Volleyball','Basketball','Soccer'].forEach((label,i)=>{s+=pill(183+i*98,127,90,label,i===0);});
 s+=t(183,181,'April 20–26, 2026',16,C.ink,650)+pill(355,163,51,'Today')+t(425,181,'‹    ›',16,C.muted)+r(670,164,145,25,'#e8edf2',6)+r(672,166,47,21,'white',5)+t(681,180,'Week',9,C.ink,600)+t(727,180,'Month',9,C.muted)+t(775,180,'List',9,C.muted);
 s+=r(183,198,633,278,'white',9,C.line);
 const days=['MON','TUE','WED','THU','FRI','SAT','SUN'];
 days.forEach((d,i)=>{let x=220+i*85;s+=i===1?r(x,199,85,276,'#fff9f4'):'';s+=t(x+31,214,d,7,C.muted,600);s+=i===1?circle(x+42,231,11,C.orange)+t(x+36,235,String(20+i),11,'white',600):t(x+36,235,String(20+i),11,C.ink,600);s+=line(x,247,x,476);});
 ['9 AM','12 PM','3 PM','6 PM'].forEach((time,i)=>{const y=261+i*53;s+=t(188,y,time,6,C.muted)+line(219,y+10,816,y+10);});
 [[0,276,'Soccer','9:00 AM','#e0f3ec','#24785c'],[1,405,'Volleyball','5:00 PM','#fff0df','#b96916'],[2,367,'Basketball','4:30 PM','#e5edfc','#446db0'],[3,333,'Team meeting','2:00 PM','#eee7f8','#7c54ab'],[4,430,'Football','7:00 PM','#ffebe5','#c25a3b'],[5,279,'Soccer','9:00 AM','#e0f3ec','#24785c']].forEach(([i,y,a,b,fill,col])=>{const x=224+Number(i)*85;const yy=Number(y);s+=r(x,yy,77,36,String(fill),4)+r(x,yy+4,2,28,String(col),1)+t(x+7,yy+13,String(a),7,String(col),650)+t(x+7,yy+26,String(b),7,String(col));});
 }
 return s;
}
function laptop(w:number,h:number,mode:'overview'|'calendar',id:string) {
 return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#e1e6ea"/><stop offset=".42" stop-color="#a3aeb7"/><stop offset=".58" stop-color="#dbe2e7"/><stop offset="1" stop-color="#677680"/></linearGradient></defs>`+r(14,0,w-28,h-16,'#26343e',11,'#85929c')+r(17,3,w-34,h-22,'#080e13',9)+`<svg x="23" y="10" width="${w-46}" height="${h-37}" viewBox="0 0 840 500" preserveAspectRatio="none">${desktop(mode)}</svg>`+r(0,h-17,w,12,`url(#${id})`,3)+r(w*.4,h-17,w*.2,3,'#73828d',2);
}
function phoneContent(family:boolean) {
 let s=r(0,0,360,720,C.bg)+t(23,26,'9:41',10,C.ink,650)+t(292,26,'▮▮  ▰',10,C.ink)+r(130,11,100,18,'#10191f',10);
 s+=logo(20,46,31)+t(61,66,'THE BOSS',14,C.ink,750)+r(305,45,34,34,'white',11,C.line)+icon(314,54,'bell',C.ink,17)+circle(330,53,3,C.orange);
 s+=t(21,105,family?'Good afternoon, Taylor':'YOUR TEAM',10,C.muted,500)+t(21,136,family?'Family Hub':'Team schedule',27,C.ink,750)+t(21,156,family?'A little less busy. A lot more together.':'Every practice. Every game. Right here.',10,C.muted);
 s+=r(20,175,320,42,'white',12,C.line)+r(25,180,family?102:91,32,'#192a35',9)+t(39,200,family?'All children':'All events',11,'white',600)+circle(159,196,10,'#fbe5d5')+t(155,200,'E',9,'#b86121',650)+t(175,200,family?'Emma':'Varsity',10,C.muted)+circle(261,196,10,'#e4eafb')+t(257,200,'N',9,'#527ac0',650)+t(276,200,family?'Noah':'JV',10,C.muted);
 s+=t(21,245,'April 20–26',15,C.ink,650)+t(269,244,'‹       ›',17,C.muted);
 ['M','T','W','T','F','S','S'].forEach((d,i)=>{let x=21+i*47;s+=i===1?r(x,259,37,53,C.orange,12):r(x,259,37,53,'white',12,C.line);s+=t(x+14,277,d,8,i===1?'white':C.muted,550)+t(x+11,299,String(20+i),14,i===1?'white':C.ink,650);});
 s+=t(21,341,'UP NEXT',9,C.muted,700)+t(283,341,'4 events',9,C.muted);
 [['20','MON','Volleyball practice','Emma · School team','5:00 PM','School gym','#ec782b','#fff1e7'],['21','TUE','Baseball practice','Noah · Community club','6:00 PM','Riverside','#557dd0','#edf2ff'],['23','THU','Volleyball game','Emma · School team','5:30 PM','Main gym','#ec782b','#fff1e7'],['25','SAT','Baseball game','Noah · Community club','9:00 AM','North field','#557dd0','#edf2ff']].forEach(([date,day,title,sub,time,place,color,fill],i)=>{let y=354+i*69;s+=r(20,y,320,62,'white',11,C.line)+r(28,y+8,39,45,fill,8)+t(36,y+22,day,7,color,650)+t(37,y+42,date,17,color,700)+t(78,y+18,title,12,C.ink,650)+t(78,y+33,sub,9,C.muted)+icon(79,y+42,'pin',C.muted,10)+t(93,y+50,place,8,C.muted)+t(283,y+49,time,8,color,600);});
 s+=r(0,642,360,78,'white')+line(0,642,360,642);
 [['home','Home'],['calendar','Calendar'],['people','Teams'],['chat','Inbox']].forEach(([kind,label],i)=>{let x=38+i*89;s+=i===1?r(x-8,649,38,25,'#fff0e6',10):'';s+=icon(x+2,653,kind,i===1?C.orange:C.muted,18)+t(x+(label==='Calendar'?-6:0),690,label,9,i===1?C.orange:C.muted,i===1?650:450);});
 return s+r(128,707,104,4,'#192630',2);
}
const phone=(w:number,h:number,family:boolean)=>r(0,0,w,h,'#25333e',w*.12,'#8b9aa5')+r(2,2,w-4,h-4,'#0b1219',w*.115)+`<svg x="5" y="5" width="${w-10}" height="${h-10}" viewBox="0 0 360 720" preserveAspectRatio="none" style="overflow:hidden;border-radius:20px">${phoneContent(family)}</svg>`;
function bucks() {
 // Rich, compact discount preview with enough hierarchy to read in the small tile.
 let s=r(0,0,111,81,'#101c25')+`<path d="M0 66 111 19v62H0Z" fill="#20313d"/>`;
 let p=r(0,0,360,680,C.bg)+r(0,0,360,142,'#172630')+logo(22,31,41)+t(76,48,'THE BOSS',16,'white',750)+t(76,69,'BUCKS DISCOUNTS',9,'#b3c3cf',550)+t(22,113,'Save like a Boss.',27,'white',750)+r(20,160,320,45,'white',11,C.line)+icon(32,174,'search',C.muted,17)+t(60,188,'Find your next great deal',12,C.muted)+icon(21,223,'pin',C.orange,15)+t(43,235,'Near you · Emerald Coast',11,C.muted,550);
 p+=r(20,256,320,178,'#ed5b0d',16)+circle(321,297,76,'#f7762b')+t(39,286,'FEATURED SAVINGS',10,'#ffe5d0',650)+t(39,333,'20% OFF',39,'white',750)+t(39,362,'Your next family meal',16,'white',650)+r(39,387,131,27,'#ffffff',13)+t(52,405,'View offer  →',12,'#b74106',650);
 p+=t(22,465,'More ways to save',16,C.ink,700)+t(281,465,'See all',10,C.orange,650);
 [['Dining','Local favorites','#ffecde'],['Shopping','Everyday finds','#e4edf6']].forEach(([a,b,c],i)=>{let x=20+i*166;p+=r(x,483,154,97,'white',13,C.line)+r(x+12,495,29,29,c,9)+icon(x+19,502,i===0?'heart':'grid',C.orange,15)+t(x+12,546,a,12,C.ink,650)+t(x+12,564,b,9,C.muted);});
 p+=r(0,605,360,75,'white')+line(0,605,360,605);[['home','Home'],['grid','Deals'],['pin','Near me'],['heart','Saved']].forEach(([kind,label],i)=>{let x=33+i*88;p+=icon(x+5,619,kind,i===1?C.orange:C.muted,18)+t(x,651,label,9,i===1?C.orange:C.muted);});
 return s+r(34,2,46,79,'#6f7e88',7)+r(35,3,44,77,'#080f15',7)+`<svg x="38" y="7" width="38" height="71" viewBox="0 0 360 680" preserveAspectRatio="none">${p}</svg>`+r(49,5,17,2,'#0a1117',1);
}
export const engagePreviewArt: Record<string,string> = {
 'engage-overview-crisp.svg':`<g transform="translate(5 7)">${laptop(403,265,'overview','engage-metal-overview')}</g><g transform="translate(363 59)">${phone(110,237,false)}</g>`,
 'engage-calendar-crisp.svg':`<g transform="translate(1 6)">${laptop(494,302,'calendar','engage-metal-calendar')}</g>`,
 'engage-family-crisp.svg':`<g transform="translate(2 2)">${phone(186,376,true)}</g>`,
 'engage-bucks-crisp.svg':bucks(),
};
