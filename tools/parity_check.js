#!/usr/bin/env node
/* =========================================================
   เทียบผลรายเกมของพอร์ต GDScript กับเอนจิน JS ทีละเมล็ดสุ่ม
   เกณฑ์ผ่านของเฟส 2: ต้องตรงกันทุกช่อง ไม่ใช่แค่ค่าเฉลี่ยใกล้กัน

   ใช้:  node tools/parity_dump.js 60 > js.json
         godot --headless --path godot --script res://sim/parity_dump.gd -- 60 | grep '^ROW' > gd.txt
         node tools/parity_check.js js.json gd.txt
   ========================================================= */
const fs = require('fs');

const js = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const gdLines = fs.readFileSync(process.argv[3], 'utf8').split('\n').filter(l => l.startsWith('ROW '));

const COLS = ['seed', 'finished', 'dreamDone', 'bankrupt', 'months', 'health', 'netWorth',
  'assets', 'vehicle', 'devices', 'studyLevel'];

const gd = {};
for (const line of gdLines) {
  const f = line.slice(4).split(' ');
  const job = f[0];
  (gd[job] ||= []).push(f.slice(1));
}

let total = 0, bad = 0;
const firstBad = [];
for (const job of Object.keys(js)) {
  const a = js[job], b = gd[job] || [];
  for (let i = 0; i < a.length; i++) {
    total++;
    const row = a[i].map(String);
    const other = (b[i] || []).map(String);
    const diffs = COLS.map((c, k) => row[k] === other[k] ? null : `${c}: js=${row[k]} gd=${other[k]}`).filter(Boolean);
    if (diffs.length) {
      bad++;
      if (firstBad.length < 12) firstBad.push(`${job} seed#${row[0]} → ${diffs.join(', ')}`);
    }
  }
}

console.log(`เกมที่เทียบ: ${total} · ตรงกัน: ${total - bad} · ต่างกัน: ${bad}`);
for (const l of firstBad) console.log('  ' + l);
console.log(bad === 0 ? 'ผลลัพธ์ตรงกับ engine.js ทุกเกม ✅' : 'ยังมีเกมที่ไม่ตรง ❌');
process.exit(bad === 0 ? 0 : 1);
