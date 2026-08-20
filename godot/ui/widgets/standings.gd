class_name WQStandings
extends PanelContainer
## 🏆 อันดับในแมตช์ — คอลัมน์ซ้ายบนสุดตามเลย์เอาต์ในบทที่ 12 ของ GDD
##
## เกมนี้ไม่ได้วัดกันที่ "ใครมีเงินเยอะสุด" แต่วัดที่ **ใครถึงความฝันก่อน**
## ตารางอันดับจึงต้องโชว์ระยะทางที่เหลือของแต่ละคน ไม่ใช่กองเงิน
## ถ้าโชว์ความมั่งคั่งเป็นตัวเรียง ผู้เล่นจะไล่สะสมเงินแทนที่จะสร้างรายได้จากทรัพย์สิน
## ซึ่งตรงข้ามกับสิ่งที่เกมทั้งเกมพยายามสอน
##
## แต่ละคนอยู่คนละด่าน ตัวเลขที่มีความหมายจึงต่างกัน (กฎ 12.2.6 — บอกเฉพาะเรื่องที่ตรงกับสถานการณ์):
##   ด่าน 1  อิสรภาพ % (รายได้จากทรัพย์สิน ÷ รายจ่าย)
##   ด่าน 2  ความคืบหน้าความฝัน + บอกว่าข้อไหนคือตัวถ่วง
##   จบแล้ว  อันดับและเดือนที่ทำสำเร็จ
##
## ลำดับมาจาก `WQMatch.standings()` — ที่นี่ไม่จัดอันดับเอง

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const ME := Color("ffffff")

var _player = null
var _match: WQMatch
var _title: Label
var _rows: VBoxContainer


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	col.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	col.add_child(_rows)


## ผูกกับผู้เล่นที่กำลังเล่น + แมตช์ — เรียกซ้ำได้ จะถอดสัญญาณเดิมให้เอง
func bind(player, match_ref: WQMatch) -> void:
	if _player == player and _match == match_ref: return
	if _player != null and _player.changed.is_connected(refresh):
		_player.changed.disconnect(refresh)
	_player = player
	if _player != null:
		_player.changed.connect(refresh)

	if _match != match_ref:
		if _match != null and _match.month_ended.is_connected(_on_month):
			_match.month_ended.disconnect(_on_month)
		_match = match_ref
		if _match != null:
			_match.month_ended.connect(_on_month)
	refresh()


func _on_month(_month: int) -> void:
	refresh()


func refresh() -> void:
	if _match == null: return
	# ห้ามใช้ 🏁 — เป็นอีโมจิขาวดำ จมหายไปกับพื้นเข้มของเกมจนเห็นเป็นกล่องเปล่า
	# (ดูหัวข้อ UI ใน godot/CLAUDE.md) 🏆 มีสีในตัวจึงใช้ได้
	_title.text = "🏆 อันดับในแมตช์ — เดือนที่ %d" % _match.month
	_clear(_rows)
	var order: Array = _match.standings()
	for i in order.size():
		_rows.add_child(_row(order[i], i + 1))


func _row(p, rank: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var mine: bool = p == _player
	var name_label := Label.new()
	# ใช้ "ชื่ออาชีพ" ไม่ใช่ไอคอนอาชีพ — อีโมจิของหลายอาชีพ (💻 🧹 💼 📊 🏢 ⚖️ 🔧) เป็นขาวดำ
	# แล้วจะเห็นเป็นกล่องดำบนพื้นเกม · ชื่ออาชีพยังบอกได้มากกว่าไอคอนด้วย
	name_label.text = "%d. %s · %s" % [rank, String(p.pname), String(p.job.get("name", ""))]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	# คนที่กำลังเล่นอยู่ต้องหาเจอในพริบตา — ใช้ความสว่าง ไม่ใช่สีใหม่
	name_label.add_theme_color_override("font_color", ME if mine else DIM)
	head.add_child(name_label)

	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", DIM)
	tag.text = _phase_tag(p)
	head.add_child(tag)
	box.add_child(head)

	box.add_child(_progress(p))
	return box


func _phase_tag(p) -> String:
	if p.bankrupt: return "ล้มละลาย"
	if p.phase >= 3: return "🏆 สำเร็จเดือนที่ %d" % int(p.dream_done)
	if p.phase == 2: return "ด่าน 2 · %s" % String(p.dream.get("name", "ความฝัน"))
	return "ด่าน 1 · สะสมทรัพย์สิน"


## แถบเดียวต่อคน — ความหมายเปลี่ยนตามด่านที่คนนั้นอยู่
func _progress(p) -> WQStatBar:
	if p.bankrupt:
		return WQStatBar.new("จบเกมแล้ว", "—", 0.0, WQPalette.DANGER)
	if p.phase >= 3:
		return WQStatBar.new("ทำความฝันสำเร็จ", "เดือนที่ %d" % int(p.dream_done),
			1.0, WQPalette.WIN)
	if p.phase == 2:
		var pr: Dictionary = p.dream_progress()
		return WQStatBar.new("ความฝัน — ตัวถ่วงคือ%s" % String(pr.worst_label),
			"%d%%" % roundi(float(pr.worst) * 100.0),
			float(pr.worst), WQPalette.WIN)
	var free: float = p.get_freedom_pct()
	return WQStatBar.new("อิสรภาพ (รายได้ทรัพย์สิน ÷ รายจ่าย)", "%.0f%%" % free,
		free / 100.0, WQPalette.MONEY)


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()
