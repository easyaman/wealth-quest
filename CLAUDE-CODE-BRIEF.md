# Brief สำหรับ Claude Code — เริ่มงานอาร์ต 3D low poly ใน Wealth Quest

> คัดลอกข้อความในกรอบด้านล่างไปวางใน Claude Code ที่โฟลเดอร์ `wealth-quest/godot` ได้เลย
> (สั่งทีละ Sprint — อย่าวางทั้งหมดในครั้งเดียว)

---

## Sprint A — วางโครง 3D + Showcase (ไม่ต้องมีโมเดลจริงสักชิ้น)

```
อ่าน CLAUDE.md, ../ART-DIRECTION.md (ทั้งไฟล์) และ ../WEALTH-QUEST-GDD.md บทที่ 3A, 12 ก่อนเริ่ม

เป้าหมาย: วางโครงงานอาร์ต 3D สไตล์ low poly flat-shaded ตาม ART-DIRECTION.md
โดยใช้ placeholder เมช (BoxMesh/CylinderMesh) ทั้งหมด ยังไม่ต้องมี .glb จริง
core/ และ sim/ ห้ามแตะ · headless sim ทุกตัวต้องยังรันผ่านเหมือนเดิม

ทำตามลำดับ:
1. สร้าง ui/theme/palette.gd (const สีตาม ART-DIRECTION 2.4) และ world/materials/palette.png
   (256×16 palette atlas สร้างด้วยสคริปต์ headless จากค่าใน palette.gd) + world/materials/flat.tres
   (StandardMaterial3D: albedo_texture = palette.png, roughness 1.0, metallic 0, specular 0)
2. world/showcase/Showcase.tscn + showcase.gd — SubViewport, กล้อง perspective FOV 35,
   DirectionalLight3D ดวงเดียวมุมบนซ้าย, พื้นหลัง gradient สองสี + กรอบมนซ้อนหลัง (ตามรูป IMG_3632.jpg),
   แท่นหมุน 12°/วิ ลากเมาส์หมุนได้, API: show(kind: String, id: String, stats: Array[Dictionary])
   โดย stats = [{label, value, max, color}] วาดเป็น stat_bar แบนใต้ภาพ
   ถ้าไม่มี world/models/<kind>/<id>.glb ให้ใช้ BoxMesh สีตาม kind แทน (อย่า error)
3. ui/widgets/stat_bar.gd — แถบสถิติแบบรูปอ้างอิง (label ตัวพิมพ์ใหญ่ + เส้นบางเทา + เส้นเติมสี)
   แล้วเปลี่ยน time_budget และแถบสุขภาพให้ใช้ stat_bar ตัวเดียวกัน
4. ต่อ Showcase เข้ากับ deal_card: hover การ์ด → Showcase แสดงดีลนั้นพร้อมแถบ
   ผลตอบแทน %/เดือน · เงินดาวน์ · เวลาปิดดีล · ความผันผวน (ตัวเลขจาก core เท่านั้น ห้ามคำนวณเองใน UI)
5. world/city/City.tscn + city.gd + place_node.gd + avatar.gd —
   กล้อง Orthogonal size 22 rotation (-30, 45, 0), วาง PlaceNode ตาม x ใน data/places.json (0–100 → −25..+25),
   อาคาร placeholder = BoxMesh สูงต่างกัน + Label3D ชื่อ, avatar = CapsuleMesh เดินไป place เมื่อ player.place เปลี่ยน
   (tween 0.6 วิ, คลิกซ้ำ = วาร์ป), คลิกอาคาร → ยิงสัญญาณ place_clicked(place_id) ให้ ui/main.gd
   world/ ห้ามเรียก travel_to() หรือแก้ state เอง
6. เพิ่ม world/tools/icon_bake.gd — headless เรนเดอร์ทุก .glb (ตอนนี้จะได้ placeholder) เป็น ui/theme/icons/<id>.png 128×128
7. เพิ่ม sim/world_check.gd — headless: โหลด City + Showcase, bind กับ match จำลอง 3 เดือน, ยืนยันไม่ error
   และยืนยันว่า core/ ไม่มี preload world/ (grep)
8. อัปเดต CLAUDE.md หัวข้อ "งานอาร์ต 3D" ให้ตรงกับที่ทำจริง + เพิ่มคำสั่ง world_check ใน "คำสั่งที่ใช้บ่อย"

ก่อนจบ: godot --headless --quit ต้องไม่มี error · rng_check / headless_sim / save_check / ui_check / world_check ผ่านหมด
· WQ_SHOT=/tmp/ui.png godot แล้วเปิดดูภาพ ยืนยันว่าเห็นฉากเมือง + Showcase บนหน้าจอ
```

---

## Sprint B — โมเดลชุดแรก + ไอคอนแทนอีโมจิ

```
อ่าน ../ART-DIRECTION.md ข้อ 2, 3, 5 ก่อน

เป้าหมาย: แทนที่ placeholder ด้วย .glb จริงกลุ่มแรก และเลิกใช้อีโมจิใน UI
1. สร้าง world/models/README.md — spec การ export (origin ที่ฐาน, flat shade, material ชื่อ flat, tris budget, ชื่อไฟล์ = id)
   + ตารางเช็กลิสต์ทุก id จาก data/places.json (places, vehicles, devices, packs), data/deals.json, data/dreams.json
   ว่ามี .glb แล้วหรือยัง (สร้างตารางด้วยสคริปต์ อย่าพิมพ์มือ)
2. เขียน world/tools/model_lint.gd — headless: โหลดทุก .glb ตรวจ tris budget, มี material เดียว, AABB ฐานอยู่ที่ y=0, ชื่อตรง id · รายงานตัวที่ไม่ผ่าน
3. ให้พาหนะ 5 คัน + อุปกรณ์ 2 ชิ้นเป็นกลุ่มแรก — ถ้ายังไม่มีไฟล์จากคนปั้น ให้สร้าง "kitbash placeholder" ด้วย
   ArrayMesh จากกล่อง/ทรงกระบอกหลายชิ้นในโค้ด (world/tools/kitbash.gd) เพื่อให้ Showcase ดูเป็นรูปเป็นร่างก่อน
   — รถหรูต้องดูฟุ่มเฟือยกว่ารถใหม่ชัดเจน (GDD 3A.2)
4. รัน icon_bake แล้วเปลี่ยน deal_card, statement, debt_list, time_budget ให้ใช้ TextureRect จาก ui/theme/icons/
   แทนอีโมจิ · ถ้าไม่มีไอคอน id นั้นให้ fallback เป็นอีโมจิเดิม (อย่าให้จอว่าง)
5. ร้านพาหนะ/อุปกรณ์ที่ห้าง: หน้า Showcase + ปุ่มซื้อ แถบ = ตัวคูณเวลาเดินทาง · ค่าใช้จ่าย/เดือน ·
   เวลาที่ได้คืน/เดือน (คำนวณจาก commute จริงของ player ผ่านฟังก์ชันใน core ถ้ายังไม่มีให้เพิ่มใน core/player.gd
   แบบ pure function และเพิ่มเทสใน sim/ui_check.gd)
```

---

## Sprint C — ฉากเมืองจริง + สภาพภัยพิบัติ + VFX

```
1. อาคาร 10 หลังจาก .glb (หรือ kitbash) · prop รอบตึกใช้ซ้ำ (ต้นไม้ เสาไฟ ม้านั่ง) วางแบบ deterministic จาก place x
   (ห้าม randf() ในตำแหน่งที่มีผลต่อการอ่านฉาก)
2. ฟัง disaster_started / month_ended: น้ำท่วม = แผ่นน้ำโปร่งยกขึ้น, เศรษฐกิจตก = fog เทา+ป้ายลดราคา, โรคระบาด = ตัวละครใส่หน้ากาก
   ตรวจ id ภัยพิบัติจริงจาก data/disasters.json ก่อน อย่าเดา
3. VFX 4 ตัวเป็น GPUParticles3D เมชเหลี่ยม: payday, deal_closed, disaster, win — ทริกเกอร์จากสัญญาณเท่านั้น
4. avatar: 6 แอนิเมชัน (idle, walk, work, tired เมื่อสุขภาพ<40, celebrate, hit) — ถ้ายังไม่มีริก ให้ทำ procedural bob/tilt ไปก่อน
5. หน้าเลือกอาชีพ (GDD บทที่ 7) ใช้ Showcase โชว์ตัวละครในชุดอาชีพ + แถบ ชม.ว่างใช้ได้ · เงินเดือน · commute
```

---

## กติกาที่ต้องย้ำกับ Claude Code ทุก Sprint

- `core/` ห้ามรู้จัก `world/` และ `ui/` — headless sim ต้องรันได้โดยไม่โหลด 3D
- ตัวเลขทุกตัวบนจอมาจาก core — UI/world ห้ามคำนวณสูตรเกมเอง
- `randf()` ใน world/ ใช้ได้เฉพาะแอนิเมชันที่ไม่กระทบสถานะและไม่กระทบการอ่านฉาก
- ทุกไฟล์ `.glb` ชื่อ = id ใน `data/*.json` · ไอคอนต้องมาจาก icon_bake ไม่วาดมือ
- ก่อนจบทุกครั้ง: `godot --headless --quit` + sim ทั้งชุด + ถ่าย `WQ_SHOT` มาดูด้วยตา
- ห้ามเพิ่ม dependency ภายนอก · ห้ามเปลี่ยนตัวเลขใน `data/` โดยไม่ถามเจ้าของโปรเจกต์
