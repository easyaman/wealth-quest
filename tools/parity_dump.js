#!/usr/bin/env node
/* =========================================================
   ดัมพ์ผลรายเมล็ดสุ่มจากเอนจิน JS เพื่อเทียบกับพอร์ต GDScript ทีละเกม
   ใช้เมล็ดชุดเดียวกับ tools/reference.js และ sim/headless_sim.gd (s * 7919)

   ใช้:  node tools/parity_dump.js [จำนวนเกม/อาชีพ] > out.json
   ========================================================= */
const E = require('../engine.js');
const { JOBS, Match } = E;

const RUNS = parseInt(process.argv[2] || '60', 10);

const out = {};
for (const job of JOBS) {
  const rows = [];
  for (let s = 1; s <= RUNS; s++) {
    const m = new Match({ mode: 'solo', seed: s * 7919, players: [{ name: 'AI', jobId: job.id, isAI: true }] });
    const p = m.players[0];
    rows.push([s, p.finished | 0, p.dreamDone | 0, p.bankrupt ? 1 : 0, m.month,
      Math.round(p.health), Math.round(p.netWorth), p.assets.length, p.vehicle,
      p.devices.slice().sort().join('|'), p.studyLevel]);
  }
  out[job.id] = rows;
}
console.log(JSON.stringify(out));
