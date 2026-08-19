class_name WQDealCard
extends PanelContainer
## การ์ดดีลหนึ่งใบ (บทที่ 12 ของ GDD)
##
## กฎการนำเสนอข้อ 12.2.1: **การ์ดต้องบอกผลตอบแทนต่อทุน %/เดือน ไม่ใช่แค่ราคา**
## ราคาถูกไม่ได้แปลว่าดี — ธุรกิจจิ๋ว 28,000฿ ที่คืน 3%/เดือน ชนะคอนโด 2 ล้าน
## ที่คืน 0.9%/เดือน เสมอ ถ้าไม่โชว์ตัวเลขนี้ผู้เล่นจะเลือกด้วยราคาแล้วแพ้เพราะไม่รู้ตัว
##
## ข้อ 12.2.3: ปุ่มทุกปุ่มติดป้ายราคาเป็นชั่วโมง รวมเวลาเดินทางถ้ายังไม่ได้อยู่ที่นั่น

const KIND_LABEL := {
	"micro": "ธุรกิจจิ๋ว", "business": "ธุรกิจ", "realestate": "อสังหาฯ",
	"speculation": "เก็งกำไร", "fund": "กองทุน/ตราสาร",
}
const KIND_COLOR := {
	"micro": Color("c9962e"), "business": Color("c9962e"), "realestate": Color("7ba3cf"),
	"speculation": Color("c8a6ff"), "fund": Color("7ee08a"),
}
const DIM := Color("8fa6bd")
const GOOD := Color("7ee08a")
const BAD := Color("ff8080")
const GOLD := Color("ffd76a")
const HOT := Color("c9962e")
const TIME_COLOR := Color("4fc3f7")
const ROI_FULL_PCT := 5.0   ## แถบเต็มที่ 5%/เดือน — สูงกว่านี้คือดีลที่ดีผิดปกติอยู่แล้ว

signal acted   ## ยิงหลังผู้เล่นกดปุ่มบนการ์ด เพื่อให้ตัวที่ถือการ์ดอยู่รู้ว่าต้องวาดใหม่
signal hovered(deal: Dictionary)   ## เมาส์เข้าการ์ด → แท่นโชว์เปลี่ยนมาโชว์ดีลใบนี้

var _p = null
var _deal: Dictionary = {}


func _init() -> void:
	mouse_entered.connect(func(): hovered.emit(_deal))


func bind(player, deal: Dictionary) -> void:
	_p = player
	_deal = deal
	_build()


## แถบสถิติสำหรับแท่นโชว์ — ตัวเลขมาจาก core ทั้งหมด ที่นี่แค่เลือกว่าจะวัดเทียบกับอะไร
## (ตัวหารของแถบเป็นเรื่องการนำเสนอ ไม่ใช่สูตรเกม — เช่น "เงินดาวน์กินเงินสดที่มีไปเท่าไหร่")
static func showcase_stats(p, d: Dictionary) -> Array:
	var t: Dictionary = p.deal_terms(d)
	var hmax: int = maxi(1, p.get_hours_max())
	return [
		{"label": "ผลตอบแทนต่อทุน", "value": maxf(0.0, t.roi), "max": ROI_FULL_PCT,
			"text": "%.1f%%/เดือน" % t.roi, "color": GOOD if t.cashflow > 0 else BAD},
		{"label": "เงินดาวน์ (ควักเอง)", "value": t.down, "max": maxf(t.down, p.cash),
			"text": WQFmt.m(t.down) + "฿", "color": GOLD if t.affordable else BAD},
		{"label": "เวลาปิดดีล", "value": t.hours, "max": hmax,
			"text": "%d / %d ชม." % [t.hours, hmax], "color": TIME_COLOR},
		{"label": "ความผันผวน", "value": t.vol, "max": _max_vol(),
			"text": "%.0f%%" % (float(t.vol) * 100.0), "color": HOT},
	]


## เพดานความผันผวนอ่านจาก data จริง ไม่ตั้งตัวเลขลอยๆ ไว้ในโค้ด
## ไม่งั้นวันที่มีคนแก้ deals.json แถบจะเต็มค้างหรือไม่ขยับโดยไม่มีใครรู้
static func _max_vol() -> float:
	var mx := 0.0
	for pool in [WQData.deal_pool, WQData.big_deals, WQData.mega_deals]:
		for t in pool: mx = maxf(mx, float(t.get("vol", 0.0)))
	return mx if mx > 0.0 else 1.0


func _build() -> void:
	for c in get_children():
		remove_child(c); c.free()

	var p = _p
	var d := _deal

	# ตัวเลขทั้งใบมาจาก core ที่เดียว (WQPlayer.deal_terms) — การ์ดไม่คำนวณสูตรเกมเอง
	var t: Dictionary = p.deal_terms(d)
	var discount: bool = t.discount
	var price: float = t.price
	var down: float = t.down
	var debt: float = t.debt
	var income: float = t.income
	var payment: float = t.payment
	var cash_flow: float = t.cashflow
	var roi: float = t.roi

	var at_venue: bool = t.at_venue
	var venue: Dictionary = WQData.place(t.venue)
	var hours: int = t.hours
	var affordable: bool = t.affordable

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 9)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	margin.add_child(col)

	var stars := " ★★" if d.get("mega", false) else (" ★" if d.get("big", false) else "")
	var tag := Label.new()
	tag.text = "%s%s" % [KIND_LABEL.get(d.kind, d.kind), stars]
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", KIND_COLOR.get(d.kind, DIM))
	col.add_child(tag)

	var nm := Label.new()
	nm.text = "%s %s" % [d.icon, d.name]
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nm)

	_row(col, "ราคา", WQFmt.m(price) + "฿" + (" −10%" if discount else ""), GOLD)
	_row(col, "ใช้เงินตัวเอง (ดาวน์)", WQFmt.m(down) + "฿", GOLD if p.cash >= down else BAD)
	_row(col, "กู้เพิ่ม", (WQFmt.m(debt) + "฿") if debt > 0 else "—",
		(BAD if debt > p.get_credit_left() else DIM) if debt > 0 else DIM)
	_row(col, "รายรับ / ค่าผ่อน", "+%s / −%s" % [WQFmt.n(income), WQFmt.n(payment)], DIM)

	var cf := Label.new()
	cf.text = "%s฿/เดือน  (%.1f%%/ด. ต่อทุน)" % [WQFmt.signed(cash_flow), roi]
	cf.add_theme_font_size_override("font_size", 15)
	cf.add_theme_color_override("font_color", GOOD if cash_flow > 0 else BAD)
	col.add_child(cf)

	var ttl: int = int(d.ttl)
	_row(col, "🔥 กำลังจะหลุดจากตลาด!" if ttl <= 1 else "อยู่ในตลาดอีก ~%d เดือน" % ttl,
		"⏳%d ชม." % hours, HOT if ttl <= 1 else DIM)
	_row(col, "%s %s%s" % [venue.icon, venue.name, " ✓" if at_venue else ""], "",
		GOOD if at_venue else DIM)

	var b := Button.new()
	if at_venue:
		b.text = "ปิดดีล (%d ชม.)" % hours
		b.disabled = not (affordable and p.hours >= hours)
		b.pressed.connect(func(): p.close_deal(int(d.id)); acted.emit())
	else:
		var travel: int = p.travel_cost(venue.id)
		b.text = "ไป%s (%d ชม.)" % [venue.name, travel]
		b.disabled = p.hours < travel
		b.pressed.connect(func(): p.travel_to(venue.id); acted.emit())
	col.add_child(b)


func _row(box: VBoxContainer, left: String, right: String, color: Color) -> void:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = left
	a.add_theme_font_size_override("font_size", 11)
	a.add_theme_color_override("font_color", DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(a)
	if right != "":
		var b := Label.new()
		b.text = right
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", color)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(b)
	else:
		a.add_theme_color_override("font_color", color)
	box.add_child(h)
