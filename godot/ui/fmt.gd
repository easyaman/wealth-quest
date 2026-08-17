class_name WQFmt
extends RefCounted
## จัดรูปตัวเลขให้ตรงกับต้นแบบเว็บ (fmt / fmtM ใน ../engine.js)
## เลขเงินในเกมนี้ใหญ่มาก ถ้าไม่ย่อหลักล้านการ์ดดีลจะอ่านไม่ทัน

## 1234567 → "1,234,567"
static func n(v: float) -> String:
	var i := roundi(v)
	var sign := "-" if i < 0 else ""
	var s := str(absi(i))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return sign + s + out


## ตั้งแต่ 1 ล้านขึ้นไปย่อเป็น "1.23 ล้าน" (ตั้งแต่ 10 ล้านเหลือทศนิยมตำแหน่งเดียว)
static func m(v: float) -> String:
	var a := absf(v)
	if a >= 1000000.0:
		return ("%.1f ล้าน" % (v / 1000000.0)) if a >= 10000000.0 else ("%.2f ล้าน" % (v / 1000000.0))
	return n(v)


## เติมเครื่องหมายบวกให้ตัวเลขที่เป็นบวก เพื่อให้ "กระแสเงินสด" อ่านออกทันทีว่าบวกหรือลบ
static func signed(v: float) -> String:
	return ("+" if v >= 0 else "") + n(v)
