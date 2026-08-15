# Wealth Quest — Godot project skeleton

เกมการเงิน 2.5D · เงิน · เวลา · สุขภาพ

## เริ่มยังไง

1. เปิดโฟลเดอร์นี้ด้วย Godot 4.3+
2. ตรวจว่าพอร์ตถูกต้องก่อนทำอย่างอื่น:
   ```bash
   godot --headless --script res://sim/headless_sim.gd
   ```
3. อ่าน `CLAUDE.md` (บริบทและกฎของโปรเจกต์) และ `../WEALTH-QUEST-GDD.md` (เอกสารออกแบบ)

## สถานะ

| ส่วน | สถานะ |
|---|---|
| core (rng, player, match, ai, save) | พอร์ตแล้ว — **ยังไม่เคยรัน** ต้องตรวจก่อน |
| data (ตารางสมดุล) | ครบ สร้างจากเอนจิน JS ที่ผ่านการจำลอง 4,000 เกม |
| headless sim | เขียนแล้ว |
| UI | placeholder (RichTextLabel + กด Space เพื่อจบตา) |
| ฉาก 2.5D / อาร์ต / เสียง | ยังไม่มี |

## หมายเหตุ

โค้ด GDScript ทั้งหมดเขียนโดยแปลจาก `engine.js` ซึ่งเป็น reference implementation ที่ทดสอบแล้ว
ถ้าผลจาก sim ไม่ตรงกับตารางอ้างอิงใน `CLAUDE.md` **ให้เชื่อ `engine.js` เป็นหลัก**
