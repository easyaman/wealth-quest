/* =========================================================
   ตัวสุ่ม — ฐานรากของทุกอย่าง ถ้าตรงนี้เพี้ยน สมดุลทั้งเกมเพี้ยนตาม
   ค่าอ้างอิงตรงกับที่ระบุใน godot/CLAUDE.md เพื่อให้พอร์ต GDScript
   เทียบได้ว่าถูกต้องหรือไม่
   ========================================================= */
const { test } = require('node:test');
const assert = require('node:assert');
const { E } = require('./helpers.js');

/** ค่าที่พอร์ต Godot ต้องทำให้ได้เป๊ะ — ห้ามแก้ตัวเลขชุดนี้เพื่อให้เทสต์ผ่าน */
const SEED_12345_FIRST_5 = [
  0.9797282677609473,
  0.3067522644996643,
  0.4842054215259850,
  0.8179344125092030,
  0.5094283693470061
];

test('makeRng(12345) ให้ค่า 5 ตัวแรกตรงกับค่าอ้างอิงเป๊ะ', () => {
  const r = E.makeRng(12345);
  const got = [r(), r(), r(), r(), r()];
  assert.deepStrictEqual(got, SEED_12345_FIRST_5);
});

test('seed เดียวกันให้ลำดับเดียวกันเสมอ', () => {
  const a = E.makeRng(777), b = E.makeRng(777);
  for (let i = 0; i < 500; i++) assert.strictEqual(a(), b());
});

test('seed ต่างกันให้ลำดับต่างกัน', () => {
  const a = E.makeRng(1), b = E.makeRng(2);
  let same = 0;
  for (let i = 0; i < 100; i++) if (a() === b()) same++;
  assert.strictEqual(same, 0, 'seed ต่างกันไม่ควรให้ค่าตรงกันเลยใน 100 ครั้งแรก');
});

test('ค่าที่ได้อยู่ในช่วง [0,1) เสมอ', () => {
  const r = E.makeRng(2026);
  for (let i = 0; i < 20000; i++) {
    const v = r();
    assert.ok(v >= 0 && v < 1, `ค่าหลุดช่วง: ${v}`);
    assert.ok(Number.isFinite(v), `ค่าไม่ใช่ตัวเลขจำกัด: ${v}`);
  }
});

test('เก็บ state แล้วเรียกคืนได้ — นี่คือสิ่งที่กัน save-scum', () => {
  const r = E.makeRng(4242);
  for (let i = 0; i < 37; i++) r();          // เดินไปกลางทาง
  const snapshot = r.s;                       // อย่างที่ serialize() เก็บ
  const expected = [r(), r(), r(), r(), r()];

  const restored = E.makeRng(0);
  restored.s = snapshot >>> 0;                // อย่างที่ Match.load() เรียกคืน
  const actual = [restored(), restored(), restored(), restored(), restored()];

  assert.deepStrictEqual(actual, expected, 'โหลด state แล้วต้องได้ลำดับเดิมต่อจากจุดเดิม');
});

test('state เป็นจำนวนเต็ม 32 บิตไม่มีเครื่องหมาย — เซฟลง JSON ได้ปลอดภัย', () => {
  const r = E.makeRng(99);
  for (let i = 0; i < 1000; i++) {
    r();
    const s = r.s >>> 0;
    assert.ok(Number.isInteger(s) && s >= 0 && s <= 0xFFFFFFFF, `state ผิดรูป: ${r.s}`);
  }
});
