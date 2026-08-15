/* =========================================================
   บันทึก / โหลด — ต้องได้เกมเดิมกลับมาเป๊ะ ไม่ใช่ "ใกล้เคียง"
   ถ้าข้อมูลหายแม้แต่ช่องเดียว ผู้เล่นจะเสียของที่ซื้อด้วยเงินจริงในเกม
   และถ้า state ของตัวสุ่มไม่ถูกเก็บ ผู้เล่นจะ save-scum ได้ (GDD ข้อ 14.2)
   ========================================================= */
const { test } = require('node:test');
const assert = require('node:assert');
const { E } = require('./helpers.js');

/** สร้างแมตช์ที่มีคนจริง 1 คน + บอท 1 ตัว แล้วหยุดรอที่ตาคนจริง */
function humanMatch(seed = 555) {
  return new E.Match({
    mode: 'solo', seed,
    players: [
      { name: 'คุณ', jobId: 'programmer', isAI: false },
      { name: 'บอท', jobId: 'teacher', isAI: true }
    ]
  });
}

/** จำลองการเซฟลงไฟล์จริง — ต้องผ่าน JSON ไป-กลับ ไม่ใช่ส่ง object ตรงๆ */
const roundTrip = m => E.Match.load(JSON.parse(JSON.stringify(m.serialize())));

test('โหลดแล้วได้ค่าพื้นฐานของแมตช์กลับมาครบ', () => {
  const m = humanMatch();
  m.endTurn(); m.endTurn();                     // เดินไปสองสามเดือนให้ state ไม่ว่าง
  const b = roundTrip(m);

  assert.strictEqual(b.month, m.month);
  assert.strictEqual(b.state, m.state);
  assert.strictEqual(b.turn, m.turn);
  assert.strictEqual(b.startIndex, m.startIndex);
  assert.strictEqual(b.marketIndex, m.marketIndex);
  assert.strictEqual(b.dealIdSeq, m.dealIdSeq);
  assert.strictEqual(b.deals.length, m.deals.length);
  assert.strictEqual(b.players.length, m.players.length);
});

test('state ของตัวสุ่มถูกเก็บ — โหลดซ้ำแล้วผลลัพธ์ไม่เปลี่ยน (กัน save-scum)', () => {
  const m = humanMatch(31337);
  m.endTurn();
  const save = JSON.stringify(m.serialize());

  // แต่ละครั้งต้อง parse ใหม่ — เหมือนตอนอ่านจากไฟล์จริง ไม่ใช้ object ร่วมกัน
  const runA = E.Match.load(JSON.parse(save));
  const runB = E.Match.load(JSON.parse(save));
  for (let i = 0; i < 12; i++) { runA.endTurn(); runB.endTurn(); }

  assert.strictEqual(runA.month, runB.month, 'โหลดไฟล์เดิมสองครั้งต้องเดินไปทางเดียวกัน');
  assert.strictEqual(runA.rng.s, runB.rng.s);
  assert.deepStrictEqual(
    runA.players.map(p => [p.cash, p.health, p.netWorth]),
    runB.players.map(p => [p.cash, p.health, p.netWorth])
  );
});

test('การเงินและทรัพย์สินของผู้เล่นถูกเก็บครบ', () => {
  const m = humanMatch(909);
  const p = m.players[0];
  p.cash = 500000;
  if (m.deals.length) p.closeDeal(m.deals[0].id);
  p.takeLoan(50000);

  const b = roundTrip(m);
  const q = b.players[0];

  assert.strictEqual(q.cash, p.cash);
  assert.strictEqual(q.salary, p.salary);
  assert.strictEqual(q.health, p.health);
  assert.strictEqual(q.assets.length, p.assets.length, 'ทรัพย์สินหาย');
  assert.strictEqual(q.liabilities.length, p.liabilities.length, 'หนี้สินหาย');
  assert.strictEqual(q.job.id, p.job.id, 'อาชีพต้องผูกกลับด้วย id');
  assert.strictEqual(q.netWorth, p.netWorth);
});

/* ---------- ระบบแผนที่/การเดินทาง (GDD ข้อ 3A) ---------- */

test('พาหนะที่ซื้อไว้ต้องยังอยู่หลังโหลด', () => {
  const m = humanMatch(1212);
  const p = m.players[0];
  p.cash = 2000000;
  p.travelTo('mall');                            // ต้องไปดูรถที่ห้างก่อน
  assert.ok(p.buyVehicle('usedcar').ok, 'ซื้อรถไม่สำเร็จตั้งแต่ต้น');
  assert.strictEqual(p.vehicle, 'usedcar');

  const q = roundTrip(m).players[0];
  assert.strictEqual(q.vehicle, 'usedcar', 'รถหายไปหลังโหลด ทั้งที่หนี้ค่ารถยังอยู่');
  assert.strictEqual(q.travelFactor, p.travelFactor, 'ตัวคูณเวลาเดินทางต้องเท่าเดิม');
  assert.strictEqual(q.commuteHours, p.commuteHours, 'เวลาไปทำงานต้องเท่าเดิม');
});

test('อุปกรณ์ที่ซื้อไว้ต้องยังอยู่หลังโหลด', () => {
  const m = humanMatch(1313);
  const p = m.players[0];
  p.cash = 2000000;
  p.travelTo('mall');
  assert.ok(p.buyDevice('smartphone').ok);
  assert.ok(p.buyDevice('laptop').ok);
  assert.deepStrictEqual(p.devices, ['smartphone', 'laptop']);

  const q = roundTrip(m).players[0];
  assert.deepStrictEqual(q.devices, ['smartphone', 'laptop'], 'อุปกรณ์หายไปหลังโหลด');
  assert.strictEqual(q.has('laptop'), true);
});

test('ตำแหน่งบนแผนที่และเวลาเดินทางที่ใช้ไปแล้วต้องถูกเก็บ', () => {
  const m = humanMatch(1414);
  const p = m.players[0];
  p.travelTo('bank');
  assert.strictEqual(p.place, 'bank');
  const usedBefore = p.travelUsed;
  assert.ok(usedBefore > 0, 'เดินทางแล้วต้องมีชั่วโมงถูกหัก');

  const q = roundTrip(m).players[0];
  assert.strictEqual(q.place, 'bank', 'โหลดแล้วผู้เล่นถูกเทเลพอร์ตกลับบ้าน');
  assert.strictEqual(q.travelUsed, usedBefore);
  assert.strictEqual(q.hours, p.hours);
});

test('แพ็กเกจฟิตเนสและโล่จากการพักผ่อนต้องถูกเก็บ', () => {
  const m = humanMatch(1515);
  const p = m.players[0];
  p.cash = 500000;
  p.travelTo('gym');
  p.exercise('monthly');
  p.travelTo('resort');
  p.vacation('weekend');

  const q = roundTrip(m).players[0];
  assert.strictEqual(q.gymPack, p.gymPack, 'แพ็กเกจฟิตเนสรายเดือนหาย — จ่ายเงินไปแล้วต้องได้ใช้');
  assert.strictEqual(q.shield, p.shield, 'โล่กันเหตุการณ์ร้ายจากการไปพักผ่อนหาย');
});

test('โหลดแล้วเล่นต่อได้โดยไม่ crash', () => {
  const m = humanMatch(1616);
  const p = m.players[0];
  p.cash = 3000000;
  p.travelTo('mall');
  p.buyVehicle('moto');
  p.buyDevice('smartphone');

  const b = roundTrip(m);
  for (let i = 0; i < 24; i++) b.endTurn();     // เดินต่ออีก 2 ปี
  assert.ok(b.month > m.month, 'เกมต้องเดินหน้าต่อได้หลังโหลด');
});

test('ทอยความฝันต้องผูกกับตัวสุ่มของแมตช์ — เซฟแล้วโหลดทอยใหม่ต้องได้ผลเดิม', () => {
  const m = humanMatch(8080);
  const save = JSON.stringify(m.serialize());

  // ผู้เล่นที่พยายาม save-scum: โหลดไฟล์เดิมสิบครั้ง แล้วทอยความฝันใหม่ทุกครั้ง
  const rolls = [];
  for (let i = 0; i < 10; i++) {
    rolls.push(E.Match.load(JSON.parse(save)).players[0].rollDream());
  }
  assert.strictEqual(new Set(rolls).size, 1,
    `โหลดไฟล์เดิมแล้วทอยได้ผลต่างกัน (${[...new Set(rolls)].join(',')}) — ผู้เล่นทอยใหม่จนได้ความฝันที่ถูกที่สุดได้`);

  const n = rolls[0];
  assert.ok(Number.isInteger(n) && n >= 1 && n <= E.DREAMS.length, `แต้มความฝันหลุดช่วง: ${n}`);
});

test('ทอยความฝันเดินตัวสุ่มไปข้างหน้า — ทอยใหม่ในเกมเดียวกันได้ผลต่างกันได้', () => {
  const p = humanMatch(9090).players[0];
  const rolls = Array.from({ length: 40 }, () => p.rollDream());
  assert.ok(new Set(rolls).size > 1, 'ทอย 40 ครั้งในเกมเดียวกันได้ค่าเดิมตลอด — ตัวสุ่มไม่เดิน');
});

test('ปฏิเสธไฟล์เซฟคนละเวอร์ชันอย่างสุภาพ', () => {
  const save = humanMatch().serialize();
  save.v = 3;
  assert.throws(() => E.Match.load(save), /เวอร์ชัน|ไม่ถูกต้อง/);
});

test('ภัยพิบัติที่กำลังมีผลถูกเก็บเป็น id แล้วผูกกลับได้', () => {
  const m = humanMatch(2024);
  for (let i = 0; i < 60 && !m.activeDisasters.length; i++) m.endTurn();
  assert.ok(m.activeDisasters.length > 0, 'เดิน 60 ตายังไม่เจอภัยพิบัติเลย — คาบน่าจะผิด');

  const b = roundTrip(m);
  assert.strictEqual(b.activeDisasters.length, m.activeDisasters.length);
  assert.strictEqual(b.activeDisasters[0].def.id, m.activeDisasters[0].def.id);
  assert.strictEqual(b.activeDisasters[0].left, m.activeDisasters[0].left);
});
