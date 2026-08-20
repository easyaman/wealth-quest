class_name WQDreamRoll
extends Control
## 🎲 ทอยเต๋าสุ่มความฝัน — หน้าจอเข้าด่าน 2 (GDD บทที่ 9)
##
## จังหวะนี้คือจุดที่เกมพูดประโยคสำคัญที่สุดของมัน: **ออกจากสนามแข่งหนูได้แล้ว แต่เกมยังไม่จบ**
## ถ้าปล่อยให้ผ่านไปเงียบๆ (อย่างที่เคยเป็น — แผงเป้าหมายขึ้นแค่ว่า "หน้าจอนี้ยังไม่ได้ทำ")
## ผู้เล่นจะไปถึงเส้นชัยด่านแรกโดยไม่รู้สึกอะไรเลย แล้วเล่นด่าน 2 แบบไม่รู้ว่ากำลังไล่ตามอะไรอยู่
##
## ลำดับตาม GDD 9.1: ประกาศ + สรุปว่าใช้เวลากี่เดือน → ทอยเต๋าสุ่มความฝัน (ทอยใหม่ได้ครั้งเดียว
## แต่ต้องรับผลครั้งที่สอง) → เลือกลาออกจากงานประจำหรือทำงานต่อ
##
## กฎเหล็กสองข้อของหน้าจอนี้:
##   1. **แต้มมาจาก `WQPlayer.roll_dream()`** ซึ่งใช้ตัวสุ่มของแมตช์ (state อยู่ในไฟล์เซฟ)
##      ทอยใหม่จึงกินตัวสุ่มจริง — เซฟแล้วโหลดใหม่เพื่อเลือกความฝันที่ชอบไม่ได้
##   2. **เกณฑ์ที่โชว์มาจาก `WQPlayer.dream_terms()`** ตัวเดียวกับที่ `enter_phase2()` ใช้จริง
##      ไม่คำนวณสูตรซ้ำที่นี่ ไม่งั้นเลขที่ใช้ตัดสินใจกับเลขที่ใช้วัดผลจะเป็นคนละอัน
##
## หน้าจอนี้ไม่เปลี่ยนสถานะผู้เล่นเอง — เลือกเสร็จแล้วยิง `chosen` ให้ `ui/main.gd`
## เป็นคนเรียก `enter_phase2()` (แบบเดียวกับหน้าเลือกอาชีพ)

signal chosen(dream: Dictionary, retire: bool)

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var picked: Dictionary = {}      ## ความฝันที่ทอยได้ล่าสุด — ว่างอยู่แปลว่ายังไม่ได้ทอย
var rerolled := false            ## ใช้สิทธิ์ทอยใหม่ไปแล้วหรือยัง (มีครั้งเดียว)

var _player = null
var _head: Label
var _sub: RichTextLabel
var _dice: WQDice
var _roll_btn: Button
var _result: VBoxContainer
var _reroll_btn: Button
var _choice: HBoxContainer
var _retire_btn: Button
var _keep_btn: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ทึบเกือบสนิท — หน้าจอหลักยังเห็นรางๆ ให้รู้ว่าเกมยังอยู่ตรงนั้น แต่ห้ามแย่งความสนใจ
	var bg := ColorRect.new()
	bg.color = Color(WQPalette.BG_DEEP, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	# เนื้อหายาวเกินจอเตี้ยได้ตอนที่ผลทอยกับปุ่มเลือกโผล่พร้อมกัน — ต้องมีสกรอลล์เสมอ
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(720, 0)
	center.add_child(col)

	_head = Label.new()
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_theme_font_size_override("font_size", 26)
	_head.add_theme_color_override("font_color", WQPalette.WIN)
	col.add_child(_head)

	_sub = _para(14)
	col.add_child(_sub)

	col.add_child(_para(13, "🎲 ทอยเต๋าเพื่อสุ่ม [b]เป้าหมายชีวิตใหม่[/b] — แต่ละความฝันขอ "
		+ "[color=#f2b233]เงินก้อน[/color] กับ [color=#66bb6a]รายได้ต่อเดือน[/color] ในสัดส่วนต่างกัน "
		+ "บางอันแพงแต่ขอรายได้น้อย บางอันถูกกว่าแต่ขอรายได้สูงมาก\n"
		+ "[color=#8fa6bd]ทอยใหม่ได้ 1 ครั้ง แต่ต้องรับผลครั้งที่สองไม่ว่าจะออกอะไร[/color]"))

	_dice = WQDice.new(110.0)
	_dice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dice.rolled.connect(_on_rolled)
	col.add_child(_dice)

	_roll_btn = Button.new()
	_roll_btn.text = "🎲 ทอยเต๋าเลือกเป้าหมาย"
	_roll_btn.custom_minimum_size = Vector2(260, 44)
	_roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_btn.pressed.connect(roll)
	col.add_child(_roll_btn)

	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 6)
	col.add_child(_result)

	_reroll_btn = Button.new()
	_reroll_btn.text = "🎲 ทอยใหม่ (ได้ครั้งเดียว — ต้องรับผลที่สอง)"
	_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_btn.visible = false
	_reroll_btn.pressed.connect(reroll)
	col.add_child(_reroll_btn)

	_choice = HBoxContainer.new()
	_choice.add_theme_constant_override("separation", 10)
	_choice.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice.visible = false
	col.add_child(_choice)

	_retire_btn = _choice_button("🌴 ลาออกจากงานประจำ")
	_retire_btn.pressed.connect(func(): _decide(true))
	_choice.add_child(_retire_btn)

	_keep_btn = _choice_button("💼 ทำงานประจำต่อไปก่อน")
	_keep_btn.pressed.connect(func(): _decide(false))
	_choice.add_child(_keep_btn)


func _choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(330, 78)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _para(size: int, bb := "") -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	if bb != "": l.text = "[center]%s[/center]" % bb
	return l


## เปิดหน้าจอให้ผู้เล่นคนนี้ — ต้องเป็นคนที่ `pending_dream` เป็นจริงเท่านั้น
func start(player) -> void:
	_player = player
	picked = {}
	rerolled = false
	_dice.reset(1)
	_roll_btn.disabled = false
	_reroll_btn.visible = false
	_choice.visible = false
	_clear(_result)

	_head.text = "🎉 ออกจากสนามแข่งหนูได้แล้ว!"
	_sub.text = ("[center]%s [b]%s[/b] ใช้เวลา [color=#f2b233]%d เดือน[/color] "
		+ "ทำให้รายได้จากทรัพย์สิน (%s฿) มากกว่ารายจ่ายทั้งหมด (%s฿) ได้สำเร็จ\n"
		+ "แต่เกมยังไม่จบ — [b]เงินอิสระแล้วจะเอาไปทำอะไรต่อ?[/b][/center]") % [
			String(_player.job.get("icon", "")), String(_player.pname), int(_player.finished),
			WQFmt.n(_player.get_passive_income()), WQFmt.n(_player.get_total_expenses())]


## ทอยจริง — `forced_roll > 0` ใช้ตอนเทสต์เท่านั้น
func roll(forced_roll := 0) -> void:
	if _player == null or _dice.rolling or not picked.is_empty(): return
	_roll_btn.disabled = true
	_reroll_btn.visible = false
	_choice.visible = false
	_clear(_result)
	var n: int = forced_roll if forced_roll > 0 else _player.roll_dream()
	picked = WQData.dreams[clampi(n, 1, WQData.dreams.size()) - 1]
	_dice.roll_to(int(picked.roll))


## ทอยใหม่ — ได้ครั้งเดียว และ **กินตัวสุ่มของแมตช์อีกครั้ง** เหมือนการทอยปกติ
## ผลที่สองต้องรับ ไม่ว่าจะดีกว่าหรือแย่กว่า (GDD 9.1 ข้อ 2)
func reroll(forced_roll := 0) -> void:
	if rerolled or picked.is_empty() or _dice.rolling: return
	rerolled = true
	picked = {}
	roll(forced_roll)


## ข้ามภาพลูกเต๋าไปที่ผลเลย — สำหรับเทสต์และตอนถ่ายภาพหน้าจอ (WQ_DREAM=<1-6>)
func skip_to(forced_roll := 0) -> void:
	roll(forced_roll)
	_dice.finish_now()


func _on_rolled(_face: int) -> void:
	if picked.is_empty(): return
	_show_dream()
	_reroll_btn.visible = not rerolled
	_choice.visible = true


## การ์ดความฝัน — เกณฑ์ทั้งสองมาจาก `dream_terms()` ของ core ไม่ได้คำนวณเองที่นี่
func _show_dream() -> void:
	var p = _player
	var terms: Dictionary = p.dream_terms(picked)
	_clear(_result)

	# รูปความฝันอบมาจากโมเดล 3D ชิ้นเดียวกับที่อยู่ใน world/models/dreams (ข้อ 8)
	# หน้านี้คือจุดเดียวในเกมที่ตอบว่า "เล่นไปทำไม" — ให้เห็นเป็นของ ไม่ใช่อ่านแต่ชื่อ
	var art := WQIcon.make("dream_%d" % int(picked.roll), String(picked.icon), 132)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result.add_child(art)

	var title := Label.new()
	title.text = "ได้แต้ม %d — %s %s" % [
		int(picked.roll), String(picked.icon), String(picked.name)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	_result.add_child(title)
	_result.add_child(_para(13, String(picked.desc)))

	# สองแถบนี้คือเกณฑ์ชนะทั้งหมดของเกม — ต้องเห็นทั้ง "ต้องมีเท่าไหร่" และ "ตอนนี้มีเท่าไหร่"
	# พร้อมกัน ไม่งั้นผู้เล่นเลือกไม่ถูกว่าความฝันไหนไกลกว่ากันสำหรับตัวเอง
	_result.add_child(WQStatBar.new("ต้องมีความมั่งคั่งสุทธิ",
		"%s / %s฿" % [WQFmt.m(p.get_net_worth()), WQFmt.m(float(terms.cost))],
		p.get_net_worth() / maxf(1.0, float(terms.cost)), WQPalette.MONEY))
	_result.add_child(WQStatBar.new("ต้องมีรายได้จากทรัพย์สินต่อเดือน",
		"%s / %s฿" % [WQFmt.n(p.get_passive_income()), WQFmt.n(float(terms.passive_req))],
		p.get_passive_income() / maxf(1.0, float(terms.passive_req)), WQPalette.WIN))
	_result.add_child(_para(12, "[color=#8fa6bd]💡 %s[/color]" % String(picked.why)))

	# ปุ่มสองปุ่มต้องบอก "ได้อะไร/เสียอะไร" เป็นตัวเลขจริงของคนนี้ ไม่ใช่คำโฆษณา
	var back: int = p.get_work_hours() + p.get_commute_hours()
	_retire_btn.text = "🌴 ลาออกจากงานประจำ\n+%d ชม./เดือน · ไม่มีเงินเดือนอีกแล้ว" % back
	_keep_btn.text = "💼 ทำงานประจำต่อไปก่อน\nเวลาเท่าเดิม · ยังได้เงินเดือน %s฿" % \
		WQFmt.m(p.get_current_salary())


func _decide(retire: bool) -> void:
	if picked.is_empty(): return
	chosen.emit(picked, retire)


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()
