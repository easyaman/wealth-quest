class_name WQWavProbe
extends RefCounted
## อ่านข้อมูลเสียงดิบออกจากไฟล์ .wav บนดิสก์ — **ไม่ใช่ผ่าน load()**
##
## Godot นำเข้า .wav เป็น QOA ที่ถูกบีบอัด `AudioStreamWAV.data` จึงไม่ใช่ PCM
## ถอดเป็น s16 แล้วได้ค่าขยะ (ตรวจแล้ว: ทุกไฟล์ให้พีค ~32767 เท่ากันหมด = เช็กที่ผ่านตลอด
## โดยไม่ได้ตรวจอะไรเลย) และไฟล์ดิบคือสิ่งที่คนทำเสียง/คนทำเพลงจะเอามาวางทับจริงๆ ด้วย

## คืนช่วง PCM ของไฟล์ .wav — ไล่หา chunk "data" จริงๆ ไม่ใช่ข้ามหัว 44 ไบต์ตายตัว
## เพราะไฟล์ที่คนทำเสียงส่งมามักมี chunk เสริม (LIST/INFO ของโปรแกรมตัดต่อ) คั่นอยู่ก่อน
static func pcm(abs_path: String) -> PackedByteArray:
	if not FileAccess.file_exists(abs_path): return PackedByteArray()
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.size() < 12 or raw.slice(0, 4).get_string_from_ascii() != "RIFF":
		return PackedByteArray()
	var pos := 12
	while pos + 8 <= raw.size():
		var id4 := raw.slice(pos, pos + 4).get_string_from_ascii()
		var size := raw.decode_u32(pos + 4)
		var body := pos + 8
		if id4 == "data":
			return raw.slice(body, mini(body + int(size), raw.size()))
		pos = body + int(size) + (int(size) & 1)      # chunk ยาวเลขคี่มีไบต์ padding ต่อท้าย
	return PackedByteArray()


## แอมพลิจูดสูงสุดของช่วง PCM (0–32767)
static func peak(data: PackedByteArray) -> int:
	var out := 0
	var i := 0
	while i + 1 < data.size():
		out = maxi(out, absi(data.decode_s16(i)))
		i += 2
	return out
