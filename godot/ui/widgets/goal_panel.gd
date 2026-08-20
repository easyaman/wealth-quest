class_name WQGoalPanel
extends PanelContainer
## 🎯 เป้าหมายด่าน — คอลัมน์ซ้ายตามเลย์เอาต์บทที่ 12
##
## เกมนี้มีสองด่านที่วัดกันคนละเกณฑ์ ถ้าไม่บอกให้ชัดว่าตอนนี้กำลังวิ่งไปหาอะไร
## ผู้เล่นจะไล่สะสมเงินอย่างเดียวซึ่งไม่ใช่เงื่อนไขชนะของด่านไหนเลย
##   ด่าน 1  รายได้จากทรัพย์สิน ≥ รายจ่ายรวม → ออกจากสนามแข่งหนู
##   ด่าน 2  ต้องครบ **ทั้งสอง** เงื่อนไข: ความมั่งคั่งสุทธิ และ รายได้ต่อเดือน (GDD 9.2)
##
## ที่ต้องมีสองเงื่อนไขในด่าน 2 เพราะถ้าขอแค่เงินก้อน ด่าน 2 จะกลายเป็นการกดสะสมอย่างเดียว
## การบังคับให้มีรายได้ต่อเดือนด้วยทำให้บทเรียนเรื่องกระแสเงินสดทำงานต่อจนจบเกม

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var _player = null
var _title: Label
var _body: VBoxContainer
var _claim: Button
var _rebuilding := false


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	col.add_child(_title)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	col.add_child(_body)

	_claim = Button.new()
	_claim.text = "🏆 ทำความฝันให้เป็นจริง"
	_claim.visible = false
	_claim.pressed.connect(_on_claim)
	col.add_child(_claim)


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(_queue_rebuild):
		_player.changed.disconnect(_queue_rebuild)
	_player = player
	if _player != null:
		_player.changed.connect(_queue_rebuild)
	refresh()


## ปุ่มอ้างสิทธิ์ความฝันอยู่ในแผงนี้ ห้าม free() มันทิ้งระหว่างที่มันกำลังส่งสัญญาณ pressed
func _queue_rebuild() -> void:
	if _rebuilding: return
	_rebuilding = true
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_rebuilding = false
	refresh()


func _on_claim() -> void:
	if _player != null: _player.claim_dream()


func refresh() -> void:
	var p = _player
	if p == null: return
	for c in _body.get_children():
		_body.remove_child(c)
		c.free()
	_claim.visible = false

	if p.phase >= 3:
		_title.text = "🏆 ทำความฝันสำเร็จแล้ว"
		_body.add_child(_line("%s %s — สำเร็จในเดือนที่ %d" % [
			String(p.dream.get("icon", "")), String(p.dream.get("name", "")),
			int(p.dream_done)], WQPalette.WIN))
		return

	if p.phase == 2:
		_title.text = "🎯 ด่าน 2 — %s %s" % [
			String(p.dream.get("icon", "")), String(p.dream.get("name", ""))]
		var pr: Dictionary = p.dream_progress()
		_body.add_child(WQStatBar.new("ความมั่งคั่งสุทธิ",
			"%s / %s฿" % [WQFmt.m(p.get_net_worth()), WQFmt.m(float(p.dream.cost))],
			float(pr.wealth), WQPalette.MONEY))
		_body.add_child(WQStatBar.new("รายได้จากทรัพย์สินต่อเดือน",
			"%s / %s฿" % [WQFmt.n(p.get_passive_income()), WQFmt.n(float(p.dream.passiveReq))],
			float(pr.income), WQPalette.WIN))
		_body.add_child(_line("ต้องครบทั้งสองเงื่อนไข — ตอนนี้ตัวถ่วงคือ%s" % String(pr.worst_label),
			DIM))
		_claim.visible = p.can_claim_dream()
		return

	_title.text = "🎯 ด่าน 1 — ออกจากสนามแข่งหนู"
	var inc: float = p.get_passive_income()
	var exp: float = p.get_total_expenses()
	_body.add_child(WQStatBar.new("รายได้จากทรัพย์สิน ÷ รายจ่ายรวม",
		"%s / %s฿" % [WQFmt.n(inc), WQFmt.n(exp)],
		inc / maxf(1.0, exp), WQPalette.MONEY))
	if p.pending_dream:
		# ผ่านเกณฑ์แล้วแต่ยังเข้าด่าน 2 ไม่ได้ ต้องบอกตามตรงว่าติดตรงไหน
		_body.add_child(_line(
			"ผ่านเกณฑ์แล้ว — แต่หน้าจอทอยเต๋าสุ่มความฝัน (GDD บทที่ 9) ยังไม่ได้ทำ", GOLD))
	else:
		_body.add_child(_line("รายได้จากทรัพย์สินต้องคลุมรายจ่ายให้หมดก่อน จึงจะได้ทอยความฝัน",
			DIM))


func _line(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 12)
	return l
