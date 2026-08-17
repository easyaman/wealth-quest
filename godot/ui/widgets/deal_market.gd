class_name WQDealMarket
extends PanelContainer
## ตลาดดีล — ของกลางของทั้งโต๊ะ ใครถึงก่อนได้ก่อน
## ถือ WQDealCard หลายใบ และเป็นคนเดียวที่รู้ว่าต้องสร้างการ์ดใหม่เมื่อไหร่

const DIM := Color("8fa6bd")
const GOOD := Color("7ee08a")
const BAD := Color("ff8080")

var _p = null
var _match: WQMatch
var _title: Label
var _index: Label
var _grid: HFlowContainer
var _rebuild_queued := false


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
	_title.text = "ตลาดดีล (ของกลาง — ใครถึงก่อนได้ก่อน)"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_index = Label.new()
	_index.add_theme_color_override("font_color", DIM)
	_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_index)
	col.add_child(head)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)


func bind(player, match_ref: WQMatch) -> void:
	if _p == player and _match == match_ref: return
	if _p != null and _p.changed.is_connected(_queue_rebuild):
		_p.changed.disconnect(_queue_rebuild)
	_p = player
	_match = match_ref
	if _p != null:
		_p.changed.connect(_queue_rebuild)
	_rebuild()


## การ์ดถูกสร้างใหม่ทั้งแผงเมื่อมีอะไรเปลี่ยน แต่ห้ามทำทันทีระหว่างที่ปุ่มบนการ์ดกำลังส่งสัญญาณอยู่
## (จะเป็นการลบปุ่มทิ้งกลางคัน) จึงเลื่อนไปสิ้นเฟรม และกันไม่ให้คิวซ้อนกันหลายรอบ
func _queue_rebuild() -> void:
	if _rebuild_queued: return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for c in _grid.get_children():
		_grid.remove_child(c); c.free()
	if _p == null or _match == null: return

	var mi: float = _match.market_index
	_index.text = "ดัชนีตลาด %d" % roundi(mi * 100.0)
	_index.add_theme_color_override("font_color", GOOD if mi >= 1.0 else BAD)

	for d in _match.deals:
		var card := WQDealCard.new()
		card.custom_minimum_size = Vector2(236, 0)
		_grid.add_child(card)
		card.bind(_p, d)
		card.acted.connect(_queue_rebuild)
