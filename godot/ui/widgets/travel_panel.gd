class_name WQTravelPanel
extends PanelContainer
## 📍 แผงสถานที่และการเดินทาง — บทที่ 3A ของ GDD
##
## **เรียงตามตำแหน่งจริงบนถนน (x 0–100) ไม่ใช่เรียงตามระยะทางจากตัวเรา**
## เพราะเมืองนี้เป็นถนนเส้นเดียว และ GDD 3A.6 ข้อ 2 ตั้งใจให้ "จะแวะที่ไหนก่อน"
## เป็นเกมย่อยที่ซ้อนบนเกมเดิม — ถ้าเรียงตามระยะทาง ผู้เล่นจะเห็นแค่ "อะไรใกล้ที่สุด"
## แต่มองไม่เห็นว่าอะไรอยู่ "ทางเดียวกัน" ซึ่งเป็นข้อมูลที่ใช้วางแผนเส้นทางได้จริง
## เรียงตาม x แล้วปักหมุดว่าตอนนี้อยู่ตรงไหน = อ่านแผงนี้แล้วเห็นถนนทั้งเส้นในหัว
##
## กฎการนำเสนอข้อ 12.2.3: ทุกปุ่มติดป้ายราคาเป็นชั่วโมง — ปุ่มเดินทางบอกค่าเดินทาง
## และรายการกิจกรรมของแต่ละที่บอกราคาของมันเอง (ถามจาก core ผ่าน `act_cost()`)
##
## กฎเหล็ก: แผงนี้ไม่ย้ายผู้เล่นเอง — กดแล้วยิงสัญญาณ `travel_requested`
## ให้ `ui/main.gd` เป็นคนเรียก `travel_to()` เหมือนที่ฉากเมือง 3D ทำ

signal travel_requested(place_id: String)

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const GOOD := Color("7ee08a")
const HERE := Color("ffffff")

## ชื่อกิจกรรมที่ผู้เล่นอ่านรู้เรื่อง — id พวกนี้มาจาก `acts` ใน data/places.json
## (เป็นข้อความสำหรับคนอ่าน ไม่ใช่ตัวเลขเกม จึงอยู่ฝั่ง UI ได้)
const ACT_LABEL := {
	"sleep": "ตั้งค่าการนอน", "food": "วางแผนอาหาร", "rest": "พักผ่อนที่บ้าน",
	"homework": "งานเสริมที่บ้าน", "homestudy": "เรียนออนไลน์", "mobile": "ธุรกรรมผ่านมือถือ",
	"ot": "รับ OT", "loan": "กู้เงิน", "repay": "ชำระหนี้", "fund": "กองทุน/ตราสารหนี้",
	"estate": "ดีลอสังหาฯ & ธุรกิจ", "scout": "สำรวจดีล", "gold": "ของเก็งกำไร",
	"freelance": "งานฟรีแลนซ์", "study": "เรียนแบบมีอาจารย์", "gym": "ออกกำลังกาย",
	"shop": "ซื้อพาหนะ/อุปกรณ์", "resort": "แพ็กเกจพักผ่อน",
}

## กิจกรรมที่ "อุปกรณ์" ตัดความจำเป็นในการเดินทางทิ้งไปเลย (GDD 3A.3)
const DEVICE_SHORTCUT := {
	"loan": "smartphone", "repay": "smartphone", "fund": "smartphone",
	"study": "laptop", "freelance": "laptop",
}

var _player = null
var _title: Label
var _used: Label
var _list: VBoxContainer
var _rebuilding := false


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var head := HBoxContainer.new()
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 16)
	head.add_child(_title)
	_used = Label.new()
	_used.add_theme_color_override("font_color", DIM)
	_used.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_used)
	col.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(_queue_rebuild):
		_player.changed.disconnect(_queue_rebuild)
	_player = player
	if _player != null:
		_player.changed.connect(_queue_rebuild)
	refresh()


## สร้างปุ่มใหม่ทั้งแผงต้องเลื่อนไปสิ้นเฟรม — ห้าม free() ปุ่มทิ้งระหว่างที่ปุ่มนั้น
## กำลังส่งสัญญาณ pressed อยู่ (เหตุผลเดียวกับ WQDealMarket._queue_rebuild)
## ธงกันคิวซ้อนไว้ด้วย ไม่งั้น changed ที่ยิงหลายครั้งในเฟรมเดียวจะสร้างแผงใหม่หลายรอบ
func _queue_rebuild() -> void:
	if _rebuilding: return
	_rebuilding = true
	call_deferred("_do_rebuild")


func _do_rebuild() -> void:
	_rebuilding = false
	refresh()


func refresh() -> void:
	var p = _player
	if p == null: return
	_title.text = "📍 สถานที่ในเมือง"
	_used.text = "เดือนนี้เดินทางไปแล้ว %d ชม." % p.travel_used

	for c in _list.get_children():
		_list.remove_child(c)
		c.free()

	# เรียงตาม x = เรียงตามถนนจริง ผู้เล่นจะเห็นว่าอะไรอยู่ทางเดียวกันกับอะไร
	var places: Array = WQData.places.duplicate()
	places.sort_custom(func(a, b): return float(a.x) < float(b.x))
	for pl in places:
		_list.add_child(_row(p, pl))


func _row(p, pl: Dictionary) -> Control:
	var id := String(pl.id)
	var here: bool = String(p.place) == id
	var hours: int = p.travel_cost(id)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)

	var btn := Button.new()
	# กว้างพอให้ชื่อสถานที่ที่ยาวที่สุด ("ศูนย์อสังหาฯ & ตลาดธุรกิจ") ยังเหลือที่ให้ไอคอน
	# ถ้าแคบกว่านี้ Godot จะบีบไอคอนของแถวนั้นจนหายไปเลย เหลือแค่แถวอื่นที่มีไอคอน
	btn.custom_minimum_size = Vector2(275, 0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# ไอคอนต้องผ่าน WQIcon เสมอ (กฎ world/ ข้อ 8) — อีโมจิของหลายสถานที่เป็นขาวดำ
	# (🎓 🏢 💻 🏋️ 💍 🛒) แล้วจะเห็นเป็นกล่องดำบนพื้นเข้มของเกม ส่วนที่อบไอคอนไว้แล้วจะได้รูปจริง
	var has_icon := WQIcon.decorate_button(btn, id)
	var head_text: String = String(pl.name) if has_icon \
		else "%s %s" % [String(pl.icon), String(pl.name)]
	if here:
		btn.text = "%s — อยู่ที่นี่" % head_text
		btn.disabled = true
	else:
		# ราคาเป็นชั่วโมงต้องอยู่บนปุ่มเสมอ (กฎ 12.2.3)
		btn.text = "%s — %d ชม." % [head_text, hours]
		btn.disabled = not p.can_spend(hours)
		btn.tooltip_text = String(pl.desc)
		btn.pressed.connect(func(): travel_requested.emit(id))
	head.add_child(btn)

	var acts := Label.new()
	acts.text = _acts_text(p, pl)
	acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acts.add_theme_font_size_override("font_size", 12)
	acts.add_theme_color_override("font_color", HERE if here else DIM)
	head.add_child(acts)
	box.add_child(head)

	var note := _note_text(p, pl, hours, here)
	if note != "":
		var l := Label.new()
		l.text = "   " + note
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color",
			WARN if not p.can_spend(hours) and not here else GOOD)
		box.add_child(l)
	return box


## "ทำอะไรได้ที่นี่" พร้อมราคาชั่วโมงของแต่ละอย่าง — ราคามาจาก core ไม่ใช่อ่าน cfg เอง
func _acts_text(p, pl: Dictionary) -> String:
	var out: Array = []
	for a in pl.acts:
		var act := String(a)
		var label: String = ACT_LABEL.get(act, act)
		var cost: int = p.act_cost(act)
		if cost > 0: label += " %d ชม." % cost
		elif cost < 0: label += " %s" % _pack_range(act)
		out.append(label)
	return " · ".join(out)


## ฟิตเนสกับรีสอร์ตราคาขึ้นกับแพ็กเกจ — โชว์เป็นช่วงจากรายการแพ็กเกจจริงใน data
func _pack_range(act: String) -> String:
	var packs: Array = WQData.gym_packs if act == "gym" else WQData.resort_packs
	if packs.is_empty(): return ""
	var lo := 99999
	var hi := 0
	for pk in packs:
		lo = mini(lo, int(pk.hours))
		hi = maxi(hi, int(pk.hours))
	return "%d ชม." % lo if lo == hi else "%d–%d ชม." % [lo, hi]


## คำใบ้ตามสถานการณ์ (กฎ 12.2.6) — พูดเฉพาะเรื่องที่เกี่ยวกับที่นี่ตอนนี้จริงๆ
func _note_text(p, pl: Dictionary, hours: int, here: bool) -> String:
	if here: return ""

	# อุปกรณ์ตัดความจำเป็นในการเดินทางทิ้งไปเลย — ต้องบอก ไม่งั้นผู้เล่นเสียเวลาไปฟรีๆ
	var covered: Array = []
	for a in pl.acts:
		var act := String(a)
		if not DEVICE_SHORTCUT.has(act): continue
		if p.has_device(String(DEVICE_SHORTCUT[act])):
			covered.append(String(ACT_LABEL.get(act, act)))
	if covered.size() > 0:
		var dev: Dictionary = WQData.device(String(DEVICE_SHORTCUT[String(pl.acts[0])])) \
			if DEVICE_SHORTCUT.has(String(pl.acts[0])) else {}
		return "%s มี%sแล้ว — %s ทำจากที่ไหนก็ได้ ไม่ต้องเดินทางมา" % [
			String(dev.get("icon", "✔")), String(dev.get("name", "อุปกรณ์")),
			" · ".join(covered)]

	if not p.can_spend(hours):
		return "เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d ชม.)" % [hours, p.hours]
	return ""
