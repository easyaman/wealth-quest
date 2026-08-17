extends Control
## หน้าจอหลักชั่วคราว — มีวิดเจ็ตจริงแล้ว: ⏳ งบเวลา · งบการเงิน · ตลาดดีล · หนี้สิน
## งานถัดไปตามบทที่ 12 ของ GDD: health_bar → standings → แผงสถานที่/การเดินทาง

const BG := Color("0a1420")

var m: WQMatch
var time_budget: WQTimeBudget
var deal_market: WQDealMarket
var statement: WQStatement
var debt_list: WQDebtList
var log_label: RichTextLabel
var _scroll: ScrollContainer
var _shot_path := ""
var _shot_frames := 0


func _ready() -> void:
	_apply_thai_font()
	_build_layout()

	WQData.load_all()
	m = WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
		{"name": "บอท B", "job_id": "pilot", "is_ai": true},
	]})
	m.month_ended.connect(func(_mo): _refresh())
	_refresh()

	# ถ่ายภาพหน้าจอแล้วปิดตัวเอง — ใช้ตรวจงาน UI จาก terminal ได้โดยไม่ต้องเปิดเกมเอง
	_shot_path = OS.get_environment("WQ_SHOT")
	set_process(_shot_path != "")
	# เลื่อนหน้าลงก่อนถ่าย เพื่อตรวจวิดเจ็ตที่อยู่ใต้ขอบจอได้จาก terminal
	var scroll_to := OS.get_environment("WQ_SHOT_SCROLL")
	if scroll_to != "": _scroll.set_deferred("scroll_vertical", scroll_to.to_int())


## Godot มากับฟอนต์ที่ไม่มีสระและวรรณยุกต์ไทย ข้อความทั้งเกมจะกลายเป็นกล่องเปล่า
## จึงต้องยืมฟอนต์ไทยจากระบบก่อน — ตอนจะปล่อยจริงค่อยฝังฟอนต์ที่มีสิทธิ์ใช้งานลงในโปรเจกต์
func _apply_thai_font() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans Thai", "Sarabun", "Thonburi", "Leelawadee UI", "Tahoma"])
	f.allow_system_fallback = true   # อีโมจิมาจากฟอนต์ระบบผ่านทางนี้ ไม่ต้องระบุชื่อเอง
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = 14
	theme = t


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	margin.add_child(cols)

	# ตลาดดีลยาวเกินจอได้ง่ายๆ (9-11 ใบ) ถ้าไม่มีสกรอลล์ การ์ดแถวล่างจะกดไม่ได้เลย
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(780, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(_scroll)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	_scroll.add_child(center)

	time_budget = WQTimeBudget.new()
	center.add_child(time_budget)

	statement = WQStatement.new()
	center.add_child(statement)

	deal_market = WQDealMarket.new()
	center.add_child(deal_market)

	debt_list = WQDebtList.new()
	center.add_child(debt_list)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(log_label)


func _refresh() -> void:
	var p = m.get_current()
	if p == null: return
	time_budget.bind(p)
	deal_market.bind(p, m)
	statement.bind(p)
	debt_list.bind(p)

	var s := "[b]เดือนที่ %d[/b]  |  %s %s\n" % [m.month, p.job.icon, p.pname]
	s += "เงินสด %s  ·  สุทธิ %s  ·  📍 %s  ·  ❤️ %d\n" % [
		WQFmt.m(p.cash), WQFmt.m(p.get_net_worth()), WQData.place(p.place).name, int(p.health)]
	s += "รายได้จากทรัพย์สิน %s / รายจ่าย %s  (%.0f%%)\n\n" % [
		WQFmt.n(p.get_passive_income()), WQFmt.n(p.get_total_expenses()), p.get_freedom_pct()]
	s += "[b]บันทึก[/b]\n"
	for i in mini(12, m.logs.size()):
		s += "  [%d] %s\n" % [m.logs[i].month, m.logs[i].text]
	log_label.text = s


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		m.end_turn()   # กด Space = จบตา (ชั่วคราว)
		_refresh()


## รอให้วาดจบสองสามเฟรมก่อน (เลย์เอาต์ของ Container นิ่งหลังเฟรมแรก) แล้วค่อยบันทึกภาพ
func _process(_dt: float) -> void:
	_shot_frames += 1
	if _shot_frames < 4: return
	set_process(false)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_shot_path)
	print("screenshot %s -> %s" % [_shot_path, "ok" if err == OK else "ผิดพลาด %d" % err])
	get_tree().quit()
