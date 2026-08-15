const E = require('./engine.js');
const { Match, JOBS, DREAMS, DISASTERS, EVENTS, EVENTS2, SLEEP_OPTIONS, FOOD_OPTIONS, COST,
        ROLL_TABLE, HOURS_PER_MONTH, CHORES_HOURS, MORTGAGE, fmt } = E;

/* ---------- รัน simulation เพื่อดึงตัวเลขสมดุลจริง ---------- */
const N = 150;
const bal = JOBS.map(job => {
  let esc=[], dr=[], bank=0, hp=[];
  for (let s=1;s<=N;s++){
    const m = new Match({mode:'solo',seed:s*7919,players:[{name:'AI',jobId:job.id,isAI:true}]});
    const p = m.players[0];
    if(p.finished) esc.push(p.finished);
    if(p.dreamDone) dr.push(p.dreamDone);
    if(p.bankrupt) bank++;
    hp.push(p.health);
  }
  const avg = a => a.length ? (a.reduce((x,y)=>x+y,0)/a.length) : null;
  return { job, escPct: esc.length/N*100, escAvg: avg(esc), drPct: dr.length/N*100,
           drAvg: avg(dr), bank: bank/N*100, hp: hp.reduce((a,b)=>a+b,0)/N };
});

const freeHours = j => {
  const sleep=(j.sleepNeed||7)*30;
  const raw = HOURS_PER_MONTH - sleep - j.work - j.commute - 30 - CHORES_HOURS;
  return { raw, eff: 0.40+0.60*j.health/100, usable: Math.round(raw*(0.40+0.60*j.health/100)) };
};
const TIER = {1:'รายได้น้อย',2:'มนุษย์เงินเดือน',3:'ชนชั้นกลางบน',4:'รายได้สูง'};
const PERK = {frugal:'ประหยัด',hustle:'ขยัน',quick:'ว่องไว',stable:'มั่นคง',discount:'ต่อรอง',credit:'เครดิตดี',insight:'อ่านตลาด',none:'—'};

const jobRows = JOBS.map(j=>{
  const f=freeHours(j), pay=j.debts.reduce((s,d)=>s+d.balance*d.rate,0);
  const exp=j.fixed+j.food+pay, save=j.salary-exp;
  return `| ${j.icon} ${j.name} | ${j.tier} | ${fmt(j.salary)} | ${fmt(j.fixed)} | ${fmt(j.food)} | ${fmt(j.debts.reduce((s,d)=>s+d.balance,0))} | ${(exp/save).toFixed(2)} | ${j.work} | ${j.commute} | ${j.sleepNeed} | ${j.health} | **${f.usable}** | ${PERK[j.perkId]} |`;
}).join('\n');

const balRows = bal.slice().sort((a,b)=>(a.drAvg||999)-(b.drAvg||999)).map(r=>
  `| ${r.job.icon} ${r.job.name} | ${r.job.tier} | ${r.escPct.toFixed(0)}% | ${r.escAvg?r.escAvg.toFixed(1):'—'} | ${r.drPct.toFixed(0)}% | ${r.drAvg?r.drAvg.toFixed(1):'—'} | ${r.bank.toFixed(0)}% | ${r.hp.toFixed(0)} |`).join('\n');

const dealRows = [
  ...E.DEAL_POOL ? [] : []
];
const poolSrc = require('fs').readFileSync('./engine.js','utf8');
function poolTable(name){
  // ดึงจากไฟล์เพื่อความแม่นยำ
  return null;
}

const sleepRows = SLEEP_OPTIONS.map(o=>
  `| ${o.h} ชม./คืน | ${o.hours} | ${o.health>0?'+':''}${o.health} | ${o.penalty?('−'+(o.penalty*100).toFixed(0)+'%'):'—'} | ${o.note} |`).join('\n');
const foodRows = FOOD_OPTIONS.map(o=>
  `| ${o.icon} ${o.label} | ${o.hours} | ×${o.costMul.toFixed(2)} | ${o.health>0?'+':''}${o.health} | ${o.note} |`).join('\n');
const costRows = Object.entries(COST).map(([k,v])=>`| \`${k}\` | ${v} ชม. | ${E.ACTION_INFO[k]} |`).join('\n');
const rollRows = Object.entries(ROLL_TABLE).map(([k,v])=>
  `| ${k} | ${v.count} | ${v.tiers.join(', ')} | +${v.bonusHours} ชม. | ${v.label} |`).join('\n');
const dreamRows = DREAMS.map(d=>
  `| ${d.roll} | ${d.icon} ${d.name} | ×${d.costMul} | ×${d.passiveMul.toFixed(2)} | ${d.why} |`).join('\n');
const disRows = DISASTERS.map(d=>{
  const m=d.mods||{};
  const eff=[
    m.business?`รายได้ธุรกิจ ×${m.business}`:null,
    m.realestate?`รายได้อสังหาฯ ×${m.realestate}`:null,
    m.rate?`ดอกเบี้ยทุกก้อน ×${m.rate}`:null,
    m.credit?`วงเงินสินเชื่อ ×${m.credit}`:null,
    d.market?`ดัชนีตลาด ${(d.market*100).toFixed(0)}%`:null,
    d.inflate?`รายจ่ายประจำ +${(d.inflate*100).toFixed(0)}% ถาวร`:null,
    d.burnAsset?'ธุรกิจ 1 อย่างถูกไฟไหม้ (50%)':null,
    d.hp?`สุขภาพ ${d.hp}`:null,
    d.cashCostMul?`จ่ายเงินก้อน ${d.cashCostMul[0]}–${d.cashCostMul[1]}× รายจ่าย`:null
  ].filter(Boolean).join(' · ');
  return `| ${d.icon} ${d.name} | ${d.dur} | ${eff} |`;
}).join('\n');
const evRows = EVENTS.map(e=>{
  const w=e.w, kind = e.health?'สุขภาพ':(e.raise?'บวก':(e.gainMul?'บวก':(e.market?'ตลาด':'ลบ')));
  const detail=[
    e.costMul?`จ่าย ${e.costMul[0]}–${e.costMul[1]}× ฐาน`:null,
    e.gainMul?`ได้ ${e.gainMul[0]}–${e.gainMul[1]}× ฐาน`:null,
    e.raise?`เงินเดือน +${(e.raise[0]*100).toFixed(0)}–${(e.raise[1]*100).toFixed(0)}% (รายจ่าย +55% ของอัตรานั้น)`:null,
    e.market?`ตลาด ${(e.market[0]*100).toFixed(0)}%..${(e.market[1]*100).toFixed(0)}%`:null,
    e.childMul?`รายจ่ายถาวร +${(e.childMul[0]*100).toFixed(0)}–${(e.childMul[1]*100).toFixed(0)}%`:null,
    e.childHours?`เวลา −${e.childHours} ชม./เดือน ถาวร`:null,
    e.downsize?`ขาดเงินเดือน ${e.downsize} เดือน`:null,
    e.hpCost?`สุขภาพ −${e.hpCost}`:null,
    e.timeCost?`เวลาเดือนหน้า −${e.timeCost} ชม.`:null
  ].filter(Boolean).join(' · ');
  return `| ${e.text} | ${w} | ${kind} | ${detail} |`;
}).join('\n');
const ev2Rows = EVENTS2.map(e=>{
  const detail=[
    e.costMul?`จ่าย ${e.costMul[0]}–${e.costMul[1]}× รายจ่าย`:null,
    e.gainMul?`ได้ ${e.gainMul[0]}–${e.gainMul[1]}× รายจ่าย`:null,
    e.market?`ตลาด ${(e.market[0]*100).toFixed(0)}%..${(e.market[1]*100).toFixed(0)}%`:null,
    e.childMul?`รายจ่ายถาวร +${(e.childMul[0]*100).toFixed(0)}–${(e.childMul[1]*100).toFixed(0)}%`:null,
    e.bonusDeals?`ดีลพิเศษ +${e.bonusDeals}`:null,
    e.hpCost?`สุขภาพ −${e.hpCost}`:null
  ].filter(Boolean).join(' · ');
  return `| ${e.text} | ${e.w} | ${detail} |`;
}).join('\n');

/* ตารางประเภทดีลอ่านจาก engine โดยตรง */
const DP = eval(poolSrc.match(/const DEAL_POOL = (\[[\s\S]*?\n\];)/)[1].replace(/;$/,''));
const BD = eval(poolSrc.match(/const BIG_DEALS = (\[[\s\S]*?\n\];)/)[1].replace(/;$/,''));
const MD = eval(poolSrc.match(/const MEGA_DEALS = (\[[\s\S]*?\n\];)/)[1].replace(/;$/,''));
const KL = {micro:'ธุรกิจจิ๋ว',business:'ธุรกิจ',realestate:'อสังหาฯ',speculation:'เก็งกำไร',fund:'กองทุน/ตราสาร'};
const dpRows = DP.map(t=>
  `| ${t.icon} ${KL[t.kind]} | ${fmt(t.min)}–${fmt(t.max)} | ${t.downPct[0]===1?'จ่ายสด':(Math.round(t.downPct[0]*100)+'–'+Math.round(t.downPct[1]*100)+'%')} | ${(t.yield[0]*100).toFixed(2)}–${(t.yield[1]*100).toFixed(2)}% | ${(t.vol*100).toFixed(0)}% | ${t.w} |`).join('\n');
const bdRows = BD.map(t=>
  `| ${t.icon} ${KL[t.kind]} (ใหญ่) | ${fmt(t.min)}–${fmt(t.max)} | ${t.downPct[0]===1?'จ่ายสด':(Math.round(t.downPct[0]*100)+'–'+Math.round(t.downPct[1]*100)+'%')} | ${(t.yield[0]*100).toFixed(2)}–${(t.yield[1]*100).toFixed(2)}% | ${(t.vol*100).toFixed(0)}% | — |`).join('\n');
const mdRows = MD.map(t=>
  `| ${t.icon} ${KL[t.kind]} (เมกะ) | สเกลตามความมั่งคั่ง ×0.15–0.65 | ${t.downPct[0]===1?'จ่ายสด':(Math.round(t.downPct[0]*100)+'–'+Math.round(t.downPct[1]*100)+'%')} | ${(t.yield[0]*100).toFixed(2)}–${(t.yield[1]*100).toFixed(2)}% | ${(t.vol*100).toFixed(0)}% | — |`).join('\n');

/* ---------- ข้อ 3A: แผนที่และการเดินทาง ----------
   บทนี้เคยหายไปจากตัวสร้างเอกสาร ทำให้การรัน `node writegdd.js` ลบทั้งบททิ้ง
   ทั้งที่ข้อมูลทุกตารางอยู่ใน engine.js ครบอยู่แล้ว */
const placeRows = E.PLACES.map(p =>
  `| ${p.icon} ${p.name} | ${p.x} | ${p.desc} |`).join('\n');

const vehicleRows = E.VEHICLES.map(v =>
  `| ${v.icon} ${v.name} | ${fmt(v.price)} | ${Math.round(v.downPct * 100)}% | ${fmt(v.upkeep)} | ×${v.factor.toFixed(2)} | ${v.note} |`).join('\n');

const deviceRows = E.DEVICES.map(d =>
  `| ${d.icon} ${d.name} | ${fmt(d.price)} | ${fmt(d.upkeep)} | ${d.note} |`).join('\n');

const gymRows = E.GYM_PACKS.map(g =>
  `| ${g.icon} ${g.name} | ${fmt(g.cost)} | ${g.hours} | +${g.hp} | ${g.monthly ? 'รายเดือน' : 'รายครั้ง'} |`).join('\n');

const resortRows = E.RESORT_PACKS.map(r =>
  `| ${r.icon} ${r.name} | ${fmt(r.cost)} | ${r.hours} | +${r.hp} | ${Math.round((r.shield || 0) * 100)}% |`).join('\n');

/* ตัวอย่าง "ซื้อเวลาด้วยเงิน" — เลือกอาชีพที่เดินทางนานที่สุดมาคำนวณจริง ไม่ใช่เขียนตัวเลขค้างไว้ */
const commuteHog = JOBS.slice().sort((a, b) => b.commute - a.commute)[0];
const usedcar = E.VEHICLES.find(v => v.id === 'usedcar');
const afterCommute = Math.round(commuteHog.commute * usedcar.factor);
const vehicleExample =
  `${commuteHog.name} (commute ${commuteHog.commute} ชม.) ซื้อ${usedcar.name} → เหลือ ${afterCommute} ชม. = ` +
  `**ได้เวลาคืน ${commuteHog.commute - afterCommute} ชม./เดือน**`;

const newcar = E.VEHICLES.find(v => v.id === 'newcar');
const luxury = E.VEHICLES.find(v => v.id === 'luxury');
const luxuryTrap =
  `เร็วกว่ารถใหม่แค่ ${Math.round((1 - luxury.factor / newcar.factor) * 100)}% ` +
  `แต่แพงกว่า ${(luxury.price / newcar.price).toFixed(1)} เท่า`;

/* ---------- โหมด 4 คน — ต้องวัดจริง ไม่ใช่เขียนตัวเลขไว้ในเอกสารเฉยๆ ----------
   เดิมเอกสารเขียน "~42 เดือน" ไว้ตายตัวโดยไม่เคยวัด ค่าจริงห่างจากนั้นพอสมควร
   สลับอาชีพด้วยตัวสุ่มที่ทำซ้ำได้ ไม่ใช่ Math.random เพื่อให้เอกสารสร้างซ้ำได้เหมือนเดิมทุกครั้ง */
const MULTI_N = 120;
function pickJobs(seed, count) {
  const r = E.makeRng(seed), pool = JOBS.slice();
  for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
  return pool.slice(0, count).map(j => j.id);
}
const multiWins = [];
for (let s = 1; s <= MULTI_N; s++) {
  const m = new Match({ mode: 'multi', seed: s * 104729,
    players: pickJobs(s * 6151, 4).map((j, i) => ({ name: 'P' + i, jobId: j, isAI: true })) });
  const w = m.standings()[0];
  if (w.dreamDone) multiWins.push(w.dreamDone);
}
multiWins.sort((a, b) => a - b);
const multi = {
  n: MULTI_N,
  median: multiWins.length % 2 ? multiWins[multiWins.length >> 1]
    : (multiWins[(multiWins.length >> 1) - 1] + multiWins[multiWins.length >> 1]) / 2,
  avg: multiWins.reduce((a, b) => a + b, 0) / multiWins.length,
  fastest: multiWins[0], slowest: multiWins[multiWins.length - 1]
};

module.exports = { jobRows, balRows, sleepRows, foodRows, costRows, rollRows, dreamRows, disRows, evRows, ev2Rows, dpRows, bdRows, mdRows, bal, multi,
  placeRows, vehicleRows, deviceRows, gymRows, resortRows, vehicleExample, luxuryTrap };
