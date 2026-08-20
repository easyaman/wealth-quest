class_name WQTimeBudget
extends PanelContainer
## ⏳ งบเวลาประจำเดือน — วิดเจ็ตแรกของ UI จริง (บทที่ 12 ของ GDD)
##
## กฎการนำเสนอข้อ 12.2.2: **แถบงบเวลาต้องเป็นภาพเดียว**
## ให้ผู้เล่นเห็นว่าชีวิตหมดไปกับอะไรก่อน แล้วค่อยเห็นว่าเหลืออะไร
## ถ้าโชว์แต่ "เหลือ 144 ชม." ผู้เล่นจะไม่มีทางรู้ว่าตัวเลขนั้นมาจากไหน และปรับอะไรได้บ้าง
##
## **ปุ่มการนอนกับอาหารอยู่ในแผงนี้ ไม่ได้อยู่ในแผง "ลงมือทำ"** เพราะสองอย่างนี้ไม่ใช่
## การกระทำที่กินเวลา แต่เป็น **ตัวกำหนดรูปร่างของแถบข้างบน** — นอน 5 หรือ 8 ชม./คืน
## ต่างกัน 90 ชม./เดือน ผู้เล่นต้องเห็นแถบขยับตอนกดเลือก ไม่ใช่กดที่แผงอื่นแล้วเดาเอา
##
## แปะกับผู้เล่นด้วย bind(player) แล้ววิดเจ็ตจะ subscribe สัญญาณ changed เอง
## (กฎเหล็กข้อ 5 — ห้าม redraw ทุกเฟรม)

const SEG_COLORS := {
	"sleep": Color("5a7fc9"), "work": Color("c9962e"), "commute": Color("a05ac9"),
	"food": Color("5ac97a"), "chores": Color("6c8199"), "child": Color("ff9ad1"),
	"free": Color("7fd8ff"),
}
const BAR_BG := Color("0d1a26")
const BAR_BORDER := Color("3d5c80")
const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const GOOD := Color("7ee08a")
const ACCENT := Color("7fd8ff")
const OPT_BTN_W := 275.0     ## เท่าปุ่มของแผงเดินทาง/แผงลงมือทำ — คอลัมน์เดียวกัน ขอบต้องตรงกัน

var _player = null
var _title: Label
var _committed: Label
var _bar: _StackedBar
var _legend: HFlowContainer
var _eff: Label
var _usable: Label
var _notes: VBoxContainer
var _left: WQStatBar
var _life: VBoxContainer         ## ส่วนตัวเลือกการนอน/อาหาร
var _sleep_head: Label
var _food_head: Label
var _sleep_rows: Array = []      ## [{btn, desc}] — สร้างครั้งเดียวแล้วอัปเดตข้อความ ไม่สร้างใหม่
var _food_rows: Array = []


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
	_committed = _dim_label("")
	_committed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_committed)
	col.add_child(head)

	_bar = _StackedBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	col.add_child(_bar)

	_legend = HFlowContainer.new()
	_legend.add_theme_constant_override("h_separation", 12)
	col.add_child(_legend)

	var foot := HBoxContainer.new()
	_eff = _dim_label("")
	_eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_eff)
	_usable = Label.new()
	_usable.add_theme_color_override("font_color", ACCENT)
	_usable.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(_usable)
	col.add_child(foot)

	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 2)
	col.add_child(_notes)

	# แถบ "เหลือเท่าไหร่" ใช้ WQStatBar ตัวเดียวกับทั้งเกม (ART-DIRECTION 2.5)
	# ไม่ทำแถบเฉพาะกิจของตัวเองอีก เพื่อให้ผู้เล่นอ่านแถบเป็นครั้งเดียวแล้วใช้ได้ทุกหน้า
	_left = WQStatBar.new()
	col.add_child(_left)

	_life = VBoxContainer.new()
	_life.add_theme_constant_override("separation", 3)
	col.add_child(_life)


## ผูกกับผู้เล่นคนหนึ่ง — เรียกซ้ำได้เมื่อสลับผู้เล่น จะถอดสัญญาณเดิมให้เอง
func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(refresh):
		_player.changed.disconnect(refresh)
	_player = player
	if _player != null:
		_player.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var p = _player
	if p == null: return
	var total: int = int(WQData.cfg.hours_per_month)

	# เรียงตามลำดับที่ชีวิตถูกหักไปจริง: นอน → งาน → เดินทาง → กิน → ธุระ → ลูก → ที่เหลือ
	var segs: Array = [
		["sleep", int(p.sleep_opt().hours), "นอน"],
		["work", p.get_work_hours(), "ทำงาน"],
		["commute", p.get_commute_hours(), "เดินทางไปงาน"],
		["food", int(p.food_opt().hours), "กินข้าว"],
		["chores", int(WQData.cfg.chores_hours), "ธุระ"],
		["child", p.child_hours, "เลี้ยงลูก"],
		["free", p.get_raw_free_hours(), "เวลาว่าง"],
	]
	var shown: Array = []
	for s in segs:
		if int(s[1]) > 0: shown.append(s)

	_title.text = "⏳ งบเวลาเดือนนี้ — %d ชั่วโมง" % total
	_committed.text = "ผูกมัดไปแล้ว %d ชม." % p.get_committed_hours()

	_bar.segments = shown.map(func(s): return {"frac": float(s[1]) / float(total), "color": SEG_COLORS[s[0]]})
	_bar.queue_redraw()

	_clear(_legend)
	for s in shown:
		_legend.add_child(_chip(SEG_COLORS[s[0]], "%s %d ชม." % [s[2], int(s[1])]))

	var eff: float = p.get_efficiency()
	_eff.text = "เวลาว่างดิบ × ประสิทธิภาพ %d%%" % roundi(eff * 100.0)
	_usable.text = "%d ชม. ใช้ได้จริง" % p.get_hours_max()

	_clear(_notes)
	if p.time_penalty > 0:
		_note("⚠ ถูกหักเวลาจากการเจ็บป่วย %d ชม." % p.time_penalty, WARN)
	if p.bonus_hours > 0:
		_note("✦ โบนัสจากการทอยเต๋าเริ่มเกม +%d ชม." % p.bonus_hours, GOOD)
	if p.travel_used > 0:
		_note("🚗 เดือนนี้เสียเวลาไปกับการเดินทางแล้ว %d ชม." % p.travel_used, SEG_COLORS["commute"])
	if p.vehicle != "public":
		var veh: Dictionary = p.get_veh()
		_note("%s ทำให้เวลาไปทำงานเหลือ %d ชม. (จาก %d)" %
			[veh.name, p.get_commute_hours(), int(p.job.commute)], GOOD,
			String(p.vehicle), String(veh.icon))
	if p.place != "home":
		_note("ตั้งค่าการนอนและอาหารได้ที่ บ้าน เท่านั้น (เดินทาง %d ชม.)" %
			p.travel_cost("home"), WARN, "home", "🏠")

	var hmax: int = p.get_hours_max()
	_left.set_stat("เหลือใช้เดือนนี้", "%d / %d ชม." % [p.hours, hmax],
		float(p.hours) / float(hmax) if hmax > 0 else 0.0, WQPalette.TIME)

	_refresh_lifestyle(p)


# ========== ตัวเลือกการนอน / อาหาร ==========
## **สร้างปุ่มครั้งเดียวแล้วอัปเดตแต่ข้อความ** — ต่างจากแผงอื่นที่สร้างใหม่ทั้งชุดแบบ deferred
## เพราะแผงนี้ต่อสัญญาณ `changed` เข้ากับ refresh() ตรงๆ การกดปุ่มจึงวิ่งกลับมาถึงที่นี่ทันที
## ขณะที่ปุ่มนั้นยังส่งสัญญาณ pressed อยู่ — free() ตอนนั้น Godot ปฏิเสธแล้วฟังก์ชันหลุดกลางคัน
## (เหตุผลเดียวกับที่ ui/main.gd::_close_screen อธิบายไว้)
## ทำแบบนี้ได้เพราะรายการตัวเลือกมาจาก data ซึ่งไม่เปลี่ยนระหว่างเกม
func _refresh_lifestyle(p) -> void:
	if _sleep_rows.is_empty(): _build_lifestyle()
	# ที่บ้านเท่านั้น (core บังคับไว้แล้ว) — ปุ่มจึงต้องเทาให้เห็นก่อน ไม่ใช่ให้กดแล้วเด้ง error
	var at_home: bool = p.can_do_here("sleep")

	_sleep_head.text = "😴 นอนกี่ชั่วโมง — %s ต้องการ %d ชม./คืน นอนน้อยกว่านี้โดนปรับสองชั้น" % [
		String(p.job.name), p.get_sleep_need()]
	for i in _sleep_rows.size():
		var t: Dictionary = p.sleep_terms(i)
		var row: Dictionary = _sleep_rows[i]
		var btn: Button = row.btn
		btn.text = String(t.label) + ("  ✓ ใช้อยู่" if t.current else "")
		btn.disabled = not at_home or t.current
		btn.tooltip_text = String(t.note)
		var bits: Array = ["%d ชม./เดือน" % int(t.hours), "สุขภาพ %+.1f" % float(t.health)]
		if float(t.eff_penalty) > 0.0:
			bits.append("ประสิทธิภาพ −%d%%" % roundi(float(t.eff_penalty) * 100.0))
		if int(t.debt) > 0:
			bits.append("นอนขาดเกณฑ์ %d ชม./คืน" % int(t.debt))
		var desc: Label = row.desc
		desc.text = " · ".join(bits)
		desc.add_theme_color_override("font_color",
			GOOD if t.current else (WARN if int(t.debt) > 0 else DIM))

	_food_head.text = "🍽️ กินอย่างไร — สามมิติที่ขัดกันเอง: เงิน / เวลา / สุขภาพ"
	for row in _food_rows:
		var t: Dictionary = p.food_terms(String(row.id))
		var btn: Button = row.btn
		btn.text = "%s %s%s" % [String(t.icon), String(t.label), "  ✓ ใช้อยู่" if t.current else ""]
		btn.disabled = not at_home or t.current
		btn.tooltip_text = String(t.note)
		var desc: Label = row.desc
		desc.text = "%d ชม./เดือน · %s฿/เดือน · สุขภาพ %+.1f" % [
			int(t.hours), WQFmt.n(float(t.cost)), float(t.health)]
		desc.add_theme_color_override("font_color", GOOD if t.current else DIM)


func _build_lifestyle() -> void:
	_sleep_head = _dim_label("")
	_sleep_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sleep_head.add_theme_font_size_override("font_size", 13)
	_life.add_child(_sleep_head)
	for i in WQData.cfg.sleep_options.size():
		var row := _option_row()
		(row.btn as Button).pressed.connect(_pick_sleep.bind(i))
		_sleep_rows.append(row)
		_life.add_child(row.box)

	_food_head = _dim_label("")
	_food_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_food_head.add_theme_font_size_override("font_size", 13)
	_life.add_child(_food_head)
	for f in WQData.cfg.food_options:
		var row := _option_row()
		row["id"] = String(f.id)
		(row.btn as Button).pressed.connect(_pick_food.bind(String(f.id)))
		_food_rows.append(row)
		_life.add_child(row.box)


## แถวหนึ่ง = [ปุ่มตัวเลือก][ผลของตัวเลือกนั้น] — ความกว้างปุ่มเท่ากับแผงอื่นในคอลัมน์เดียวกัน
func _option_row() -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(OPT_BTN_W, 0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(btn)
	var desc := Label.new()
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	box.add_child(desc)
	return {"box": box, "btn": btn, "desc": desc, "id": ""}


func _pick_sleep(i: int) -> void:
	if _player != null: _player.set_sleep(i)


func _pick_food(id: String) -> void:
	if _player != null: _player.set_food(id)


## ลบลูกทิ้งทันที ไม่ใช้ queue_free เพราะ refresh ถูกเรียกได้หลายรอบในเฟรมเดียว
## (สัญญาณ changed ยิงทุกการกระทำ) แล้วโหนดที่รอลบอยู่จะยังนับเป็นลูกอยู่ ทำให้รายการซ้อนกัน
func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()


func _dim_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", DIM)
	return l


## หมายเหตุหนึ่งบรรทัด — ใส่ไอคอนนำหน้าได้ถ้าบรรทัดนั้นพูดถึงของที่มีโมเดล
func _note(text: String, color: Color, icon_id := "", icon_emoji := "") -> void:
	if icon_id != "" or icon_emoji != "":
		var row := WQIcon.row(icon_id, icon_emoji, text, 16)
		var l := row.get_child(1) as Label
		l.add_theme_color_override("font_color", color)
		l.add_theme_font_size_override("font_size", 14)
		_notes.add_child(row)
		return
	var lbl := _dim_label(text)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_child(lbl)


func _chip(color: Color, text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var dot := _Swatch.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(9, 9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(dot)
	box.add_child(_dim_label(text))
	return box


## แถบเดียวที่แบ่งเป็นช่วงตามสัดส่วนของ 720 ชม. — "ชีวิตหมดไปกับอะไร" ในภาพเดียว
class _StackedBar extends Control:
	var segments: Array = []

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, WQTimeBudget.BAR_BG)
		var x := 0.0
		for s in segments:
			var w: float = float(s.frac) * size.x
			draw_rect(Rect2(x, 0, w, size.y), s.color)
			x += w
		draw_rect(r, WQTimeBudget.BAR_BORDER, false, 1.0)


class _Swatch extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), color)
