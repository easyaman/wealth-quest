class_name WQLessons
extends PanelContainer
## 💡 บทเรียนที่เกมนี้สอน — คอลัมน์ขวาล่างตามเลย์เอาต์บทที่ 12
##
## นี่คือ "วิทยานิพนธ์" ของเกมทั้งเกมย่อลงเจ็ดบรรทัด — ข้อความชุดเดียวกับต้นแบบเว็บ
## (`../ui.html`) เพื่อให้สิ่งที่เกมพยายามสอนไม่เพี้ยนไปคนละทางระหว่างสองเวอร์ชัน
##
## เป็นข้อความคงที่โดยตั้งใจ ต่างจาก 💡 คำใบ้ตามบริบทด้านบนที่เปลี่ยนตามสถานการณ์
## อันนั้นบอก "ตอนนี้ควรทำอะไร" ส่วนอันนี้บอก "ทำไมเกมถึงออกแบบมาแบบนี้"

const LESSONS := [
	["720 ชม./เดือน เท่ากันทุกคน", "หมอมีเงินเยอะสุดแต่เหลือเวลาว่างน้อยสุด"],
	["สุขภาพ = ประสิทธิภาพเวลา", "สุขภาพตกแปลว่าชั่วโมงที่มีอยู่ใช้ได้จริงน้อยลง"],
	["อาหารมีสามมิติ", "เงิน/เวลา/สุขภาพ — ไม่มีตัวเลือกไหนดีทุกด้าน"],
	["เรียนเพิ่มเติม ≠ เลื่อนขั้น", "เรียนแล้วเงินเดือนขึ้นโดยรายจ่ายไม่โต"],
	["งานเสริมคือกับดัก", "30 ชม. ได้เงินก้อนเดียว แต่ 18 ชม. ซื้อทรัพย์สินได้เงินทุกเดือน"],
	["รถไม่ใช่ของฟุ่มเฟือยเสมอไป", "ถ้าเดินทางเยอะ มันคือการซื้อเวลาคืน"],
	["ภัยพิบัติมาเป็นระยะ", "คนที่กู้เยอะเจ็บที่สุดตอนดอกเบี้ยพุ่ง"],
]

const DIM := Color("8fa6bd")
const ACCENT := Color("7fd8ff")


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)

	var title := Label.new()
	title.text = "💡 บทเรียนที่เกมนี้สอน"
	title.add_theme_font_size_override("font_size", 15)
	col.add_child(title)

	for l in LESSONS:
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("normal_font_size", 12)
		row.text = "• [color=#%s]%s[/color] — [color=#%s]%s[/color]" % [
			ACCENT.to_html(false), String(l[0]), DIM.to_html(false), String(l[1])]
		col.add_child(row)
