extends Control
## หน้าจอหลักชั่วคราว — มีวิดเจ็ตจริงแล้ว: ⏳ งบเวลา · งบการเงิน · ตลาดดีล · หนี้สิน
## และงานอาร์ต 3D ชุดแรก: ฉากเมือง (world/city) + แท่นโชว์ (world/showcase)
## งานถัดไปตามบทที่ 12 ของ GDD: health_bar เต็มรูปแบบ → standings → แผงสถานที่/การเดินทาง

const BG := WQPalette.BG_DEEP
const SEED := 20260815

var m: WQMatch
var time_budget: WQTimeBudget
var deal_market: WQDealMarket
var statement: WQStatement
var debt_list: WQDebtList
var shop: WQShop
var showcase: WQShowcase
var city: WQCity
var health_bar: WQStatBar
var log_label: RichTextLabel
var _scroll: ScrollContainer
var setup_screen: WQJobSelect
var _shot_path := ""
var _shot_frames := 0


func _ready() -> void:
	_apply_thai_font()
	_build_layout()
	WQData.load_all()

	# เกมเริ่มที่หน้าเลือกอาชีพเสมอ (GDD บทที่ 7) — ยกเว้นตอนถ่ายภาพหน้าจอเกม
	# ซึ่งข้ามได้ด้วย WQ_JOB=<job_id> เพื่อไม่ต้องกดผ่านหน้าเลือกอาชีพทุกครั้ง
	var forced := OS.get_environment("WQ_JOB")
	if forced != "":
		_start_match(forced, 0, 0)
	else:
		setup_screen = WQJobSelect.new()
		setup_screen.chosen.connect(_on_job_chosen)
		add_child(setup_screen)
		setup_screen.start(SEED)

	# ถ่ายภาพหน้าจอแล้วปิดตัวเอง — ใช้ตรวจงาน UI จาก terminal ได้โดยไม่ต้องเปิดเกมเอง
	_shot_path = OS.get_environment("WQ_SHOT")
	set_process(_shot_path != "")
	# เลื่อนหน้าลงก่อนถ่าย เพื่อตรวจวิดเจ็ตที่อยู่ใต้ขอบจอได้จาก terminal
	var scroll_to := OS.get_environment("WQ_SHOT_SCROLL")
	if scroll_to != "": _scroll.set_deferred("scroll_vertical", scroll_to.to_int())


func _on_job_chosen(job_id: String, roll: int, bonus_hours: int) -> void:
	if setup_screen != null:
		remove_child(setup_screen)
		setup_screen.free()
		setup_screen = null
	_start_match(job_id, roll, bonus_hours)


func _start_match(job_id: String, roll: int, bonus_hours: int) -> void:
	m = WQMatch.new()
	m.setup({"mode": "solo", "seed": SEED, "players": [
		{"name": "คุณ", "job_id": job_id, "is_ai": false,
			"roll": roll, "bonus_hours": bonus_hours},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
		{"name": "บอท B", "job_id": "pilot", "is_ai": true},
	]})
	m.month_ended.connect(func(_mo): _refresh())
	city.bind(m)
	# คลิกอาคารในฉาก 3D ไม่เรียก travel_to() เอง — ยิงสัญญาณกลับมาให้ ui/ ตัดสินใจ
	# (ART-DIRECTION 4.1 · world/ อ่านสถานะได้ แต่ห้ามแก้)
	city.place_clicked.connect(_on_place_clicked)
	deal_market.deal_hovered.connect(_on_deal_hovered)
	shop.picked.connect(_on_shop_picked)
	_refresh()


## รายละเอียดว่าทำไมต้องยืมฟอนต์จากระบบอยู่ใน ui/theme/fonts.gd
func _apply_thai_font() -> void:
	var t := Theme.new()
	t.default_font = WQFonts.thai()
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

	# แถบสุขภาพใช้ WQStatBar ตัวเดียวกับแถบเวลา — วิดเจ็ต health_bar เต็มรูปแบบยังเป็นงานถัดไป
	health_bar = WQStatBar.new()
	center.add_child(health_bar)

	statement = WQStatement.new()
	center.add_child(statement)

	deal_market = WQDealMarket.new()
	center.add_child(deal_market)

	debt_list = WQDebtList.new()
	center.add_child(debt_list)

	shop = WQShop.new()
	center.add_child(shop)

	# คอลัมน์ขวา: ฉากเมือง 3D อยู่บน แท่นโชว์อยู่กลาง บันทึกอยู่ล่าง
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)

	city = load("res://world/city/City.tscn").instantiate()
	city.custom_minimum_size = Vector2(0, 300)
	right.add_child(city)

	showcase = load("res://world/showcase/Showcase.tscn").instantiate()
	showcase.custom_minimum_size = Vector2(0, 330)
	right.add_child(showcase)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_label)


func _refresh() -> void:
	if m == null: return
	var p = m.get_current()
	if p == null: return
	time_budget.bind(p)
	deal_market.bind(p, m)
	statement.bind(p)
	debt_list.bind(p)
	shop.bind(p)
	city.bind_player(p)
	health_bar.set_stat("สุขภาพ", "%d / 100" % int(p.health), p.health / 100.0,
		WQPalette.HEALTH if p.health >= 40.0 else WQPalette.DANGER)

	# แท่นโชว์ตั้งต้นที่ดีลใบแรกในตลาด เพื่อไม่ให้แท่นว่างเปล่าตอนเปิดเกม
	if showcase.id == "" and not m.deals.is_empty(): _on_deal_hovered(m.deals[0])

	var s := "[b]เดือนที่ %d[/b]  |  %s %s\n" % [m.month, p.job.icon, p.pname]
	s += "เงินสด %s  ·  สุทธิ %s  ·  📍 %s  ·  ❤️ %d\n" % [
		WQFmt.m(p.cash), WQFmt.m(p.get_net_worth()), WQData.place(p.place).name, int(p.health)]
	s += "รายได้จากทรัพย์สิน %s / รายจ่าย %s  (%.0f%%)\n\n" % [
		WQFmt.n(p.get_passive_income()), WQFmt.n(p.get_total_expenses()), p.get_freedom_pct()]
	s += "[b]บันทึก[/b]\n"
	for i in mini(12, m.logs.size()):
		s += "  [%d] %s\n" % [m.logs[i].month, m.logs[i].text]
	log_label.text = s


## ดีลไม่มี id ของตัวเองที่คงที่ (id เป็นเลขรันไทม์) โมเดลจึงอ้างด้วย "ประเภทของดีล"
## → world/models/assets/<kind>.glb เช่น micro.glb, realestate.glb
func _on_deal_hovered(d: Dictionary) -> void:
	var p = m.get_current()
	if p == null: return
	showcase.show_item("assets", String(d.kind),
		WQDealCard.showcase_stats(p, d), "%s %s" % [d.icon, d.name])


## กด "ดู" ในร้าน → เอาของขึ้นแท่นโชว์พร้อมแถบสเปก
func _on_shop_picked(kind: String, id: String) -> void:
	var p = m.get_current()
	if p == null: return
	var stats: Array = WQShop.vehicle_stats(p, id) if kind == "vehicles" \
		else WQShop.device_stats(p, id)
	var item: Dictionary = WQData.vehicle(id) if kind == "vehicles" else WQData.device(id)
	showcase.show_item(kind, id, stats, "%s %s" % [item.get("icon", ""), item.get("name", id)])


func _on_place_clicked(place_id: String) -> void:
	var p = m.get_current()
	if p == null or p.is_ai: return
	p.travel_to(place_id)
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if m == null: return          # ยังอยู่หน้าเลือกอาชีพ ยังไม่มีเกมให้จบตา
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
