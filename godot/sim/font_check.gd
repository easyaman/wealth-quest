extends SceneTree
## ตรวจว่าฟอนต์ไทยที่ฝังไว้ยังอยู่และยังถูกใช้จริง
##   godot --headless --path . --script res://sim/font_check.gd
##
## ทำไมต้องมีสูทนี้: ฟอนต์พังแล้ว **ไม่มีอะไรฟ้องเลย** เกมยังรันครบทุกอย่าง sim ยังเขียว
## ผลยังตรง engine.js ทุกเกม — เห็นก็ต่อเมื่อเปิดหน้าต่างดูด้วยตาแล้วพบว่าตัวอักษรไทย
## กลายเป็นกล่องเปล่า ซึ่งบนเครื่องที่ **มี** ฟอนต์ไทยติดมา (แมค) จะไม่มีวันเห็น เพราะ
## `allow_system_fallback` เอาฟอนต์ระบบมาแปะให้เนียนแทน — บั๊กจึงไปโผล่ที่เครื่องคนเล่นเท่านั้น
##
## เคยพลาดมาแล้วหนึ่งครั้งตอนทำ: `variation_opentype` รับคีย์เป็นตัวเลข tag ไม่ใช่ชื่อแกน
## เขียน `{"wght": 700}` ตรงๆ แล้วเงียบสนิท ไม่มี error และตัวหนาออกมาหน้าเท่าตัวปกติเป๊ะ

const ALL_CHECKS: Array[String] = ["file", "glyphs", "bold", "theme"]

## ตัวแทนของกลุ่มอักขระที่ฟอนต์ละตินล้วนมักไม่มี — ถ้าขาดตัวใดตัวหนึ่ง ข้อความไทยจะแหว่ง
## เป็นกล่องเปล่าเฉพาะจุด ซึ่งอ่านผ่านๆ แล้วนึกว่าเกมพิมพ์ผิด ไม่ใช่ฟอนต์ผิด
const MUST_HAVE := {
	"ก": "พยัญชนะ",
	"ั": "ไม้หันอากาศ",
	"ิ": "สระบน",
	"ุ": "สระล่าง",
	"่": "วรรณยุกต์เอก",
	"้": "วรรณยุกต์โท",
	"ๆ": "ไม้ยมก",
	"฿": "สัญลักษณ์บาท (ใช้ทุกตัวเลขเงินใน HUD)",
	"A": "ละติน",
	"0": "ตัวเลข",
}

var _fails := 0
## เช็กไหนที่รันจนจบฟังก์ชันจริง — กันสูทเขียวปลอมตอน SCRIPT ERROR หลุดกลางฟังก์ชัน
## (กติกาเดียวกับ sim/audio_check.gd ซึ่งเคยเจอเคสนี้จริงมาแล้ว)
var _completed := {}


func _init() -> void:
	_check_file()
	_check_glyphs()
	_check_bold()
	await _check_theme()
	for name in ALL_CHECKS:
		if not _completed.get(name, false):
			_fails += 1
			print("  ❌ เช็ก \"%s\" ไม่รันจบฟังก์ชัน — สคริปต์พังกลางทางก่อนถึงเครื่องหมายจบ" % name)
	print("font_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## ไฟล์ต้องอยู่ในโปรเจกต์จริง — และ **ใบอนุญาตต้องเดินทางไปกับไฟล์เสมอ**
## OFL ข้อ 4 บังคับให้แนบสัญญาไปกับทุกสำเนาของฟอนต์ ลบ OFL.txt ทิ้งเมื่อไหร่ = แจกผิดสัญญาทันที
func _check_file() -> void:
	_eq("ไฟล์ฟอนต์อยู่ในโปรเจกต์", FileAccess.file_exists(WQFonts.PATH), true)
	_eq("Godot นำเข้าไฟล์ฟอนต์แล้ว (ถ้าไม่ ให้รัน --import)",
		ResourceLoader.exists(WQFonts.PATH), true)
	_eq("ใบอนุญาต OFL อยู่ข้างไฟล์ฟอนต์",
		FileAccess.file_exists(WQFonts.PATH.get_base_dir() + "/OFL.txt"), true)
	_completed["file"] = true


## ฟอนต์ต้องเป็นไฟล์ที่ฝังมา **ไม่ใช่ฟอนต์ที่ยืมจากเครื่อง**
##
## เดิมเกมใช้ `SystemFont` ซึ่งอ่านออกเฉพาะเครื่องที่มีฟอนต์ไทยติดมาเอง ถ้าวันหลังมีใคร
## เปลี่ยนกลับ (เช่นแก้บั๊กเฉพาะหน้าแล้วลืมเปลี่ยนคืน) เกมจะยังดูปกติทุกอย่างบนเครื่องคนแก้
func _check_glyphs() -> void:
	var f := WQFonts.thai()
	_eq("ฟอนต์หลักเป็นไฟล์ที่ฝังมา ไม่ใช่ SystemFont", f is FontFile, true)
	_eq("เป็น Noto Sans Thai ตัวที่ ART-DIRECTION กำหนด", f.get_font_name(), "Noto Sans Thai")

	for ch in MUST_HAVE:
		_eq("มี \"%s\" (%s)" % [ch, MUST_HAVE[ch]], f.has_char(String(ch).unicode_at(0)), true)

	## อีโมจิไม่ได้อยู่ในไฟล์ฟอนต์ (🏆 💡 ❤️ ⏳ ใช้ทั่ว UI และมาจาก data/*.json ด้วย)
	## ทางนี้คือทางเดียวที่มันจะโผล่มา ปิดเมื่อไหร่อีโมจิกลายเป็นกล่องเปล่าทั้งเกม
	_eq("เปิดทางให้อีโมจิยืมจากฟอนต์ระบบ", f.allow_system_fallback, true)
	_eq("ไฟล์นี้เป็นฟอนต์ variable จริง (มีแกน wght ให้รีดตัวหนา)",
		f.get_supported_variation_list().has(
			TextServerManager.get_primary_interface().name_to_tag("wght")), true)
	_completed["glyphs"] = true


## ตัวหนาต้องหนากว่าจริง ไม่ใช่แค่ตั้งค่าไว้แล้วเชื่อ
##
## วัดที่ความกว้างของข้อความ ไม่ใช่ที่ค่าใน `variation_opentype` — ค่าที่ตั้งผิดคีย์ยังอ่านกลับมา
## ได้ตามที่ตั้งไว้ทุกประการ แต่ TextServer ไม่เอาไปใช้ ตัวหนาจึงออกมาเท่าตัวปกติเป๊ะ
func _check_bold() -> void:
	var thin := WQFonts.thai().get_string_size(_SAMPLE, 0, -1, 14).x
	var thick := WQFonts.bold().get_string_size(_SAMPLE, 0, -1, 14).x
	_eq("ตัวหนากว้างกว่าตัวปกติจริง (ได้ %.1f vs %.1f)" % [thick, thin], thick > thin, true)
	_eq("ตัวหนาสืบทอดตัวอักษรไทยจากฟอนต์เดียวกัน",
		WQFonts.bold().has_char("ก".unicode_at(0)), true)
	_completed["bold"] = true


## ฟอนต์ต้องไปถึงหน้าจอจริง ไม่ใช่แค่โหลดขึ้น
##
## RichTextLabel เป็นจุดที่หลุดง่ายที่สุด: `Theme.default_font` **ไม่ครอบ** `[b]` ของมัน
## มันไปหาช่อง `bold_font` ของธีมช่องเดียว ถ้าไม่ตั้งจะตกไปใช้ฟอนต์เริ่มต้นของ Godot
## ซึ่งไม่มีอักษรไทย — ผลคือกล่องเปล่าเฉพาะคำที่เน้น (การ์ดสอนกับหน้าทอยความฝันเต็มไปด้วย
## `[b]...[/b]` ภาษาไทย) ส่วนข้อความรอบๆ ยังอ่านออกปกติ จึงดูเหมือนพิมพ์ตกมากกว่าฟอนต์พัง
func _check_theme() -> void:
	var main: Control = load("res://ui/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	_eq("ธีมของเกมใช้ฟอนต์ที่ฝังไว้", main.theme.default_font, WQFonts.thai())
	_eq("ธีมตั้งฟอนต์ตัวหนาของ RichTextLabel ไว้",
		main.theme.get_font("bold_font", "RichTextLabel"), WQFonts.bold())

	## ถามจากตัววิดเจ็ตจริงที่อยู่ในฉาก ไม่ใช่จากธีม — ทางนี้เท่านั้นที่พิสูจน์ว่า
	## ธีมถูกส่งต่อลงมาถึงลูกจริง (ธีมที่ตั้งถูกแต่ไม่ได้ผูกกับ node ไหนเลยก็ผ่านเช็กข้างบน)
	var got: Font = main.log_label.get_theme_font("bold_font")
	_eq("บันทึกในเกมได้ฟอนต์ตัวหนาที่มีอักษรไทย", got.has_char("ก".unicode_at(0)), true)
	_eq("บันทึกในเกมได้ฟอนต์ปกติที่มีอักษรไทย",
		main.log_label.get_theme_font("normal_font").has_char("ก".unicode_at(0)), true)

	main.queue_free()
	_completed["theme"] = true


## ประโยคจริงจากการ์ดสอน — ปนไทย/ละติน/ตัวเลขในบรรทัดเดียวเหมือนข้อความส่วนใหญ่ในเกม
const _SAMPLE := "หนึ่งเดือนมี 720 ชั่วโมง"


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
