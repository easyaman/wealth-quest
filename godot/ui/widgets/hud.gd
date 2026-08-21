class_name WQHud
extends PanelContainer
## แถบ HUD บนสุด — บรรทัดเดียวที่ตอบว่า "ตอนนี้ฉันอยู่ตรงไหนของเกม" (บทที่ 12 ของ GDD)
##
## ห้าตัวเลขนี้คือสิ่งที่ผู้เล่นต้องเห็นตลอดเวลาโดยไม่ต้องเลื่อนหา:
## เดือน · เงินสด · ความมั่งคั่งสุทธิ · เวลาที่เหลือ · สุขภาพ
## รายละเอียดของแต่ละอันอยู่ในแผงของมันเองด้านล่าง ที่นี่เอาแค่ตัวเลขเดียวต่ออย่าง
##
## ปุ่ม [💾][📂] ต่อกับ `ui/screens/save_panel.gd` แล้ว — HUD ไม่เขียนไฟล์เอง แค่ยิงสัญญาณ

signal end_turn_pressed
signal save_pressed
signal load_pressed
signal audio_pressed

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")

var _player = null
var _match: WQMatch
var _month: Label
var _who: Label
var _cash: Label
var _net: Label
var _time: Label
var _health: Label
var _audio: Button
var _save: Button
var _load: Button
var _end: Button


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	_month = _stat(row, 16)
	_who = _stat(row, 15)
	row.add_child(_spacer())
	_cash = _stat(row, 14)
	_net = _stat(row, 14)
	_time = _stat(row, 14)
	_health = _stat(row, 14)

	# ปุ่มบันทึก/โหลดอยู่ก่อนปุ่มจบตา — จบตาคือปุ่มที่กดบ่อยที่สุดและกดผิดแล้วย้อนไม่ได้
	# จึงต้องอยู่ริมสุดตัวเดียว ไม่มีอะไรมาอยู่ถัดจากมันให้กดพลาด
	var audio_btn := Button.new()
	_audio = audio_btn
	audio_btn.text = "🔊"
	audio_btn.tooltip_text = "ปรับเสียง"
	audio_btn.pressed.connect(func(): WQAudio.ui("click"); audio_pressed.emit())
	row.add_child(audio_btn)

	var save_btn := Button.new()
	_save = save_btn
	save_btn.text = "💾"
	save_btn.tooltip_text = "บันทึกเกม"
	save_btn.pressed.connect(func(): WQAudio.ui("click"); save_pressed.emit())
	row.add_child(save_btn)

	var load_btn := Button.new()
	_load = load_btn
	load_btn.text = "📂"
	load_btn.tooltip_text = "โหลดเกม"
	load_btn.pressed.connect(func(): WQAudio.ui("click"); load_pressed.emit())
	row.add_child(load_btn)

	_end = Button.new()
	_end.text = "จบตา (Space)"
	_end.pressed.connect(func(): WQAudio.ui("click"); end_turn_pressed.emit())
	row.add_child(_end)


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


func _on_month(_m: int) -> void:
	refresh()


func refresh() -> void:
	var p = _player
	if p == null or _match == null: return
	_month.text = "เดือนที่ %d" % _match.month
	_who.text = "%s · %s" % [String(p.pname), String(p.job.get("name", ""))]
	_cash.text = "เงินสด %s฿" % WQFmt.m(p.cash)
	_cash.add_theme_color_override("font_color", WQPalette.MONEY if p.cash >= 0.0 else WARN)
	_net.text = "สุทธิ %s฿" % WQFmt.m(p.get_net_worth())
	_net.add_theme_color_override("font_color",
		WQPalette.WIN if p.get_net_worth() >= 0.0 else WARN)

	var hmax: int = maxi(1, p.get_hours_max())
	_time.text = "⏳ %d / %d ชม." % [p.hours, hmax]
	_time.add_theme_color_override("font_color",
		WQPalette.TIME if p.hours > 0 else DIM)
	_health.text = "❤️ %d — %s" % [int(p.health), String(p.health_band().name)]
	_health.add_theme_color_override("font_color",
		WQPalette.HEALTH if p.health >= 40.0 else WQPalette.DANGER)


func _stat(row: HBoxContainer, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	row.add_child(l)
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
