class_name WQBanner
extends PanelContainer
## แบนเนอร์ประกาศ — 🏆 ชัยชนะ · ⛔ ภัยพิบัติที่กำลังมีผล (บทที่ 12 ของ GDD)
##
## GDD 9.3: เกม**ไม่จบ**เมื่อบอทหรือผู้เล่นอื่นทำความฝันสำเร็จ — ขึ้นแบนเนอร์ทองประกาศ
## พร้อม**อันดับที่** แล้วคนนั้นออกจากลำดับตาไป ที่เหลือเดินต่อ
## ถ้าไม่ประกาศให้ชัด ผู้เล่นจะไม่รู้เลยว่ามีคนถึงเส้นชัยไปแล้วกี่คน ซึ่งเป็นแรงกดดันหลักของโหมดแข่ง
##
## ภัยพิบัติต้องเห็นตลอดเวลาที่มันยังมีผล ไม่ใช่ขึ้นครั้งเดียวตอนเริ่มแล้วหายไป
## เพราะผลของมันอยู่ยาว 1–6 เดือน และเปลี่ยนการตัดสินใจทุกเดือนที่มันยังอยู่
##
## ซ่อนตัวเองทั้งแถบเมื่อไม่มีอะไรจะประกาศ — แบนเนอร์ว่างเปล่ากินที่บนจอโดยไม่ให้ข้อมูล

const GOLD := Color("f2b233")
const DIM := Color("8fa6bd")

var _match: WQMatch
var _rows: VBoxContainer


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	margin.add_child(_rows)


func bind(match_ref: WQMatch) -> void:
	if _match == match_ref: return
	if _match != null:
		if _match.champion_added.is_connected(_on_change):
			_match.champion_added.disconnect(_on_change)
		if _match.disaster_started.is_connected(_on_disaster):
			_match.disaster_started.disconnect(_on_disaster)
		if _match.month_ended.is_connected(_on_month):
			_match.month_ended.disconnect(_on_month)
	_match = match_ref
	if _match != null:
		_match.champion_added.connect(_on_change)
		_match.disaster_started.connect(_on_disaster)
		_match.month_ended.connect(_on_month)
	refresh()


func _on_change(_entry: Dictionary) -> void:
	refresh()


func _on_disaster(_def: Dictionary) -> void:
	refresh()


func _on_month(_m: int) -> void:
	refresh()


func refresh() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	if _match == null:
		visible = false
		return

	for entry in _match.champions:
		var l := Label.new()
		l.text = "🏆 อันดับ %d — %s (%s) ทำความฝัน %s สำเร็จในเดือนที่ %d" % [
			int(entry.rank), String(entry.name), String(entry.job),
			String(entry.dream), int(entry.month)]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", GOLD)
		l.add_theme_font_size_override("font_size", 14)
		_rows.add_child(l)

	for d in _match.active_disasters:
		var def: Dictionary = d.def
		var l2 := Label.new()
		l2.text = "⛔ %s %s — %s (เหลืออีก %d เดือน)" % [
			String(def.icon), String(def.name), String(def.desc), int(d.left)]
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.add_theme_color_override("font_color", WQPalette.DANGER)
		l2.add_theme_font_size_override("font_size", 13)
		_rows.add_child(l2)

	visible = _rows.get_child_count() > 0
