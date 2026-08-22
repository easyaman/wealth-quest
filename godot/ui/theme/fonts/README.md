# ฟอนต์ที่ฝังมากับเกม

| ไฟล์ | ที่มา | สิทธิ์ |
|---|---|---|
| `NotoSansThai.ttf` | [google/fonts · ofl/notosansthai](https://github.com/google/fonts/tree/main/ofl/notosansthai) — ไฟล์ต้นทางชื่อ `NotoSansThai[wdth,wght].ttf` | SIL Open Font License 1.1 (`OFL.txt`) |

เป็นฟอนต์แบบ **variable** ไฟล์เดียวได้ทุกน้ำหนัก (Thin 100 → Black 900) จึงไม่ต้องเก็บไฟล์
Regular กับ Bold แยกกัน — `ui/theme/fonts.gd` ดึงตัวหนาออกมาด้วย `FontVariation` แกน `wght`

ครอบทั้งอักษรไทยและละติน/ตัวเลข จึงใช้เป็นฟอนต์เดียวของทั้งเกมได้
ส่วนอีโมจิไม่มีอยู่ในไฟล์นี้ ยังยืมจากฟอนต์ระบบผ่าน `allow_system_fallback` เหมือนเดิม

## OFL แปลว่าอะไรในทางปฏิบัติ

- แจกฟอนต์ไปพร้อมเกมได้ ขายเกมได้ ไม่ต้องจ่ายค่าสิทธิ์
- **ต้องแนบ `OFL.txt` ไปด้วยเสมอ** — ห้ามลบทิ้งตอนแพ็กไฟล์ส่งออก
- Noto ไม่มี Reserved Font Name จึงไม่ต้องเปลี่ยนชื่อไฟล์เวลาแก้ฟอนต์

## เปลี่ยนฟอนต์ยังไง

วางไฟล์ `.ttf`/`.otf` ตัวใหม่ลงโฟลเดอร์นี้ → แก้ `WQFonts.PATH` ให้ชี้ไฟล์ใหม่ →
`godot --headless --path . --import` → `godot --headless --path . --script res://sim/font_check.gd`

ฟอนต์ตัวใหม่ต้องมีสระบนล่างและวรรณยุกต์ไทยครบ ไม่งั้น `font_check` จะไม่ผ่าน
(ฟอนต์ละตินล้วนทำให้ข้อความไทยกลายเป็นกล่องเปล่า ซึ่งเป็นเหตุผลที่ต้องฝังฟอนต์ตั้งแต่แรก)
