class_name WQFonts
extends RefCounted
## ฟอนต์กลางของเกม
##
## Godot มากับฟอนต์ที่ไม่มีสระ/วรรณยุกต์ไทย ข้อความไทยจะกลายเป็นกล่องเปล่า
## เดิมแก้ด้วยการยืมฟอนต์ไทยจากระบบผ่าน `SystemFont` ซึ่งพอเอาไปเปิดบนเครื่องที่ไม่มี
## ฟอนต์ไทยติดมา (ลินุกซ์ส่วนใหญ่ · วินโดวส์บางรุ่น) ทั้งเกมจะอ่านไม่ออกทันที
## ตอนนี้จึง **ฝัง Noto Sans Thai (SIL OFL 1.1) ไว้ในโปรเจกต์** — ที่มาและสิทธิ์อยู่ใน
## `ui/theme/fonts/README.md` และ `ui/theme/fonts/OFL.txt` (ห้ามลบตอนแพ็กส่งออก)
##
## แยกออกมาจาก ui/main.gd เพราะ Label3D ในฉาก 3D ไม่ใช่ Control
## จึงไม่ได้รับ Theme ที่ main.gd ตั้งไว้ ต้องยัดฟอนต์ให้ตรงๆ ทีละตัว

const PATH := "res://ui/theme/fonts/NotoSansThai.ttf"

## น้ำหนักของตัวหนา — ไฟล์เป็นฟอนต์ variable จึงรีดตัวหนาออกจากไฟล์เดียวกันได้
## ไม่ต้องเก็บไฟล์ Bold แยก (ดู README ในโฟลเดอร์ฟอนต์)
const BOLD_WEIGHT := 700

static var _thai: FontFile
static var _bold: FontVariation


## ฟอนต์หลักของทั้งเกม
static func thai() -> FontFile:
	if _thai == null:
		_thai = load(PATH)
		## อีโมจิไม่ได้อยู่ในไฟล์ฟอนต์ที่ฝัง (🏆 💡 ❤️ ⏳ ใช้ทั่วทั้ง UI และมาจาก data/*.json ด้วย)
		## ทางนี้คือทางเดียวที่มันจะโผล่มา — ปิดเมื่อไหร่อีโมจิกลายเป็นกล่องเปล่าทั้งเกม
		_thai.allow_system_fallback = true
	return _thai


## ตัวหนาสำหรับ `[b]` ของ RichTextLabel
##
## RichTextLabel ไม่ได้ทำตัวหนาปลอมให้ มันไปหยิบฟอนต์จากช่อง `bold_font` ของธีมตรงๆ
## ถ้าไม่ตั้งช่องนั้น มันจะตกไปใช้ฟอนต์เริ่มต้นของ Godot ซึ่งไม่มีอักษรไทย — ข้อความในการ์ดสอน
## กับหน้าทอยความฝันมี `[b]...[/b]` เป็นภาษาไทยเต็มไปหมด จะกลายเป็นกล่องเปล่าเฉพาะคำที่เน้น
static func bold() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = thai()
		## คีย์ของ `variation_opentype` เป็น **ตัวเลข tag** ไม่ใช่ชื่อแกน — เขียน `{"wght": 700}`
		## ตรงๆ จะเงียบสนิท ไม่มี error และตัวหนาจะออกมาหน้าเท่าตัวปกติเป๊ะ (วัดด้วย
		## `get_string_size()` แล้วได้ค่าเดียวกันทั้งสองตัว) ต้องแปลงผ่าน `name_to_tag()` เสมอ
		var ts := TextServerManager.get_primary_interface()
		_bold.variation_opentype = {ts.name_to_tag("wght"): BOLD_WEIGHT}
	return _bold
