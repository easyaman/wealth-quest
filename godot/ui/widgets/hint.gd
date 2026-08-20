class_name WQHint
extends PanelContainer
## 💡 คำใบ้ตามบริบท — บรรทัดเดียว บอกเรื่องที่สำคัญที่สุด "ตอนนี้" (กฎ 12.2.6)
##
## **ไม่ใช่ tooltip คงที่** และไม่ใช่รายการคำแนะนำยาวเหยียด — ถ้าโชว์พร้อมกันสิบข้อ
## มันจะกลายเป็นกำแพงข้อความที่ผู้เล่นเลิกอ่านตั้งแต่เดือนที่สอง
## ที่นี่จึงเรียงลำดับความสำคัญไว้ แล้วพูดข้อเดียวที่ชนะ
##
## ลำดับความสำคัญ = "ถ้าไม่ทำตอนนี้แล้วเสียหายแค่ไหน"
##   1. ทำความฝันได้แล้ว        — ถึงเส้นชัยแล้วแต่ยังไม่กด จะเสียเวลาเปล่าทั้งเดือน
##   2. สุขภาพวิกฤต             — เดือนละ 30% ที่จะล้มป่วยแล้วเสียเวลา 90 ชม.
##   3. มีคนเสนอซื้อทรัพย์สิน   — ข้อเสนออยู่แค่ 2 เดือนแล้วหายไป (GDD 5.3 = วิธีเร่งที่เร็วที่สุด)
##   4. ออกจากสนามแข่งหนูได้แล้ว — เปลี่ยนด่านได้ทันที
##   5. เวลาหมดแล้ว             — เหลือน้อยจนทำอะไรไม่ได้ ควรจบตา
##   6. ยังไม่มีทรัพย์สิน       — ยังไม่ได้เริ่มเล่นเกมจริงเลย
##
## ตัวเลขทุกตัวมาจาก core ที่นี่แค่เลือกว่าจะพูดเรื่องไหน

const DIM := Color("8fa6bd")

var _player = null
var _label: Label


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7)
	add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 13)
	margin.add_child(_label)


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(refresh):
		_player.changed.disconnect(refresh)
	_player = player
	if _player != null:
		_player.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var p = _player
	if p == null: return
	var hint := _pick(p)
	_label.text = "💡 " + String(hint.text)
	_label.add_theme_color_override("font_color", hint.get("color", DIM))
	visible = String(hint.text) != ""


func _pick(p) -> Dictionary:
	if p.phase == 2 and p.can_claim_dream():
		return {"text": "ครบทั้งสองเงื่อนไขแล้ว — กด \"ทำความฝันให้เป็นจริง\" ได้เลย",
			"color": WQPalette.WIN}

	if p.health < WQPlayer.HEALTH_CRISIS:
		return {"text": "สุขภาพอยู่ในโซนวิกฤต — เดือนละ %d%% ที่จะล้มป่วยหนักแล้วเสียเวลาอีก 90 ชม. ไปฟิตเนสหรือพักผ่อนก่อน" %
			roundi(WQPlayer.HEALTH_CRISIS_CHANCE * 100.0), "color": WQPalette.DANGER}

	# ข้อเสนออยู่แค่ 2 เดือน — พลาดแล้วพลาดเลย
	for a in p.assets:
		if a.offer == null: continue
		var t: Dictionary = p.asset_terms(a)
		return {"text": "มีคนเสนอซื้อ %s ที่ %s฿ (สูงกว่าราคาตลาด %.0f%%) เหลืออีก %d เดือน — ขายแล้วเอาเงินก้อนไปดาวน์หลายชิ้นคือวิธีเร่งที่เร็วที่สุด" % [
			String(a.name), WQFmt.m(float(t.sell_price)), float(t.premium) * 100.0,
			int(t.offer_ttl)], "color": WQPalette.MONEY}

	if p.phase == 1 and p.get_passive_income() >= p.get_total_expenses():
		return {"text": "รายได้จากทรัพย์สินคลุมรายจ่ายหมดแล้ว — ออกจากสนามแข่งหนูได้ในสิ้นเดือนนี้",
			"color": WQPalette.WIN}

	# เหลือเวลาน้อยกว่าการกระทำที่ถูกที่สุดที่ยังมีความหมาย = ทำอะไรต่อไม่ได้แล้ว
	var cheapest: int = p.act_cost("loan")
	if p.hours < cheapest:
		return {"text": "เวลาเดือนนี้เหลือ %d ชม. ทำอะไรไม่ได้แล้ว — กด \"จบตา\" เพื่อขึ้นเดือนใหม่" % p.hours,
			"color": WQPalette.TIME}

	if p.assets.is_empty():
		return {"text": "ยังไม่มีทรัพย์สินสักชิ้น — รายได้มาจากเงินเดือนล้วนๆ ซึ่งจะไม่มีวันชนะเกมนี้ ลองดูตลาดดีล",
			"color": DIM}

	var free: float = p.get_freedom_pct()
	return {"text": "อิสรภาพ %.0f%% — รายได้จากทรัพย์สิน %s฿ ยังต้องไล่ให้ทันรายจ่าย %s฿/เดือน" % [
		free, WQFmt.n(p.get_passive_income()), WQFmt.n(p.get_total_expenses())], "color": DIM}
