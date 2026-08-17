#!/usr/bin/env node
/* =========================================================
   ดัมพ์สถานะรายเดือนของเกมเดียวจากเอนจิน JS — คู่กับ godot/sim/trace_dump.gd
   ใช้หาว่าพอร์ต GDScript เริ่มต่างจากต้นฉบับที่เดือนไหน

   ใช้:  node tools/trace_dump.js <job_id> <seed_index>
   ========================================================= */
const E = require('../engine.js');
const { Match, Player } = E;

const jobId = process.argv[2] || 'cleaner';
const s = parseInt(process.argv[3] || '1', 10);

/* ถ่ายภาพที่ refillMarket เพราะเป็นจุดสุดท้ายของ endMonth ที่ยังไม่ recurse เข้าเดือนถัดไป
   (ถ้าไป wrap endMonth ตรงๆ จะได้ภาพตอนคลาย stack = สถานะสุดท้ายของเกมทุกบรรทัด)
   ตรงกับจุดที่ match.gd ยิงสัญญาณ month_ended พอดี — ครั้งแรกคือตอน constructor จึงข้าม */
let i = 0;
let skippedSetup = false;
const origEnd = Match.prototype.refillMarket;
Match.prototype.refillMarket = function () {
  const out = origEnd.call(this);
  if (!skippedSetup) { skippedSetup = true; return out; }
  const p = this.players[0];
  console.log(`T ${i} rng=${this.rng.s} cash=${Math.round(p.cash)} hp=${p.health.toFixed(1)} ` +
    `hmax=${p.hoursMax} place=${p.place} veh=${p.vehicle} dev=${p.devices.slice().sort().join('|')} ` +
    `assets=${p.assets.length} nw=${Math.round(p.netWorth)} debt=${Math.round(p.totalDebt)} ` +
    `sp=${p.studyProgress.toFixed(2)} sal=${Math.round(p.salary)} mi=${this.marketIndex.toFixed(4)} ` +
    `deals=${this.deals.length}`);
  i++;
  return out;
};

/* ป้ายกำกับของแต่ละตัวเลือก — อ่านจากซอร์สของ arrow function ที่ aiBestMove สร้างไว้
   (V8 คืนซอร์สจริงจาก toString) เพื่อให้เทียบกับ tag ฝั่ง GDScript ได้บรรทัดต่อบรรทัด */
function tagOf(run) {
  const src = run.toString();
  if (src.includes('sellAsset')) return 'sell';
  if (src.includes('closeDeal')) return 'deal';
  if (src.includes('exercise')) return 'gym';
  if (src.includes('vacation')) return 'vacation';
  if (src.includes('this.rest')) return 'rest';
  if (src.includes('study')) return 'study';
  if (src.includes("sideJob('ot')")) return 'ot';
  if (src.includes('sideJob')) return 'freelance';
  if (src.includes('scout')) return 'scout';
  if (src.includes('aiShop')) return 'shop';
  return '?';
}

if (process.env.WQ_TRACE_AI) {
  const origBest = Player.prototype.aiBestMove;
  Player.prototype.aiBestMove = function () {
    for (const d of this.match.deals) {
      const price = this.job.perkId === 'discount' ? d.price * 0.9 : d.price;
      const down = price * (d.down / d.price), debt = price - down;
      const cf = d.income * (price / d.price) - debt * E.MORTGAGE;
      const roi = d.kind === 'speculation' ? 0.022 : cf / Math.max(1, down);
      console.log(`  D id=${d.id} kind=${d.kind} price=${Math.round(price)} down=${Math.round(down)} ` +
        `cf=${cf.toFixed(1)} roi=${roi.toFixed(4)} cash=${Math.round(this.cash)} ` +
        `exp=${this.totalExpenses.toFixed(1)} cl=${this.creditLeft.toFixed(1)}`);
    }
    const best = origBest.call(this);
    console.log(`A m=${this.match.month} h=${this.hours} cash=${Math.round(this.cash)} ` +
      `hp=${this.health.toFixed(1)} -> ` +
      (best ? `${tagOf(best.run)}@${best.place} tr=${best.travel} sc=${best.score.toFixed(4)}` : 'none'));
    return best;
  };
}

new Match({ mode: 'solo', seed: s * 7919, players: [{ name: 'AI', jobId, isAI: true }] });
