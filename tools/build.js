#!/usr/bin/env node
/* =========================================================
   ประกอบไฟล์เดียวจบสำหรับให้คนนอกเล่น
       ui.html (UI ล้วน) + engine.js (ตรรกะล้วน) → wealth-quest-prototype.html

   ทำไมต้องมีไฟล์นี้: เดิมการประกอบทำด้วยมือ แก้ engine.js แล้วไฟล์ที่คนเล่นจริง
   ไม่เปลี่ยนตาม — บั๊กที่แก้แล้วก็ยังอยู่ในมือผู้เล่น
   ตอนนี้ให้รัน `node tools/build.js` ทุกครั้งหลังแก้เอนจิน

   ใช้:  node tools/build.js           → เขียนไฟล์
         node tools/build.js --check   → ตรวจว่าไฟล์ที่มีอยู่ตรงกับ source ไหม (ไม่เขียนทับ)
   ========================================================= */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const UI = path.join(ROOT, 'ui.html');
const ENGINE = path.join(ROOT, 'engine.js');
const OUT = path.join(ROOT, 'wealth-quest-prototype.html');
const SLOT = '/*__ENGINE__*/';

function build() {
  const ui = fs.readFileSync(UI, 'utf8');
  const engine = fs.readFileSync(ENGINE, 'utf8');

  if (!ui.includes(SLOT)) {
    console.error(`❌ ไม่พบช่อง ${SLOT} ใน ui.html — ประกอบไฟล์ไม่ได้`);
    process.exit(1);
  }
  if (ui.split(SLOT).length > 2) {
    console.error(`❌ พบช่อง ${SLOT} มากกว่าหนึ่งที่ใน ui.html`);
    process.exit(1);
  }

  /* ตัดท้าย module.exports ทิ้ง — เบราว์เซอร์ไม่มี module และไฟล์ที่แจกอยู่เดิมก็ไม่มีบล็อกนี้
     (โค้ดมี guard `typeof module !== 'undefined'` อยู่แล้ว จึงไม่พังถ้าไม่ตัด แต่ตัดให้ตรงของเดิม) */
  const EXPORT_RE = /\nif \(typeof module !== 'undefined'\) module\.exports = \{[\s\S]*?\n\};\n/;
  if (!EXPORT_RE.test(engine)) {
    console.error('❌ ไม่พบบล็อก module.exports ท้าย engine.js — โครงไฟล์เปลี่ยนไป ตรวจ tools/build.js ก่อน');
    process.exit(1);
  }
  const browserEngine = engine.replace(EXPORT_RE, '\n');

  return ui.replace(SLOT, browserEngine);
}

const out = build();
const check = process.argv.includes('--check');
const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;

if (check) {
  if (existing === out) {
    console.log('✅ wealth-quest-prototype.html ตรงกับ ui.html + engine.js แล้ว');
  } else {
    console.error('❌ wealth-quest-prototype.html ไม่ตรงกับ source — ต้องรัน `node tools/build.js`');
    process.exit(1);
  }
} else {
  fs.writeFileSync(OUT, out);
  const kb = (Buffer.byteLength(out) / 1024).toFixed(0);
  console.log(`✅ ประกอบเสร็จ → wealth-quest-prototype.html (${kb} KB)` +
    (existing === out ? ' — ไม่มีอะไรเปลี่ยน' : ''));
}
