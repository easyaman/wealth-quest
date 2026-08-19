class_name WQShop
extends PanelContainer
## ร้านพาหนะและอุปกรณ์ที่ห้างสรรพสินค้า (GDD ข้อ 3A.2)
##
## เกมนี้ตั้งกับดักไว้ตรงนี้: รถหรูเร็วกว่ารถใหม่แค่ 12% แต่แพงกว่าเกือบ 3 เท่า
## หน้าที่ของแผงนี้คือ **โชว์ของให้ดูน่าอยาก แล้วให้ตัวเลขเป็นคนเบรก** — ไม่ใช่ห้ามผู้เล่นซื้อ
## ผู้เล่นต้องเห็นพร้อมกันว่า "ได้เวลาคืนกี่ชั่วโมง" กับ "จ่ายเพิ่มเดือนละเท่าไหร่"
##
## ตัวเลขทุกตัวมาจาก WQPlayer.vehicle_terms() / device_terms() ซึ่งเป็น pure function ใน core
## แผงนี้ไม่คำนวณสูตรเกมเอง และไม่แก้ state — การซื้อยังไปผ่าน p.buy_vehicle() / p.buy_device()

signal picked(kind: String, id: String)   ## เลือกดูของชิ้นไหน → แท่นโชว์เปลี่ยนตาม

const DIM := Color("8fa6bd")
const GOOD := Color("7ee08a")
const BAD := Color("ff8080")
const GOLD := Color("ffd76a")

var _p = null
var _sel_kind := "vehicles"
var _sel_id := ""
var _title: Label
var _list: VBoxContainer
var _rebuild_queued := false


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

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)


func bind(player) -> void:
	if _p == player: return
	if _p != null and _p.changed.is_connected(_queue_rebuild):
		_p.changed.disconnect(_queue_rebuild)
	_p = player
	if _p != null:
		_p.changed.connect(_queue_rebuild)
	if _sel_id == "" and _p != null: _sel_id = String(_p.vehicle)
	_rebuild()


## เหมือน deal_market — ห้ามสร้างใหม่ทันทีระหว่างที่ปุ่มกำลังส่งสัญญาณอยู่
func _queue_rebuild() -> void:
	if _rebuild_queued: return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for c in _list.get_children():
		_list.remove_child(c)
		c.free()
	if _p == null: return

	var at_shop: bool = _p.place == "mall"
	_title.text = "🛒 ร้านพาหนะ & อุปกรณ์" + ("" if at_shop else "  (ต้องไปที่ห้างก่อน)")
	_title.add_theme_color_override("font_color", Color.WHITE if at_shop else DIM)

	for v in WQData.vehicles:
		_list.add_child(_vehicle_row(String(v.id), v))
	for d in WQData.devices:
		_list.add_child(_device_row(String(d.id), d))


func _vehicle_row(id: String, v: Dictionary) -> Control:
	var t: Dictionary = _p.vehicle_terms(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(WQIcon.make(id, String(v.icon), 22))

	var name_l := Label.new()
	name_l.text = String(v.name) + ("  ✓ ใช้อยู่" if t.is_current else "")
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color", GOOD if t.is_current else Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)

	# สองตัวเลขที่ต้องเห็นคู่กันเสมอ — ได้เวลาคืนเท่าไหร่ แลกกับจ่ายเพิ่มเท่าไหร่
	var saved := Label.new()
	saved.text = "%+d ชม./ด." % int(t.hours_saved)
	saved.add_theme_font_size_override("font_size", 12)
	saved.add_theme_color_override("font_color",
		GOOD if int(t.hours_saved) > 0 else (BAD if int(t.hours_saved) < 0 else DIM))
	row.add_child(saved)

	var cost := Label.new()
	cost.text = "%+s฿/ด." % WQFmt.n(float(t.upkeep_delta))
	cost.add_theme_font_size_override("font_size", 12)
	cost.add_theme_color_override("font_color", BAD if float(t.upkeep_delta) > 0 else GOOD)
	row.add_child(cost)

	row.add_child(_look_button("vehicles", id))
	row.add_child(_buy_button(id, t, func(): _p.buy_vehicle(id)))
	return row


func _device_row(id: String, d: Dictionary) -> Control:
	var t: Dictionary = _p.device_terms(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(WQIcon.make(id, String(d.icon), 22))

	var name_l := Label.new()
	name_l.text = String(d.name) + ("  ✓ มีแล้ว" if t.owned else "")
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color", GOOD if t.owned else Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)

	var price := Label.new()
	price.text = WQFmt.m(float(t.price)) + "฿"
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", GOLD if t.affordable else BAD)
	row.add_child(price)

	var up := Label.new()
	up.text = "+%s฿/ด." % WQFmt.n(float(t.upkeep))
	up.add_theme_font_size_override("font_size", 12)
	up.add_theme_color_override("font_color", DIM)
	row.add_child(up)

	row.add_child(_look_button("devices", id))
	var b := Button.new()
	b.text = "มีแล้ว" if t.owned else "ซื้อ"
	b.disabled = t.owned or not t.affordable or not t.at_shop
	if not b.disabled:
		b.pressed.connect(func(): _p.buy_device(id))
	row.add_child(b)
	return row


func _look_button(kind: String, id: String) -> Button:
	var b := Button.new()
	b.text = "ดู"
	b.pressed.connect(func():
		_sel_kind = kind
		_sel_id = id
		picked.emit(kind, id))
	return b


func _buy_button(id: String, t: Dictionary, action: Callable) -> Button:
	var b := Button.new()
	if t.is_current:
		b.text = "ใช้อยู่"
		b.disabled = true
	elif t.is_downgrade:
		# ขายลงมาคันถูกกว่าได้เงินคืน ไม่ต้องมีเงินดาวน์ — ต้องบอกให้ชัดว่าได้คืนเท่าไหร่
		b.text = "ขายคืน +%s฿" % WQFmt.m(float(t.refund))
		b.disabled = not t.at_shop
	else:
		b.text = "ดาวน์ %s฿" % WQFmt.m(float(t.down))
		b.disabled = not t.affordable or not t.at_shop
	if not b.disabled:
		b.pressed.connect(action)
	return b


## แถบสถิติของพาหนะสำหรับแท่นโชว์ (Sprint B ข้อ 5)
## ตัวหารของแต่ละแถบเป็นเรื่องการนำเสนอ ส่วนตัวเลขมาจาก core ทั้งหมด
static func vehicle_stats(p, id: String) -> Array:
	var t: Dictionary = p.vehicle_terms(id)
	if t.is_empty(): return []
	var commute_now: int = maxi(1, int(p.job.commute))
	return [
		# แถบยิ่งยาว = ยิ่งเร็ว (1 − factor) เพื่อให้ "ยาวกว่า = ดีกว่า" เหมือนแถบอื่นทั้งเกม
		{"label": "ความเร็วในการเดินทาง", "value": 1.0 - float(t.factor), "max": 0.75,
			"text": "×%.2f เวลาเดิม" % t.factor, "color": WQPalette.TIME},
		{"label": "ค่าใช้จ่าย/เดือน", "value": float(t.upkeep), "max": _max_upkeep(),
			"text": WQFmt.n(float(t.upkeep)) + "฿", "color": WQPalette.MONEY_DARK},
		{"label": "เวลาที่ได้คืน/เดือน", "value": maxf(0.0, float(t.hours_saved)),
			"max": float(commute_now),
			"text": "%+d ชม. (จาก %d)" % [int(t.hours_saved), commute_now],
			"color": WQPalette.WIN if int(t.hours_saved) > 0 else WQPalette.DANGER},
	]


static func device_stats(p, id: String) -> Array:
	var t: Dictionary = p.device_terms(id)
	if t.is_empty(): return []
	return [
		{"label": "ราคา", "value": float(t.price), "max": maxf(float(t.price), p.cash),
			"text": WQFmt.m(float(t.price)) + "฿",
			"color": WQPalette.MONEY if t.affordable else WQPalette.DANGER},
		{"label": "ค่าใช้จ่าย/เดือน", "value": float(t.upkeep), "max": _max_upkeep(),
			"text": WQFmt.n(float(t.upkeep)) + "฿", "color": WQPalette.MONEY_DARK},
	]


## เพดานค่าใช้จ่ายอ่านจาก data จริง ไม่ตั้งตัวเลขลอยๆ ไว้ในโค้ด
static func _max_upkeep() -> float:
	var mx := 0.0
	for v in WQData.vehicles: mx = maxf(mx, float(v.upkeep))
	return mx if mx > 0.0 else 1.0
