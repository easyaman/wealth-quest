class_name WQHealthBar
extends PanelContainer
## ❤️ สุขภาพ — วิดเจ็ตเต็มรูปแบบตามบทที่ 4 ของ GDD
##
## **สุขภาพไม่ใช่ HP มันคือตัวคูณเวลา** — นั่นคือสิ่งเดียวที่วิดเจ็ตนี้ต้องสอนให้ได้
## แถบเลข 75/100 เฉยๆ ไม่บอกอะไรผู้เล่นเลย เพราะมองไม่เห็นว่าเลขนั้นไปทำอะไรกับชีวิต
## ที่นี่จึงแปลสุขภาพเป็น "ชั่วโมงที่หายไปต่อเดือน" ซึ่งเป็นหน่วยที่ผู้เล่นเจ็บจริง
##
## และต้องบอก **ทิศทาง** ด้วย ไม่ใช่แค่ตำแหน่งปัจจุบัน — กับดักใน GDD 4.1 คือสุขภาพ
## ค่อยๆ ร่วงเดือนละนิดจนเข้าโซนวิกฤตโดยไม่มีใครทันสังเกต แล้วล้มป่วยทีเดียวเสียเวลา 90 ชม.
## จึงต้องโชว์ทั้งยอดรวมที่จะเปลี่ยนสิ้นเดือน แยกเป็นรายการว่ามาจากอะไร และนับถอยหลังถึงวิกฤต
##
## กฎการนำเสนอข้อ 12.2.6: **คำใบ้เปลี่ยนตามสถานการณ์** ไม่ใช่ tooltip คงที่
## เตือนเรื่องนอนขาดเฉพาะตอนที่นอนขาดจริง เตือนทำงานหนักเฉพาะตอนที่เกินเกณฑ์จริง
##
## ตัวเลขทุกตัวมาจาก core — `health_delta()` เป็นสูตรตัวเดียวกับที่ `settle()` ใช้หักจริง
## วิดเจ็ตนี้ไม่คำนวณสูตรเกมเองแม้แต่ช่องเดียว

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const GOOD := Color("7ee08a")
const DANGER_BELOW := 40.0        ## ต่ำกว่านี้แถบเปลี่ยนเป็นสีอันตราย (ตรงกับเกณฑ์เดิมใน main.gd)

var _player = null
var _bar: WQStatBar
var _cost: Label
var _trend: Label
var _parts: VBoxContainer
var _event_mul: Label
var _notes: VBoxContainer


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# แถบหลักใช้ WQStatBar ตัวเดียวกับทั้งเกม ไม่ทำแถบเฉพาะกิจของตัวเอง (ART-DIRECTION 2.5)
	_bar = WQStatBar.new()
	col.add_child(_bar)

	_cost = Label.new()
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cost.add_theme_font_size_override("font_size", 13)
	col.add_child(_cost)

	_trend = Label.new()
	_trend.add_theme_font_size_override("font_size", 14)
	col.add_child(_trend)

	_parts = VBoxContainer.new()
	_parts.add_theme_constant_override("separation", 1)
	col.add_child(_parts)

	_event_mul = _dim_label("")
	_event_mul.add_theme_font_size_override("font_size", 13)
	col.add_child(_event_mul)

	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 2)
	col.add_child(_notes)


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
	var band: Dictionary = p.health_band()
	var hp: float = p.health
	var color: Color = WQPalette.DANGER if hp < DANGER_BELOW else WQPalette.HEALTH

	_bar.set_stat("❤️ สุขภาพ — %s" % String(band.name), "%d / 100" % int(hp), hp / 100.0, color)

	# หัวใจของวิดเจ็ต: แปลสุขภาพเป็นชั่วโมงที่หายไป ซึ่งเป็นหน่วยที่ผู้เล่นเจ็บจริง
	var eff: float = p.get_efficiency()
	var raw: int = p.get_raw_free_hours()
	var lost: int = raw - p.get_hours_max()
	_cost.text = "สุขภาพคือตัวคูณเวลา — ประสิทธิภาพ %d%% แปลว่าเดือนนี้เวลาว่างหายไป %d ชม. จาก %d" % [
		roundi(eff * 100.0), lost, raw]
	_cost.add_theme_color_override("font_color", WARN if lost > raw / 4 else DIM)

	var dh: float = p.health_delta()
	_trend.text = "สิ้นเดือนนี้ %s /เดือน" % _signed(dh)
	_trend.add_theme_color_override("font_color", GOOD if dh >= 0.0 else WARN)

	_clear(_parts)
	for part in p.health_parts():
		var row := HBoxContainer.new()
		var l := _dim_label("   " + String(part.label))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		var v := Label.new()
		v.text = _signed(float(part.value))
		v.add_theme_font_size_override("font_size", 12)
		v.add_theme_color_override("font_color",
			GOOD if float(part.value) >= 0.0 else WARN)
		row.add_child(v)
		_parts.add_child(row)

	_event_mul.text = "น้ำหนักเหตุการณ์ร้ายด้านสุขภาพ ×%s" % _num(p.health_event_mul())

	_clear(_notes)
	_advice(p, dh)


## คำใบ้ตามสถานการณ์ (กฎ 12.2.6) — พูดเฉพาะเรื่องที่กำลังเป็นปัญหาจริงตอนนี้
func _advice(p, dh: float) -> void:
	if p.health < WQPlayer.HEALTH_CRISIS:
		_note("⛔ โซนวิกฤต — เดือนละ %d%% ที่จะล้มป่วยหนัก: หยุดงาน 1 เดือน + ค่ารักษา และเสียเวลาอีก 90 ชม." %
			roundi(WQPlayer.HEALTH_CRISIS_CHANCE * 100.0), WARN)
	else:
		var left: int = p.months_to_crisis()
		if left >= 0:
			_note("⚠ ถ้ายังใช้ชีวิตแบบนี้ อีก %d เดือนจะเข้าโซนวิกฤต" % left, WARN)

	var debt: int = p.get_sleep_debt()
	if debt > 0:
		# กับดักหลักของ GDD 4.1 — อดนอนได้ชั่วโมงดิบเพิ่ม แต่ใช้ได้จริงเพิ่มนิดเดียว
		_note("😴 นอนน้อยกว่าที่อาชีพนี้ต้องการ %d ชม./คืน — ได้เวลาว่างดิบเพิ่ม แต่ประสิทธิภาพตกจนแทบไม่เหลือกำไร"
			% debt, WARN, "home", "🏠")

	var load: int = p.get_work_load()
	if load > WQPlayer.OVERWORK_HARD:
		_note("🔥 ทำงาน %d ชม./เดือน เกิน %d — โดนหักสุขภาพหนักสุด" %
			[load, WQPlayer.OVERWORK_HARD], WARN)
	elif load > WQPlayer.OVERWORK_SOFT:
		_note("🔥 ทำงาน %d ชม./เดือน เกิน %d — เริ่มโดนหักสุขภาพจากการทำงานหนัก" %
			[load, WQPlayer.OVERWORK_SOFT], WARN)

	if p.exercise_this_month > 0:
		_note("💪 เดือนนี้ออกกำลังกายไปแล้ว %d ครั้ง" % p.exercise_this_month, GOOD, "gym", "🏋️")
	if p.rested_this_month:
		_note("🌴 เดือนนี้ได้พักผ่อนแล้ว", GOOD, "resort", "🏨")
	if dh >= 0.0 and p.health >= 85.0:
		_note("✦ สุขภาพอยู่ในโซนดีที่สุดและยังไม่ตก — ประสิทธิภาพเวลาสูงสุดเท่าที่จะทำได้", GOOD)


## +1.5 / −0.5 — ตัดทศนิยมที่ไม่จำเป็นทิ้ง ให้บรรทัดอ่านเร็ว
func _signed(v: float) -> String:
	return ("+" if v >= 0.0 else "−") + _num(absf(v))


func _num(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"): s = s.substr(0, s.length() - 1)
	if s.ends_with("."): s = s.substr(0, s.length() - 1)
	return s


## ลบลูกทิ้งทันที ไม่ใช้ queue_free เพราะ refresh ถูกเรียกได้หลายรอบในเฟรมเดียว
func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()


func _dim_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", DIM)
	return l


func _note(text: String, color: Color, icon_id := "", icon_emoji := "") -> void:
	if icon_id != "" or icon_emoji != "":
		var row := WQIcon.row(icon_id, icon_emoji, text, 16)
		var l := row.get_child(1) as Label
		l.add_theme_color_override("font_color", color)
		l.add_theme_font_size_override("font_size", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notes.add_child(row)
		return
	var lbl := _dim_label(text)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_child(lbl)
