extends Control
## หน้าจอหลัก — จัดสามคอลัมน์ตามผังบทที่ 12 ของ GDD แล้ว
## ซ้าย = "ฉันอยู่ตรงไหน" (อันดับ เป้าหมาย สุขภาพ งบการเงิน)
## กลาง = "ฉันทำอะไรได้" (เวลา ดีล เดินทาง ทรัพย์สิน หนี้ ร้านค้า)
## ขวา = "เกิดอะไรขึ้นแล้ว" (แท่นโชว์ บันทึก บทเรียน)
##
## เกมเริ่มที่ `ui/screens/setup_screen.gd` (ทอยเต๋า → เลือกอาชีพ) แล้วค่อยตั้งแมตช์ที่นี่

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
var action_panel: WQActionPanel
var travel_panel: WQTravelPanel
var asset_list: WQAssetList
var debt_list: WQDebtList
var shop: WQShop
var showcase: WQShowcase
var city: WQCity
var log_label: RichTextLabel
var lessons: WQLessons
var setup_screen: WQSetupScreen
var dream_screen: WQDreamRoll     ## หน้าทอยความฝันด่าน 2 — มีอยู่แปลว่ากำลังรอผู้เล่นตัดสินใจ
var save_panel: WQSavePanel       ## หน้าบันทึก/โหลด — มีอยู่แปลว่ากำลังเปิดค้างอยู่
var audio_panel: WQAudioPanel     ## แผงปรับเสียง — มีอยู่แปลว่ากำลังเปิดค้างอยู่
var tutorial: WQTutorial          ## การสอน 5 เดือนแรก — ซ่อนตัวเองเมื่อจบหรือถูกข้าม
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
		setup_screen = WQSetupScreen.new()
		setup_screen.chosen.connect(_on_job_chosen)
		setup_screen.load_requested.connect(func(): _open_save_panel("load"))
		add_child(setup_screen)
		setup_screen.start(SEED)
		# WQ_ROLL=<1-6> ข้ามภาพทอยเต๋าไปหน้าเลือกอาชีพเลย — ใช้ตอนถ่ายภาพหน้าจอจาก terminal
		var forced_roll := OS.get_environment("WQ_ROLL")
		if forced_roll != "": setup_screen.skip_to_jobs(forced_roll.to_int())

	# WQ_PANEL=save|load|audio เปิดหน้านั้นค้างไว้เลย — ใช้ตอนถ่ายภาพหน้าจอจาก terminal
	var panel := OS.get_environment("WQ_PANEL")
	if panel == "audio": _open_audio_panel()
	elif panel != "": _open_save_panel(panel)

	# ถ่ายภาพหน้าจอแล้วปิดตัวเอง — ใช้ตรวจงาน UI จาก terminal ได้โดยไม่ต้องเปิดเกมเอง
	_shot_path = OS.get_environment("WQ_SHOT")
	set_process(_shot_path != "")
	# เลื่อนหน้าลงก่อนถ่าย เพื่อตรวจวิดเจ็ตที่อยู่ใต้ขอบจอได้จาก terminal
	var scroll_to := OS.get_environment("WQ_SHOT_SCROLL")
	if scroll_to != "": _scroll.set_deferred("scroll_vertical", scroll_to.to_int())

	# ฟังเสียงทีละตัวจาก terminal: WQ_SFX=win godot --path .
	# มีเพราะ audio_check ตรวจได้แค่ว่ามีไฟล์และยิงถูกจังหวะ ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง
	# (บทเรียนเดียวกับที่ต้องเปิดดูไอคอนจริงทุกครั้งหลังอบ)
	# ใช้ preview() ไม่ใช่ _play() — เมธอดภายในของ WQAudio ไม่ใช่ของที่ ui/ เรียกได้
	var sfx := OS.get_environment("WQ_SFX")
	if sfx != "":
		await get_tree().create_timer(0.2).timeout
		WQAudio.preview(sfx)
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()


## **ห้าม `free()` หน้าจอทิ้งตรงนี้** — เรามาถึงที่นี่จากปุ่มที่กำลังส่งสัญญาณ `pressed` อยู่
## ตัวมันเองยังถูกล็อกอยู่ Godot จึงปฏิเสธ ("Object is locked and can't be freed")
## แล้ว **ทั้งฟังก์ชันนี้จะหลุดกลางคัน** — เกมไม่เริ่มสักที ทั้งที่กดปุ่มแล้ว
## (กฎเดียวกับที่วิดเจ็ตใช้ `call_deferred` ตอนสร้างปุ่มใหม่ทั้งแผง)
func _close_screen(screen: Control) -> void:
	if screen == null: return
	screen.visible = false
	remove_child(screen)
	screen.call_deferred("free")


func _on_job_chosen(job_id: String, roll: int, bonus_hours: int) -> void:
	_close_screen(setup_screen)
	setup_screen = null
	_start_match(job_id, roll, bonus_hours)


func _start_match(job_id: String, roll: int, bonus_hours: int) -> void:
	var fresh := WQMatch.new()
	fresh.setup({"mode": "solo", "seed": SEED, "players": [
		{"name": "คุณ", "job_id": job_id, "is_ai": false,
			"roll": roll, "bonus_hours": bonus_hours},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
		{"name": "บอท B", "job_id": "pilot", "is_ai": true},
	]})
	_adopt_match(fresh)

	# การสอนเปิดให้เองสำหรับเกมใหม่ (GDD 12.4) — ปิดได้ด้วยปุ่ม "ข้ามการสอน" บนการ์ด
	# WQ_TUT=off ปิดตั้งแต่ต้นสำหรับถ่ายภาพหน้าจอ · WQ_TUT=<เลข> กระโดดไปสเต็ปนั้นเลย
	var tut := OS.get_environment("WQ_TUT")
	if tut == "off":
		tutorial.stop()
	elif tut != "":
		tutorial.resume(tut.to_int())
	else:
		tutorial.start()

	# WQ_PLACE=<place_id> วางผู้เล่นไว้ที่นั่นเลยโดยไม่เสียเวลาเดินทาง — ใช้ถ่ายภาพหน้าจอ
	# ของแผงที่หน้าตาเปลี่ยนตามสถานที่ (ฟิตเนส/รีสอร์ตกางแพ็กเกจ · ธนาคารกางปุ่มกู้)
	var forced_place := OS.get_environment("WQ_PLACE")
	if forced_place != "" and not WQData.place(forced_place).is_empty():
		var me2 = m.get_current()
		me2.place = forced_place
		# ต้องยิง `changed` เอง — วิดเจ็ตฟังสัญญาณนี้ ไม่ได้อ่านค่าใหม่ตอน _refresh()
		# (bind() ของวิดเจ็ตจะคืนทันทีถ้าเป็นผู้เล่นคนเดิม)
		me2.changed.emit()
		_refresh()

	# WQ_DREAM=1 ดันผู้เล่นไปที่จังหวะ "ออกจากสนามแข่งหนูได้แล้ว" ทันที
	# เพื่อดูหน้าทอยความฝัน (GDD บทที่ 9) โดยไม่ต้องเล่นจริง 20–50 เดือนก่อน
	if OS.get_environment("WQ_DREAM") != "":
		var me = m.get_current()
		me.finished = m.month
		me.pending_dream = true
		_refresh()


## รับแมตช์มาใช้เป็นเกมปัจจุบัน — ใช้ทั้งตอนเริ่มเกมใหม่และตอน **โหลดไฟล์เซฟ**
## ต้องถอดสัญญาณของแมตช์เก่าออกก่อนเสมอ ไม่งั้นโหลดเกมแล้วเกมเก่ายังส่งสัญญาณมาอัปเดตหน้าจอ
## (สัญญาณของ "วิดเจ็ต" ต่อไว้ครั้งเดียวใน `_build_layout` เพราะมันไม่ได้ผูกกับแมตช์)
func _adopt_match(new_match: WQMatch) -> void:
	if m != null and m.month_ended.is_connected(_on_month_ended):
		m.month_ended.disconnect(_on_month_ended)
	m = new_match
	m.month_ended.connect(_on_month_ended)
	## เสียงต้องตามผู้เล่นคนจริงเสมอ ไม่ใช่ `get_current()` ซึ่งเป็นบอทได้ระหว่างตาบอท
	## (main.gd เองก็มี `if p.is_ai: return` กันไว้หลายจุดด้วยเหตุผลเดียวกัน)
	WQAudio.bind(m)
	for pl in m.players:
		if not pl.is_ai:
			WQAudio.bind_player(pl)
			break
	city.bind(m)
	tutorial.bind(m.get_current(), m, {
		"time": time_budget, "deals": deal_market, "city": city, "shop": shop,
		"travel": travel_panel, "statement": statement, "goal": goal_panel,
		"actions": action_panel,
		"health": health_bar, "standings": standings, "hud": hud,
	})
	_refresh()


func _on_month_ended(_mo: int) -> void:
	# autosave ทุกสิ้นเดือน (GDD 14.3) — วนสามช่อง ผู้เล่นเขียนทับช่องพวกนี้เองไม่ได้
	WQSave.write_auto(m, _ui_state())
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
	# แผงลงมือทำอยู่ติดกับตลาดดีลโดยตั้งใจ — คำถามที่เกมนี้ถามซ้ำทุกเดือนคือ
	# "ชั่วโมงก้อนนี้เอาไปแลกเงินก้อนเดียว หรือเอาไปซื้อของที่จ่ายเราทุกเดือน"
	# ถ้าสองแผงนี้อยู่คนละที่ ผู้เล่นจะเทียบมันไม่ได้เลย
	action_panel = WQActionPanel.new()
	center.add_child(action_panel)
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

	# สัญญาณของวิดเจ็ตต่อครั้งเดียวตอนสร้างหน้าจอ — ไม่ผูกกับแมตช์ใดแมตช์หนึ่ง
	# (เดิมต่อใน `_start_match` ซึ่งพอโหลดเกมทีก็จะต่อซ้ำอีกชั้น แล้วกดเดินทางทีเดียวเดินสองรอบ)
	#
	# คลิกอาคารในฉาก 3D ไม่เรียก travel_to() เอง — ยิงสัญญาณกลับมาให้ ui/ ตัดสินใจ
	# (ART-DIRECTION 4.1 · world/ อ่านสถานะได้ แต่ห้ามแก้) แผงเดินทางเข้าทางเดียวกันเป๊ะ
	city.place_clicked.connect(_on_place_clicked)
	travel_panel.travel_requested.connect(_on_place_clicked)
	action_panel.travel_requested.connect(_on_place_clicked)
	deal_market.deal_hovered.connect(_on_deal_hovered)
	shop.picked.connect(_on_shop_picked)
	hud.end_turn_pressed.connect(_end_turn)
	hud.save_pressed.connect(func(): _open_save_panel("save"))
	hud.load_pressed.connect(func(): _open_save_panel("load"))
	hud.audio_pressed.connect(_open_audio_panel)

	# การสอนต้องลอยอยู่เหนือทุกอย่างในหน้าจอหลัก แต่ยังอยู่ใต้หน้าจอเต็มจอ
	# (หน้าทอยความฝัน/หน้าบันทึก ถูก add ทีหลัง จึงทับการ์ดสอนตอนเปิดอยู่แล้ว)
	tutorial = WQTutorial.new()
	add_child(tutorial)


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
	action_panel.bind(p)
	asset_list.bind(p)
	hud.bind(p, m)
	banner.bind(m)
	hint.bind(p)
	goal_panel.bind(p)

	# แท่นโชว์ตั้งต้นที่ดีลใบแรกในตลาด เพื่อไม่ให้แท่นว่างเปล่าตอนเปิดเกม
	if showcase.id == "" and not m.deals.is_empty(): _on_deal_hovered(m.deals[0])

	tutorial.refresh()
	_check_pending_dream()

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


# ========== บันทึก / โหลด ==========
## สถานะฝั่ง UI ที่ต้องกลับมาเหมือนเดิมตอนโหลด — ฝากไว้ในไฟล์เซฟผ่านช่อง `ui`
func _ui_state() -> Dictionary:
	return {"tut": tutorial.save_state()}


## แผงปรับเสียงเป็นของ "นอกเกม" — เปิดค้างไว้ไม่กระทบตาที่เล่นอยู่ ต่างจากแผงบันทึก
## ที่ต้องปิดก่อนถึงจะเล่นต่อได้ จึงไม่ต้องล้างของเก่าเหมือน _close_screen()
func _open_audio_panel() -> void:
	if audio_panel != null: return
	WQAudio.ui("panel_open")
	audio_panel = WQAudioPanel.new()
	audio_panel.closed.connect(_close_audio_panel)
	add_child(audio_panel)


func _close_audio_panel() -> void:
	if audio_panel == null: return
	audio_panel.queue_free()
	audio_panel = null


func _open_save_panel(mode: String) -> void:
	if save_panel != null: return
	WQAudio.ui("panel_open")
	save_panel = WQSavePanel.new()
	save_panel.save_requested.connect(_on_save_slot)
	save_panel.load_requested.connect(_on_load_slot)
	save_panel.closed.connect(_close_save_panel)
	add_child(save_panel)
	save_panel.open(mode, m != null)


func _close_save_panel() -> void:
	if save_panel == null: return      # ปิดของที่ไม่ได้เปิดอยู่ ต้องไม่มีเสียง
	WQAudio.ui("panel_close")
	_close_screen(save_panel)
	save_panel = null


func _on_save_slot(slot: String) -> void:
	if m == null: return
	var err := WQSave.write_slot(m, slot, _ui_state())
	_close_save_panel()
	if err == OK:
		WQAudio.ui("save")
		m.log_line("💾 บันทึกลงช่อง %s แล้ว" % slot, "good", null)
	else:
		m.log_line("⚠️ บันทึกไม่สำเร็จ (รหัส %d)" % err, "bad", null)
	_refresh()


## โหลดแล้วต้องล้างหน้าจอที่ค้างอยู่ทั้งหมด — ผู้เล่นอาจกดโหลดจากหน้า setup
## หรือกดตอนที่หน้าทอยความฝันเปิดค้างอยู่ ถ้าไม่ล้าง หน้าจอเก่าจะลอยทับเกมใหม่
func _on_load_slot(slot: String) -> void:
	var loaded := WQSave.read_slot(slot)
	_close_save_panel()
	if loaded == null:
		if m != null: m.log_line("⚠️ โหลดช่อง %s ไม่ได้" % slot, "bad", null)
		return
	if setup_screen != null:
		_close_screen(setup_screen)
		setup_screen = null
	if dream_screen != null:
		_close_screen(dream_screen)
		dream_screen = null
	WQAudio.ui("load")
	_adopt_match(loaded)
	# สอนต่อจากสเต็ปเดิม — ไฟล์ที่บันทึกตอนปิดการสอนไปแล้วจะได้ −1 แปลว่าไม่ต้องสอนอีก
	tutorial.resume(int(WQSave.read_extra(slot).get("tut", -1)))
	m.log_line("📂 โหลดจากช่อง %s แล้ว" % slot, "good", null)
	_refresh()


func _end_turn() -> void:
	# กำลังรอเลือกความฝัน หรือกำลังเปิดหน้าบันทึก/โหลดอยู่ ห้ามเดินเดือนต่อ
	if m == null or dream_screen != null or save_panel != null: return
	m.end_turn()
	_refresh()


## ผู้เล่นออกจากสนามแข่งหนูได้แล้ว (`pending_dream` ตั้งตอนสิ้นเดือนใน `settle()`)
## ต้องเด้งหน้าทอยความฝันทันที ไม่ใช่ปล่อยให้เล่นต่อโดยไม่รู้ว่าตัวเองผ่านด่าน 1 ไปแล้ว
func _check_pending_dream() -> void:
	if m == null or dream_screen != null: return
	var p = m.get_current()
	if p == null or p.is_ai or not p.pending_dream: return
	dream_screen = WQDreamRoll.new()
	dream_screen.chosen.connect(_on_dream_chosen)
	add_child(dream_screen)
	dream_screen.start(p)
	# WQ_DREAM=<1-6> ทอยให้เลยเพื่อถ่ายภาพหน้าจอตอนที่การ์ดความฝันโผล่แล้ว
	var forced := OS.get_environment("WQ_DREAM").to_int()
	if forced > 0: dream_screen.skip_to(forced)


func _on_dream_chosen(dream: Dictionary, retire: bool) -> void:
	var p = m.get_current()
	_close_screen(dream_screen)
	dream_screen = null
	if p != null: p.enter_phase2(dream, retire)
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	# ยังไม่มีเกมให้จบตา หรือมีหน้าจออื่นเปิดค้างอยู่
	if m == null or dream_screen != null or save_panel != null: return
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
