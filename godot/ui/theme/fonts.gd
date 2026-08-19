class_name WQFonts
extends RefCounted
## ฟอนต์กลางของเกม
##
## Godot มากับฟอนต์ที่ไม่มีสระ/วรรณยุกต์ไทย ข้อความไทยจะกลายเป็นกล่องเปล่า
## จึงต้องยืมฟอนต์ไทยจากระบบก่อน — **ตอนปล่อยจริงต้องฝังฟอนต์ที่มีสิทธิ์ใช้งานลงในโปรเจกต์**
##
## แยกออกมาจาก ui/main.gd เพราะ Label3D ในฉาก 3D ไม่ใช่ Control
## จึงไม่ได้รับ Theme ที่ main.gd ตั้งไว้ ต้องยัดฟอนต์ให้ตรงๆ ทีละตัว

## เรียงตามลำดับที่อยากได้ — ตัวแรกที่เครื่องมีจะถูกใช้
## (เป็น static var ไม่ใช่ const เพราะ PackedStringArray(...) ไม่นับเป็นค่าคงที่ใน GDScript)
static var NAMES := PackedStringArray([
	"Noto Sans Thai", "Sarabun", "Thonburi", "Leelawadee UI", "Tahoma"])

static var _thai: SystemFont


static func thai() -> SystemFont:
	if _thai == null:
		_thai = SystemFont.new()
		_thai.font_names = NAMES
		_thai.allow_system_fallback = true   # อีโมจิมาจากฟอนต์ระบบผ่านทางนี้
	return _thai
