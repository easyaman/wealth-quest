extends Control
## หน้าจอหลักชั่วคราว — มีวิดเจ็ตจริงแล้ว: 🏆 อันดับ · ⏳ งบเวลา · ❤️ สุขภาพ
## · 📍 สถานที่/การเดินทาง · งบการเงิน · ตลาดดีล · 🏘️ ทรัพย์สิน · หนี้สิน · ร้านค้า
## และงานอาร์ต 3D: ฉากเมือง (world/city) + แท่นโชว์ (world/showcase) + หน้าเลือกอาชีพ
##
## **ยังไม่ได้จัดเป็นสามคอลัมน์ตามบทที่ 12 ของ GDD** — ตอนนี้ยังเป็นคอลัมน์กลางเลื่อนยาว
## กับคอลัมน์ขวาที่เป็นฉาก 3D งานถัดไปคือแผงสถานที่/การเดินทาง แล้วค่อยจัดเลย์เอาต์จริง

const BG := WQPalette.BG_DEEP
const SEED := 20260815

var m: WQMatch
var hud: WQHud
var banner: WQBanner
var hint: WQHint
var standings: WQStandings
var goal_panel: WQGoalPanel
var health_bar: WQHealthBar
var statement: WQStatement
var time_budget: WQTimeBudget
var deal_market: WQDealMarket
var travel_panel: WQTravelPanel
var asset_list: WQAssetList
var debt_list: WQDebtList
var shop: WQShop
var showcase: WQShowcase
var city: WQCity
var log_label: RichTextLabel
var lessons: WQLessons
var setup_screen: WQJobSelect
var _scroll: ScrollContainer          ## คอลัมน์กลาง — ตัวที่ WQ_SHOT_SCROLL เลื่อนตอนถ่ายภาพ
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
	# แผงเดินทางกับฉากเมือง 3D เข้าทางเดียวกันเป๊ะ — ทั้งคู่แค่ "บอก" ว่าอยากไปไหน
	travel_panel.travel_requested.connect(_on_place_clicked)
	if not hud.end_turn_pressed.is_connected(_end_turn):
		hud.end_turn_pressed.connect(_end_turn)
	_refresh()


## รายละเอียดว่าทำไมต้องยืมฟอนต์จากระบบอยู่ใน ui/theme/fonts.gd
func _apply_thai_font() -> void:
	var t := Theme.new()
	t.default_font = WQFonts.thai()
	t.default_font_size = 14
	theme = t


## เลย์เอาต์ตามบทที่ 12 ของ GDD:
##   HUD (เต็มความกว้าง) → ฉากเมือง → แบนเนอร์ประกาศ → คำใบ้ตามบริบท → สามคอลัมน์
##
## ทำไมสามคอลัมน์ถึงสำคัญ: ก่อนหน้านี้ทุกวิดเจ็ตกองอยู่ในคอลัมน์เดียวที่เลื่อนยาวมาก
## ผู้เล่นต้องเลื่อนขึ้นลงไปมาเพื่อเทียบ "เวลาที่เหลือ" กับ "ดีลที่อยากซื้อ" ซึ่งเป็นการตัดสินใจ
## คู่เดียวที่เกมนี้ถามซ้ำทุกเดือน — ของที่ต้องเทียบกันต้องอยู่ในสายตาพร้อมกัน
##
## ซ้าย = "ฉันอยู่ตรงไหน" (อันดับ เป้าหมาย สุขภาพ งบการเงิน) — อ่านอย่างเดียว
## กลาง = "ฉันทำอะไรได้" (เวลา ดีล เดินทาง ทรัพย์สิน หนี้ ร้านค้า) — ทุกอย่างที่กดได้
## ขวา = "เกิดอะไรขึ้นแล้ว" (แท่นโชว์ บันทึก บทเรียน)
func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	hud = WQHud.new()
	page.add_child(hud)

	# ฉากเมืองเป็นแถบขวางตามผัง — มันคืออินเทอร์เฟซหลักของระบบเดินทาง (GDD 3A.6 ข้อ 1)
	# ไม่ใช่ของประดับที่ยัดไว้มุมจอ
	#
	# แต่ **ห้ามปล่อยให้กว้างเต็มจอ** — กล้องเป็น orthographic size 22 ซึ่งล็อกความสูงที่
	# 22 หน่วยตาม ART-DIRECTION 2.3 ความกว้างที่เห็นจึงผันตามอัตราส่วนภาพล้วนๆ
	# เต็มจอ 16:9 ในแถบสูง 300 = เห็นกว้างราว 140 หน่วย ขณะที่ถนนทั้งเส้นยาวแค่ 50
	# ผลคือเมืองลอยอยู่กลางพื้นว่างเปล่าสองข้าง — บีบให้เหลือราว 3:1 แล้วถนนเต็มเฟรมพอดี
	var city_row := CenterContainer.new()
	page.add_child(city_row)
	city = load("res://world/city/City.tscn").instantiate()
	city.custom_minimum_size = Vector2(1000, 300)
	city_row.add_child(city)

	banner = WQBanner.new()
	page.add_child(banner)

	hint = WQHint.new()
	page.add_child(hint)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)

	var left := _column(cols, 330)
	standings = WQStandings.new()
	left.add_child(standings)
	goal_panel = WQGoalPanel.new()
	left.add_child(goal_panel)
	health_bar = WQHealthBar.new()
	left.add_child(health_bar)
	statement = WQStatement.new()
	left.add_child(statement)

	# ตลาดดีลมีได้ถึง 11 ใบ คอลัมน์กลางจึงยาวที่สุดและต้องกว้างพอให้การ์ดสามใบเรียงกันได้
	var center := _column(cols, 700, true)
	time_budget = WQTimeBudget.new()
	center.add_child(time_budget)
	deal_market = WQDealMarket.new()
	center.add_child(deal_market)
	travel_panel = WQTravelPanel.new()
	center.add_child(travel_panel)
	asset_list = WQAssetList.new()
	center.add_child(asset_list)
	debt_list = WQDebtList.new()
	center.add_child(debt_list)
	shop = WQShop.new()
	center.add_child(shop)

	var right := _column(cols, 360)
	showcase = load("res://world/showcase/Showcase.tscn").instantiate()
	showcase.custom_minimum_size = Vector2(0, 300)
	right.add_child(showcase)

	var log_box := PanelContainer.new()
	var log_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		log_margin.add_theme_constant_override("margin_" + side, 12)
	log_box.add_child(log_margin)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.custom_minimum_size = Vector2(0, 260)
	log_margin.add_child(log_label)
	right.add_child(log_box)

	lessons = WQLessons.new()
	right.add_child(lessons)


## หนึ่งคอลัมน์ = ScrollContainer ของตัวเอง — ทุกคอลัมน์ยาวไม่เท่ากันและยาวเกินจอได้ทั้งสามอัน
## ถ้าใช้สกรอลล์เดียวร่วมกัน เลื่อนดูดีลทีเดียวแล้วสุขภาพกับบันทึกจะเลื่อนหายไปด้วย
func _column(parent: HBoxContainer, width: float, is_center := false) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_center:
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll = scroll
	parent.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	return col


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
	health_bar.bind(p)
	standings.bind(p, m)
	travel_panel.bind(p)
	asset_list.bind(p)
	hud.bind(p, m)
	banner.bind(m)
	hint.bind(p)
	goal_panel.bind(p)

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


func _end_turn() -> void:
	if m == null: return
	m.end_turn()
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if m == null: return          # ยังอยู่หน้าเลือกอาชีพ ยังไม่มีเกมให้จบตา
	if e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		_end_turn()


## รอให้วาดจบสองสามเฟรมก่อน (เลย์เอาต์ของ Container นิ่งหลังเฟรมแรก) แล้วค่อยบันทึกภาพ
func _process(_dt: float) -> void:
	_shot_frames += 1
	if _shot_frames < 4: return
	set_process(false)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_shot_path)
	print("screenshot %s -> %s" % [_shot_path, "ok" if err == OK else "ผิดพลาด %d" % err])
	get_tree().quit()
