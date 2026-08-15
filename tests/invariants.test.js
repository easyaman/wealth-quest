/* =========================================================
   กฎที่ต้องจริงเสมอ ไม่ว่าเกมจะเดินไปทางไหน
   เทสต์ชุดนี้กวาดหลายร้อยเกมเพื่อหา NaN / ค่าหลุดช่วง / เกมที่ไม่ยอมจบ
   ถ้าชุดนี้แดง แปลว่ามีเคสที่ผู้เล่นจริงจะเจอจอพัง
   ========================================================= */
const { test } = require('node:test');
const assert = require('node:assert');
const { E, runSolo, runMulti, walkNumbers } = require('./helpers.js');

const JOB_IDS = E.JOBS.map(j => j.id);
const GAMES_PER_JOB = 30;

/** ตรวจผู้เล่นหนึ่งคนว่าตัวเลขทุกช่องยังสมเหตุสมผล */
function checkPlayer(p, where) {
  const nums = { cash: p.cash, health: p.health, salary: p.salary,
    fixedExpenses: p.fixedExpenses, foodBase: p.foodBase, hours: p.hours,
    netWorth: p.netWorth, passiveIncome: p.passiveIncome, totalExpenses: p.totalExpenses };
  for (const [k, v] of Object.entries(nums)) {
    assert.ok(Number.isFinite(v), `${where}: ${k} ไม่ใช่ตัวเลขจำกัด (${v})`);
  }
  assert.ok(p.health >= 0 && p.health <= 100, `${where}: สุขภาพหลุดช่วง 0–100 (${p.health})`);
  assert.ok(p.hours >= 0, `${where}: ชั่วโมงติดลบ (${p.hours})`);
  assert.ok(p.phase >= 1 && p.phase <= 3, `${where}: phase ผิด (${p.phase})`);
  assert.ok(Array.isArray(p.assets) && Array.isArray(p.liabilities), `${where}: โครงสร้างทรัพย์สิน/หนี้สินพัง`);
  for (const l of p.liabilities) {
    assert.ok(Number.isFinite(l.balance), `${where}: ยอดหนี้ไม่ใช่ตัวเลข`);
    assert.ok(l.balance >= 0, `${where}: ยอดหนี้ติดลบ (${l.balance}) — แปลว่าจ่ายเกินแล้วไม่ปัดทิ้ง`);
    assert.ok(Number.isFinite(l.rate) && l.rate >= 0, `${where}: ดอกเบี้ยผิดรูป`);
  }
  for (const a of p.assets) {
    assert.ok(Number.isFinite(a.value) && a.value > 0, `${where}: มูลค่าทรัพย์สินผิด (${a.value})`);
    assert.ok(Number.isFinite(p.assetPrice(a)), `${where}: ราคาตลาดของทรัพย์สินเป็น NaN`);
  }
}

test('เกมเดี่ยวทุกอาชีพจบเสมอ และตัวเลขไม่พังระหว่างทาง', () => {
  for (const jobId of JOB_IDS) {
    for (let s = 1; s <= GAMES_PER_JOB; s++) {
      const { match, player } = runSolo(jobId, s * 104729);
      const where = `${jobId} seed ${s}`;
      assert.strictEqual(match.state, 'over', `${where}: เกมไม่จบ (state=${match.state})`);
      assert.ok(match.month <= 600, `${where}: เกินเพดาน 600 เดือน`);
      assert.ok(match.month >= 1, `${where}: เดือนผิด`);
      checkPlayer(player, where);
      // ต้องจบด้วยทางใดทางหนึ่งเสมอ ไม่ใช่ค้างกลางอากาศ
      assert.ok(player.bankrupt || player.dreamDone || match.month >= 600,
        `${where}: เกมจบแต่ไม่ล้มละลาย ไม่สำเร็จ และไม่ชนเพดาน`);
    }
  }
});

test('ไม่มี NaN หรือ Infinity โผล่ในไฟล์เซฟของเกมที่เล่นจบแล้ว', () => {
  for (const jobId of JOB_IDS) {
    for (let s = 1; s <= 10; s++) {
      const { match } = runSolo(jobId, s * 7919);
      const bad = [];
      walkNumbers(match.serialize(), (path, v) => {
        if (!Number.isFinite(v)) bad.push(`${path}=${v}`);
      });
      assert.deepStrictEqual(bad, [], `${jobId} seed ${s}: พบค่าพัง — ${bad.join(', ')}`);
    }
  }
});

test('แมตช์หลายคนที่แย่งตลาดเดียวกันก็จบและไม่พัง', () => {
  for (let s = 1; s <= 40; s++) {
    // เลือกอาชีพแบบหมุนวน ไม่ใช้ Math.random เพื่อให้ผลซ้ำได้
    const jobs = [0, 1, 2, 3].map(i => JOB_IDS[(s + i * 4) % JOB_IDS.length]);
    const m = runMulti(jobs, s * 104729);
    assert.strictEqual(m.state, 'over', `แมตช์ seed ${s} ไม่จบ`);
    m.players.forEach((p, i) => checkPlayer(p, `multi seed ${s} p${i}`));
    assert.strictEqual(m.standings().length, 4, 'ตารางอันดับต้องมีครบทุกคน');
  }
});

test('ตลาดกลางมีดีลตามจำนวนที่กำหนด และการันตีดีลที่คนจนที่สุดเอื้อมถึง', () => {
  for (let s = 1; s <= 30; s++) {
    const m = new E.Match({
      mode: 'multi', seed: s * 31,
      players: [
        { name: 'จน', jobId: 'cleaner', isAI: false },
        { name: 'รวย', jobId: 'pilot', isAI: true }
      ]
    });
    assert.ok(m.deals.length >= 4, `seed ${s}: ดีลในตลาดน้อยเกินไป (${m.deals.length})`);
    const poorest = m.players.reduce((a, b) => (a.cash < b.cash ? a : b));
    const reachable = m.deals.filter(d => d.down <= poorest.cash).length;
    assert.ok(reachable >= 2,
      `seed ${s}: คนจนที่สุด (เงินสด ${poorest.cash}) เอื้อมถึงแค่ ${reachable} ใบ — GDD ข้อ 5.2 การันตีอย่างน้อย 2`);
  }
});

test('ดัชนีตลาดอยู่ในกรอบที่กำหนดเสมอ', () => {
  for (const jobId of ['programmer', 'doctor', 'cleaner']) {
    for (let s = 1; s <= 20; s++) {
      const { match } = runSolo(jobId, s * 555);
      assert.ok(match.marketIndex >= 0.5 && match.marketIndex <= 1.9,
        `${jobId} seed ${s}: ดัชนีตลาดหลุดกรอบ (${match.marketIndex})`);
    }
  }
});

test('ทุกอาชีพมีข้อมูลครบและสมเหตุสมผล', () => {
  assert.strictEqual(E.JOBS.length, 16, 'จำนวนอาชีพเปลี่ยนไปจาก 16 — ต้องอัปเดตเอกสารด้วย');
  const ids = new Set();
  for (const j of E.JOBS) {
    assert.ok(!ids.has(j.id), `id ซ้ำ: ${j.id}`);
    ids.add(j.id);
    assert.ok(j.salary > 0 && j.fixed > 0 && j.food > 0, `${j.id}: ตัวเลขการเงินผิด`);
    assert.ok(j.tier >= 1 && j.tier <= 4, `${j.id}: tier ผิด`);
    assert.ok(j.health > 0 && j.health <= 100, `${j.id}: สุขภาพเริ่มต้นผิด`);
    assert.ok(j.work + j.commute < 720, `${j.id}: งาน+เดินทางกินเกิน 720 ชม.`);
    assert.ok([7, 8].includes(j.sleepNeed || 7), `${j.id}: เกณฑ์การนอนผิด`);
    // ต้องเหลือเวลาว่างให้เล่นเกมได้จริง
    const free = 720 - (j.sleepNeed || 7) * 30 - j.work - j.commute - 30 - E.CHORES_HOURS;
    assert.ok(free > 0, `${j.id}: ไม่เหลือเวลาว่างเลยแม้แต่ชั่วโมงเดียว (${free})`);
  }
});
