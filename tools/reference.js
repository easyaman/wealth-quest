#!/usr/bin/env node
/* =========================================================
   สร้างตัวเลขอ้างอิงสำหรับเอกสาร — ต้องได้ผลเดิมทุกครั้งที่รัน
   ต่างจาก sim.js เดิมตรงที่ไม่ใช้ Math.random() เลย
   (ของเดิมสุ่มอาชีพในโหมด 4 คนด้วย Math.random ทำให้ตัวเลขในเอกสารซ้ำไม่ได้)

   ใช้:  node tools/reference.js            → รายงานอ่านคน
         node tools/reference.js --json     → JSON สำหรับเครื่องอ่าน
   ========================================================= */
const E = require('../engine.js');
const { JOBS, Match, CHORES_HOURS, SLEEP_OPTIONS, FOOD_OPTIONS } = E;

const GAMES_PER_JOB = 250;
const MULTI_MATCHES = 120;

const mean = a => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0);
const median = a => {
  if (!a.length) return 0;
  const s = a.slice().sort((x, y) => x - y), m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/* ---------- งบเวลาต่อเดือน (ใช้เกณฑ์การนอนของอาชีพนั้นจริงๆ) ---------- */
function timeBudget(job) {
  // ต้องเป็นผู้เล่นคนจริง ไม่งั้น constructor จะให้บอทเล่นจนจบเกมทันที
  // แล้วเราจะได้ตัวเลขของคนที่เกษียณไปแล้ว (เดือน 1 เท่านั้นที่ตรงกับเอกสาร)
  const m = new Match({ mode: 'solo', seed: 1, players: [{ name: 'x', jobId: job.id, isAI: false }] });
  const p = m.players[0];
  if (m.month !== 1) throw new Error('คาดว่าจะหยุดที่เดือน 1 แต่ได้เดือน ' + m.month);
  // ตั้งค่าให้ตรงกับสมมติฐานของเอกสาร: นอนตามเกณฑ์อาชีพ + สตรีทฟู้ด
  p.sleepIdx = SLEEP_OPTIONS.findIndex(s => s.h === (job.sleepNeed || 7));
  p.foodId = 'street';
  return {
    id: job.id, name: job.name, icon: job.icon, tier: job.tier,
    work: job.work, commute: job.commute, sleepNeed: job.sleepNeed || 7,
    rawFree: p.rawFreeHours,
    efficiency: p.efficiency,
    usable: p.hoursMax
  };
}

/* ---------- สมดุลรายอาชีพ ---------- */
function jobBalance(job, n) {
  const esc = [], dr = [];
  let bank = 0, hp = 0;
  for (let s = 1; s <= n; s++) {
    const m = new Match({ mode: 'solo', seed: s * 7919, players: [{ name: 'AI', jobId: job.id, isAI: true }] });
    const p = m.players[0];
    if (p.finished) esc.push(p.finished);
    if (p.dreamDone) dr.push(p.dreamDone);
    if (p.bankrupt) bank++;
    hp += p.health;
  }
  return {
    id: job.id, name: job.name, icon: job.icon, tier: job.tier,
    escapePct: esc.length / n * 100, escapeAvg: mean(esc),
    dreamPct: dr.length / n * 100, dreamAvg: mean(dr), dreamMedian: median(dr),
    bankruptPct: bank / n * 100, healthAvg: hp / n
  };
}

/* ---------- โหมด 4 คนแย่งตลาดเดียวกัน (เลือกอาชีพแบบกำหนดตายตัว) ---------- */
/** สลับอาชีพแบบสุ่มที่ทำซ้ำได้ — ใช้ตัวสุ่มของเกมเอง ไม่ใช่ Math.random
    (สูตรโมดูโลแบบง่ายให้ชุดอาชีพซ้ำกันไม่กี่ชุด ทำให้ตัวอย่างไม่กระจาย) */
function pickJobs(seed, count) {
  const r = E.makeRng(seed);
  const pool = JOBS.slice();
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, count).map(j => j.id);
}

function multiBalance(n) {
  const winners = [], disasters = {};
  let noWinner = 0;
  for (let s = 1; s <= n; s++) {
    const jobs = pickJobs(s * 6151, 4);
    const m = new Match({ mode: 'multi', seed: s * 104729, players: jobs.map((j, i) => ({ name: 'P' + i, jobId: j, isAI: true })) });
    const w = m.standings()[0];
    if (w.dreamDone) winners.push(w.dreamDone); else noWinner++;
    m.disasterHistory.forEach(d => { disasters[d.name] = (disasters[d.name] || 0) + 1; });
  }
  return {
    matches: n, noWinner,
    avg: mean(winners), median: median(winners),
    fastest: Math.min(...winners), slowest: Math.max(...winners),
    disasters
  };
}

const report = {
  generatedBy: 'tools/reference.js',
  gamesPerJob: GAMES_PER_JOB,
  multiMatches: MULTI_MATCHES,
  timeBudget: JOBS.map(timeBudget),
  jobs: JOBS.map(j => jobBalance(j, GAMES_PER_JOB)),
  multi: multiBalance(MULTI_MATCHES)
};

if (process.argv.includes('--json')) {
  console.log(JSON.stringify(report, null, 2));
} else {
  const pad = (s, n) => String(s).padEnd(n);
  const num = (v, n, d = 1) => (typeof v === 'number' ? v.toFixed(d) : v).padStart(n);

  console.log('=== งบเวลาต่อเดือน (นอนตามเกณฑ์อาชีพ + สตรีทฟู้ด) ===');
  console.log(pad('อาชีพ', 26) + '| งาน | เดินทาง | ต้องนอน | ว่างดิบ | ประสิทธิภาพ | ใช้ได้จริง');
  for (const t of report.timeBudget) {
    console.log(pad(t.icon + ' ' + t.name, 26) + '|' + num(t.work, 5, 0) + '|' + num(t.commute, 9, 0) +
      '|' + num(t.sleepNeed, 9, 0) + '|' + num(t.rawFree, 9, 0) + '|' + num(t.efficiency * 100, 12, 0) + '%|' + num(t.usable, 10, 0));
  }

  console.log('\n=== สมดุลด่าน 1 + ด่าน 2 (' + GAMES_PER_JOB + ' เกม/อาชีพ) ===');
  console.log(pad('อาชีพ', 26) + '| T | ออกสนามหนู% | เดือนเฉลี่ย | ทำฝัน% | เดือนฝัน | ล้มละลาย% | สุขภาพ');
  for (const r of report.jobs) {
    console.log(pad(r.icon + ' ' + r.name, 26) + '|' + num(r.tier, 3, 0) + '|' + num(r.escapePct, 13, 0) +
      '|' + num(r.escapeAvg, 13) + '|' + num(r.dreamPct, 8, 0) + '|' + num(r.dreamAvg, 10) +
      '|' + num(r.bankruptPct, 11, 0) + '|' + num(r.healthAvg, 8, 0));
  }

  const m = report.multi;
  console.log('\n=== โหมด 4 คนแย่งตลาดเดียวกัน (' + m.matches + ' แมตช์) ===');
  console.log(`ผู้ชนะคนแรกใช้เวลา — เฉลี่ย ${m.avg.toFixed(1)} เดือน | มัธยฐาน ${m.median} | เร็วสุด ${m.fastest} | ช้าสุด ${m.slowest}`);
  console.log(`แมตช์ที่ไม่มีใครทำความฝันสำเร็จเลย: ${m.noWinner}/${m.matches}`);
  console.log('ภัยพิบัติที่เกิด: ' + Object.entries(m.disasters).sort((a, b) => b[1] - a[1]).map(([k, v]) => k + ' ' + v).join(' | '));
}
