class_name WQIcon
extends RefCounted
## ไอคอนใน UI — รูปเรนเดอร์จากเมช 3D ชิ้นเดียวกับที่โชว์บนแท่น (ART-DIRECTION ข้อ 2.5)
##
## เลิกใช้อีโมจิเป็นไอคอนจริง เพราะอีโมจิหน้าตาไม่เหมือนกันข้ามเครื่อง
## และไม่มีทางตรงกับของที่ผู้เล่นเห็นในฉาก 3D ได้เลย
##
## **ไม่มีไอคอนของ id นั้น = ใช้อีโมจิเดิม** ห้ามปล่อยให้ช่องว่าง
## เพราะของอย่างอาหาร/สถานะ ไม่มีเมชและจะไม่มีวันมี

const DIR := "res://ui/theme/icons"
const DEFAULT_PX := 18


static func path_of(id: String) -> String:
	return "%s/%s.png" % [DIR, id]


static func exists(id: String) -> bool:
	return id != "" and ResourceLoader.exists(path_of(id))


## คืน TextureRect ถ้ามีไอคอน ไม่งั้นคืน Label ที่เป็นอีโมจิเดิม — ผู้เรียกไม่ต้องสนใจว่าได้อันไหน
static func make(id: String, fallback_emoji: String, px := DEFAULT_PX) -> Control:
	if exists(id):
		var t := TextureRect.new()
		t.texture = load(path_of(id))
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# โปรเจกต์ตั้ง default filter เป็น Nearest ไว้ (project.godot) ซึ่งเหมาะกับงาน pixel
		# แต่ไอคอนถูกอบมาที่ 128px แล้วย่อลงเหลือ ~18px การย่อ 7 เท่าแบบ Nearest จะแตกเป็นจุดๆ
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return t
	var l := Label.new()
	l.text = fallback_emoji
	l.add_theme_font_size_override("font_size", px - 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## ติดไอคอนให้ปุ่ม — คืน true ถ้าติดได้จริง ผู้เรียกจะได้รู้ว่าต้องใส่อีโมจิลงในข้อความไหม
##
## มีไว้เพราะ Button ใส่ลูกเป็น HBox ไม่ได้ ต้องใช้ช่อง `icon` ของมันเอง
## แต่กติกา "ไอคอนใน UI ต้องผ่าน WQIcon เสมอ" ยังต้องเป็นจริง — ตัวเลือก fallback
## กับการตั้ง filter จึงต้องอยู่ที่นี่ที่เดียว ไม่ใช่ให้แต่ละวิดเจ็ตไปเดาเอง
static func decorate_button(btn: Button, id: String) -> bool:
	if not exists(id): return false
	btn.icon = load(path_of(id))
	btn.expand_icon = true
	# ไอคอนอบมาที่ 128px แล้วย่อลงเหลือความสูงของปุ่ม — ถ้าใช้ Nearest ตามค่าเริ่มต้นของโปรเจกต์
	# จะแตกเป็นจุดๆ (เหตุผลเดียวกับใน make())
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return true


## แถวแนวนอน [ไอคอน][ข้อความ] — รูปแบบที่ใช้ซ้ำทั่ว UI
static func row(id: String, fallback_emoji: String, text: String, px := DEFAULT_PX) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(make(id, fallback_emoji, px))
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h
