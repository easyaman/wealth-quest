const { Match, JOBS, rollStart, SLEEP_OPTIONS, FOOD_OPTIONS, CHORES_HOURS, HOURS_PER_MONTH } = require('./engine.js');

console.log('=== งบเวลาต่อเดือน (นอน 7 ชม. + สตรีทฟู้ด) ===');
console.log('อาชีพ                         | งาน | เดินทาง | ว่างดิบ | สุขภาพ | ประสิทธิภาพ | ใช้ได้จริง');
for (const j of JOBS){
  const m = new Match({mode:'solo',seed:1,players:[{name:'x',jobId:j.id,isAI:true}]});
  const p = m.players[0];
  console.log((j.icon+' '+j.name).padEnd(30)+' | '+String(j.work).padStart(3)+' | '+String(j.commute).padStart(7)+
    ' | '+String(720-210-j.work-j.commute-30-CHORES_HOURS).padStart(7)+' | '+String(j.health).padStart(6)+
    ' | '+(0.4+0.6*j.health/100).toFixed(2).padStart(11)+' | '+String(Math.round((720-210-j.work-j.commute-30-CHORES_HOURS)*(0.4+0.6*j.health/100))).padStart(9));
}

console.log('\n=== สมดุล Phase 1 + Phase 2 (250 เกม/อาชีพ) ===');
console.log('อาชีพ                         | T | ออกสนามหนู% | เดือนเฉลี่ย | ทำฝันสำเร็จ% | เดือนฝัน | ล้มละลาย% | สุขภาพเฉลี่ย');
const rows=[];
for (const job of JOBS){
  let esc=[], dr=[], bank=0, hp=[], N=250;
  for (let s=1;s<=N;s++){
    const m = new Match({ mode:'solo', seed:s*7919, players:[{name:'AI', jobId:job.id, isAI:true}] });
    const p = m.players[0];
    if (p.finished) esc.push(p.finished);
    if (p.dreamDone) dr.push(p.dreamDone);
    if (p.bankrupt) bank++;
    hp.push(p.health);
  }
  rows.push({job, esc, dr, bank:bank/N, hp:hp.reduce((a,b)=>a+b,0)/N, N});
}
for (const r of rows){
  const avg = a => a.length? (a.reduce((x,y)=>x+y,0)/a.length).toFixed(1) : '-';
  console.log((r.job.icon+' '+r.job.name).padEnd(30)+' | '+r.job.tier+' | '+
    (r.esc.length/r.N*100).toFixed(0).padStart(11)+' | '+String(avg(r.esc)).padStart(11)+' | '+
    (r.dr.length/r.N*100).toFixed(0).padStart(12)+' | '+String(avg(r.dr)).padStart(8)+' | '+
    (r.bank*100).toFixed(0).padStart(9)+' | '+r.hp.toFixed(0).padStart(12));
}

console.log('\n=== โหมด 4 คนแย่งตลาดเดียวกัน (120 แมตช์) ===');
let win=[], dis={};
for (let s=1;s<=120;s++){
  const jobs = JOBS.slice().sort(()=>Math.random()-0.5).slice(0,4);
  const m = new Match({mode:'multi', seed:s*104729, players: jobs.map((j,i)=>({name:'P'+i, jobId:j.id, isAI:true}))});
  const w = m.standings()[0];
  if (w.dreamDone) win.push(w.dreamDone);
  m.disasterHistory.forEach(d=>dis[d.name]=(dis[d.name]||0)+1);
}
win.sort((a,b)=>a-b);
console.log('ผู้ชนะ (ทำความฝันสำเร็จ) ใช้เวลาเฉลี่ย '+(win.reduce((a,b)=>a+b,0)/win.length).toFixed(1)+' เดือน | กลาง '+win[Math.floor(win.length/2)]+' | เร็วสุด '+win[0]+' | ช้าสุด '+win[win.length-1]);
console.log('ภัยพิบัติที่เกิด:', Object.entries(dis).sort((a,b)=>b[1]-a[1]).map(([k,v])=>k+' '+v).join(' | '));
