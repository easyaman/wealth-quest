class_name WQDice
extends Control
## 🎲 ลูกเต๋าหนึ่งลูก — วาดเอง ไม่ใช้รูป (ART-DIRECTION 2.5: UI แบนสนิท)
##
## เกมนี้เหลือเต๋าอยู่สองจุดเท่านั้น และทั้งสองจุดเป็น "จุดเปลี่ยนชีวิต" ที่ผู้เล่นต้องรู้สึกได้:
##   · ทอยตอนเริ่มเกม = ต้นทุนชีวิตที่เกิดมาพร้อม (GDD บทที่ 7)
##   · ทอยตอนเข้าด่าน 2 = ความฝันที่จะไล่ตามต่อ (GDD บทที่ 9)
## ทั้งคู่ใช้วิดเจ็ตตัวนี้ตัวเดียวกัน ผู้เล่นจึงอ่านออกทันทีว่า "ตรงนี้แหละที่โชคเข้ามาเกี่ยว"
##
## **แต้มที่ออกไม่ได้เกิดที่นี่** — ผู้เล่นเรียก `roll_to(n)` พร้อมแต้มที่ core ทอยมาแล้ว
## วิดเจ็ตนี้แค่เล่นภาพให้ดูเหมือนกำลังกลิ้ง แล้วหยุดที่แต้มนั้น
## ภาพที่กลิ้งจึงไม่ใช้ตัวสุ่มเลย (ไล่หน้า 1→2→…→6 วน) เพื่อไม่ให้ใครเข้าใจผิดว่า
## หน้าจอมีตัวสุ่มของตัวเองที่ไปยุ่งกับผลเกม — ตัวสุ่มของเกมอยู่ในแมตช์ที่เดียว

signal rolled(face: int)

## ตำแหน่งจุดบนตาราง 3×3 ของแต่ละแต้ม (เหมือน `PIPS` ในต้นแบบเว็บ)
const PIPS := {
	1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8],
}
const TICK := 0.07              ## วินาทีต่อหนึ่งหน้าระหว่างกลิ้ง — เท่ากับต้นแบบเว็บ
const TICKS := 14               ## จำนวนหน้าที่พลิกก่อนหยุด (~1 วินาที)

var face := 1 : set = _set_face
var rolling := false

var _left := 0
var _target := 1
var _acc := 0.0


func _init(px := 96.0) -> void:
	custom_minimum_size = Vector2(px, px)


## **ต้องปิด `_process` ที่นี่ ไม่ใช่ใน `_init()`** — Godot เปิด process ให้เองตอนโหนดเข้าฉาก
## ถ้าสคริปต์มี `_process` อยู่ ค่าที่สั่งปิดไว้ตั้งแต่ `_init()` จึงถูกทับ
## (เจอจริง: เต๋าที่หัวข้อหน้าเลือกอาชีพเด้งกลับไปหน้า 1 ทุกครั้ง ทั้งที่โค้ดตั้งแต้มไว้ถูกแล้ว)
func _ready() -> void:
	set_process(rolling)


## เริ่มภาพกลิ้งแล้วไปหยุดที่ `n` — เรียกซ้ำระหว่างกำลังกลิ้งจะไม่ทำอะไร
## (ปุ่มทอยถูกกดรัวๆ ได้จริง ถ้าปล่อยให้ซ้อนกัน สัญญาณ `rolled` จะยิงหลายครั้งต่อการทอยหนึ่งครั้ง)
func roll_to(n: int) -> void:
	if rolling: return
	WQAudio.ui("dice_roll")
	_target = clampi(n, 1, 6)
	_left = TICKS
	_acc = 0.0
	rolling = true
	set_process(true)


## ยกเลิกการกลิ้งแล้วกลับไปนิ่งที่หน้า `n` — ใช้ตอนเริ่มหน้าจอใหม่
## ไม่ยิงสัญญาณ `rolled` เพราะไม่มีการทอยเกิดขึ้นจริง
func reset(n := 1) -> void:
	rolling = false
	set_process(false)
	_left = 0
	_acc = 0.0
	_target = n
	face = n


## จบภาพกลิ้งทันที — ใช้ตอนเทสต์ headless และตอนผู้เล่นกดข้าม
func finish_now() -> void:
	if not rolling: return
	_left = 0
	_settle()


func _process(dt: float) -> void:
	if not rolling:
		set_process(false)
		return
	_acc += dt
	while _acc >= TICK:
		_acc -= TICK
		_left -= 1
		if _left <= 0:
			_settle()
			return
		face = face % 6 + 1


func _settle() -> void:
	WQAudio.ui("dice_land")
	rolling = false
	set_process(false)
	face = _target
	rolled.emit(_target)


func _set_face(v: int) -> void:
	face = clampi(v, 1, 6)
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var org := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var body := Rect2(org, Vector2(s, s))
	draw_rect(body, WQPalette.NEUTRAL_1, true)
	# ขอบหนาขึ้นตอนกลิ้ง = สัญญาณว่ายังไม่ใช่ผลจริง ห้ามอ่านแต้มระหว่างนี้
	draw_rect(body, WQPalette.MONEY, false, 3.0 if rolling else 2.0)

	var r: float = s * 0.085
	var step: float = s / 4.0
	for i in PIPS[face]:
		var col: int = int(i) % 3
		var row: int = int(i) / 3
		draw_circle(org + Vector2(step * (col + 1), step * (row + 1)), r, WQPalette.BG_DEEP)
