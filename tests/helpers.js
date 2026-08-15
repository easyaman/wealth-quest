/* =========================================================
   ตัวช่วยสำหรับชุดทดสอบ — รันเกมแบบกำหนด seed ได้ผลเดิมทุกครั้ง
   ห้ามใช้ Math.random() ที่ไหนในไฟล์นี้ ไม่งั้นเทสต์จะ flaky
   ========================================================= */
const E = require('../engine.js');

/** รันเกมเดี่ยว (บอทล้วน) จนจบ แล้วคืนผู้เล่นกับแมตช์ */
function runSolo(jobId, seed) {
  const m = new E.Match({ mode: 'solo', seed, players: [{ name: 'AI', jobId, isAI: true }] });
  return { match: m, player: m.players[0] };
}

/** รันแมตช์หลายคน (บอทล้วน) — เลือกอาชีพแบบกำหนดได้ ไม่สุ่มจาก Math.random */
function runMulti(jobIds, seed) {
  const m = new E.Match({
    mode: 'multi', seed,
    players: jobIds.map((jobId, i) => ({ name: 'P' + i, jobId, isAI: true }))
  });
  return m;
}

/** สถิติรวมของอาชีพหนึ่ง จาก n เกม (seed เรียงแบบกำหนดตายตัว) */
function statsFor(jobId, n) {
  const escapes = [], dreams = [];
  let bankrupt = 0, healthSum = 0;
  for (let s = 1; s <= n; s++) {
    const { player } = runSolo(jobId, s * 7919);
    if (player.finished) escapes.push(player.finished);
    if (player.dreamDone) dreams.push(player.dreamDone);
    if (player.bankrupt) bankrupt++;
    healthSum += player.health;
  }
  return {
    n,
    escapePct: escapes.length / n * 100,
    escapeAvg: mean(escapes),
    dreamPct: dreams.length / n * 100,
    dreamAvg: mean(dreams),
    bankruptPct: bankrupt / n * 100,
    healthAvg: healthSum / n
  };
}

const mean = a => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0);

function median(a) {
  if (!a.length) return 0;
  const s = a.slice().sort((x, y) => x - y);
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** เดินไปทุกค่าตัวเลขในโครงสร้าง แล้วเรียก fn(path, value) — ใช้ล่า NaN/Infinity */
function walkNumbers(obj, fn, path = '', seen = new Set()) {
  if (obj === null || typeof obj !== 'object') return;
  if (seen.has(obj)) return;
  seen.add(obj);
  for (const [k, v] of Object.entries(obj)) {
    const p = path ? path + '.' + k : k;
    if (typeof v === 'number') fn(p, v);
    else if (typeof v === 'object') walkNumbers(v, fn, p, seen);
  }
}

module.exports = { E, runSolo, runMulti, statsFor, mean, median, walkNumbers };
