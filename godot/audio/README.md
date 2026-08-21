# เสียงของ Wealth Quest

> ไฟล์นี้สร้างจาก `audio/tools/sfx_readme.gd` **ห้ามแก้ด้วยมือ**

ทุกไฟล์ตอนนี้เป็นคลื่นสังเคราะห์จาก `WQSynth` ไม่ใช่เสียงที่คนทำ
วางไฟล์ `.wav` ของตัวเองทับได้ทีละตัว — ตัวอบจะเห็นว่า sha256 ไม่ตรงกับที่จดไว้
แล้วจะไม่แตะไฟล์นั้นอีกเลย

ฟังทีละตัว: `WQ_SFX=<id> godot --path .`

| id | ดังตอนไหน | คลื่น | ยาว (วิ) | ที่มา |
|---|---|---|---|---|
| `buy` | core ยิง `acted(buy)` | square | 0.22 | 🤖 อบจากโค้ด |
| `click` | เลน UI — `WQAudio.ui("click")` | square | 0.04 | 🤖 อบจากโค้ด |
| `deal_closed` | สัญญาณของแมตช์/ผู้เล่น | triangle | 0.40 | 🤖 อบจากโค้ด |
| `denied` | เลน UI — `WQAudio.ui("denied")` | square | 0.16 | 🤖 อบจากโค้ด |
| `dice_land` | เลน UI — `WQAudio.ui("dice_land")` | square | 0.12 | 🤖 อบจากโค้ด |
| `dice_roll` | เลน UI — `WQAudio.ui("dice_roll")` | noise | 0.35 | 🤖 อบจากโค้ด |
| `disaster` | สัญญาณของแมตช์/ผู้เล่น | noise | 0.70 | 🤖 อบจากโค้ด |
| `freelance` | core ยิง `acted(freelance)` | square | 0.20 | 🤖 อบจากโค้ด |
| `gym` | core ยิง `acted(gym)` | square | 0.25 | 🤖 อบจากโค้ด |
| `health_low` | สัญญาณของแมตช์/ผู้เล่น | square | 0.60 | 🤖 อบจากโค้ด |
| `lifestyle` | core ยิง `acted(lifestyle)` | square | 0.16 | 🤖 อบจากโค้ด |
| `load` | เลน UI — `WQAudio.ui("load")` | square | 0.14 | 🤖 อบจากโค้ด |
| `loan` | core ยิง `acted(loan)` | square | 0.35 | 🤖 อบจากโค้ด |
| `lose` | สัญญาณของแมตช์/ผู้เล่น | triangle | 1.00 | 🤖 อบจากโค้ด |
| `month_end` | สัญญาณของแมตช์/ผู้เล่น | triangle | 0.50 | 🤖 อบจากโค้ด |
| `ot` | core ยิง `acted(ot)` | square | 0.20 | 🤖 อบจากโค้ด |
| `panel_close` | เลน UI — `WQAudio.ui("panel_close")` | square | 0.10 | 🤖 อบจากโค้ด |
| `panel_open` | เลน UI — `WQAudio.ui("panel_open")` | square | 0.10 | 🤖 อบจากโค้ด |
| `payday` | สัญญาณของแมตช์/ผู้เล่น | triangle | 0.45 | 🤖 อบจากโค้ด |
| `phase2` | core ยิง `acted(phase2)` | triangle | 0.70 | 🤖 อบจากโค้ด |
| `repay` | core ยิง `acted(repay)` | square | 0.30 | 🤖 อบจากโค้ด |
| `resort` | core ยิง `acted(resort)` | triangle | 0.55 | 🤖 อบจากโค้ด |
| `rest` | core ยิง `acted(rest)` | triangle | 0.40 | 🤖 อบจากโค้ด |
| `save` | เลน UI — `WQAudio.ui("save")` | square | 0.14 | 🤖 อบจากโค้ด |
| `scout` | core ยิง `acted(scout)` | square | 0.24 | 🤖 อบจากโค้ด |
| `sell` | core ยิง `acted(sell)` | triangle | 0.30 | 🤖 อบจากโค้ด |
| `study` | core ยิง `acted(study)` | triangle | 0.35 | 🤖 อบจากโค้ด |
| `travel` | core ยิง `acted(travel)` | noise | 0.30 | 🤖 อบจากโค้ด |
| `tutorial_step` | เลน UI — `WQAudio.ui("tutorial_step")` | triangle | 0.18 | 🤖 อบจากโค้ด |
| `win` | สัญญาณของแมตช์/ผู้เล่น | triangle | 1.20 | 🤖 อบจากโค้ด |

**คนทำเสียงจริงแล้ว 0/30 ตัว**

## สเปกสำหรับคนทำเสียง

- mono · 22050 Hz ขึ้นไป · 16-bit PCM `.wav`
- ยาวไม่เกิน 2 วินาที (เสียงชนะยาวสุดที่ 1.2 วินาที)
- ชื่อไฟล์ = id ในตารางข้างบนเป๊ะ
- ทำให้ดังพอๆ กับไฟล์ที่อบไว้ ระบบไม่มี normalize ให้
