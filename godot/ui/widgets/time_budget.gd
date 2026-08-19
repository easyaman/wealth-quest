class_name WQTimeBudget
extends PanelContainer
## ⏳ งบเวลาประจำเดือน — วิดเจ็ตแรกของ UI จริง (บทที่ 12 ของ GDD)
##
## กฎการนำเสนอข้อ 12.2.2: **แถบงบเวลาต้องเป็นภาพเดียว**
## ให้ผู้เล่นเห็นว่าชีวิตหมดไปกับอะไรก่อน แล้วค่อยเห็นว่าเหลืออะไร
## ถ้าโชว์แต่ "เหลือ 144 ชม." ผู้เล่นจะไม่มีทางรู้ว่าตัวเลขนั้นมาจากไหน และปรับอะไรได้บ้าง
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

var _player = null
var _title: Label
var _committed: Label
var _bar: _StackedBar
var _legend: HFlowContainer
var _eff: Label
var _usable: Label
var _notes: VBoxContainer
var _left: WQStatBar


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
