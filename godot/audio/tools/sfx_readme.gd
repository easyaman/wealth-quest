extends SceneTree
## สร้าง audio/README.md ใหม่จากรายการจริงใน WQBank — **ห้ามแก้ README ด้วยมือ**
##   godot --headless --path . --script res://audio/tools/sfx_readme.gd
##
## กติกาเดียวกับ world/tools/models_readme.gd: เช็กลิสต์ที่พิมพ์ด้วยมือจะโกหกภายในสัปดาห์เดียว
## ที่มาของแต่ละไฟล์ตัดสินจาก sha256 เทียบกับ audio/sfx/baked.json — แฮชไม่ตรง = คนวางทับ

const OUT := "res://audio/README.md"
const STAMP := "res://audio/sfx/baked.json"


func _init() -> void:
	var marks := {}
	var f := FileAccess.open(STAMP, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary: marks = parsed
		f.close()

	var lines: Array[String] = []
	lines.append("# เสียงของ Wealth Quest")
	lines.append("")
	lines.append("> ไฟล์นี้สร้างจาก `audio/tools/sfx_readme.gd` **ห้ามแก้ด้วยมือ**")
	lines.append("")
	lines.append("ทุกไฟล์ตอนนี้เป็นคลื่นสังเคราะห์จาก `WQSynth` ไม่ใช่เสียงที่คนทำ")
	lines.append("วางไฟล์ `.wav` ของตัวเองทับได้ทีละตัว — ตัวอบจะเห็นว่า sha256 ไม่ตรงกับที่จดไว้")
	lines.append("แล้วจะไม่แตะไฟล์นั้นอีกเลย")
	lines.append("")
	lines.append("ฟังทีละตัว: `WQ_SFX=<id> godot --path .`")
	lines.append("")
	lines.append("| id | ดังตอนไหน | คลื่น | ยาว (วิ) | ที่มา |")
	lines.append("|---|---|---|---|---|")

	var human := 0
	for id in WQBank.ids():
		var spec: Array = WQBank.SPEC[id]
		var path := "res://audio/sfx/%s.wav" % id
		var abs := ProjectSettings.globalize_path(path)
		var src := "❓ ยังไม่มีไฟล์"
		if FileAccess.file_exists(abs):
			if FileAccess.get_sha256(abs) == String(marks.get(id, "")):
				src = "🤖 อบจากโค้ด"
			else:
				src = "🙌 คนทำ"
				human += 1
		lines.append("| `%s` | %s | %s | %.2f | %s |"
			% [id, _when(id), String(spec[0]), float(spec[3]), src])

	lines.append("")
	lines.append("**คนทำเสียงจริงแล้ว %d/%d ตัว**" % [human, WQBank.ids().size()])
	lines.append("")
	lines.append("## เพลงพื้นหลัง")
	lines.append("")
	lines.append("| id | ดังตอนไหน | bpm | ยาว (วิ) | ที่มา |")
	lines.append("|---|---|---|---|---|")
	var mmarks := {}
	var mf := FileAccess.open("res://audio/music/baked.json", FileAccess.READ)
	if mf != null:
		var mparsed = JSON.parse_string(mf.get_as_text())
		if mparsed is Dictionary: mmarks = mparsed
		mf.close()
	const WHEN := {
		"phase1": "ด่าน 1 หรือยังไม่เริ่มแมตช์",
		"phase2": "ด่าน 2",
		"crisis": "สุขภาพต่ำกว่า 40 หรือมีภัยพิบัติค้างอยู่",
	}
	for id in WQMusic.ids():
		var mabs := ProjectSettings.globalize_path("res://audio/music/%s.wav" % id)
		var msrc := "❓ ยังไม่มีไฟล์"
		if FileAccess.file_exists(mabs):
			msrc = "🤖 อบจากโค้ด" if FileAccess.get_sha256(mabs) == String(mmarks.get(id, "")) \
				else "🙌 คนทำ"
		lines.append("| `%s` | %s | %d | %.1f | %s |" % [id, String(WHEN.get(id, "—")),
			int(WQMusic.TRACKS[id]["bpm"]), WQMusic.length_sec(id), msrc])
	lines.append("")
	lines.append("## สเปกสำหรับคนทำเสียง")
	lines.append("")
	lines.append("- mono · 22050 Hz ขึ้นไป · 16-bit PCM `.wav`")
	lines.append("- ยาวไม่เกิน 2 วินาที (เสียงชนะยาวสุดที่ 1.2 วินาที)")
	lines.append("- ชื่อไฟล์ = id ในตารางข้างบนเป๊ะ")
	lines.append("- ทำให้ดังพอๆ กับไฟล์ที่อบไว้ ระบบไม่มี normalize ให้")

	var out := FileAccess.open(OUT, FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("sfx_readme: เขียน %s (คนทำแล้ว %d ตัว)" % [OUT, human])
	quit()


## "เสียงนี้ดังตอนไหน" — อ่านจากตารางจริงใน WQBank ไม่ใช่พิมพ์เอง
## ไม่งั้นวันที่ใครย้ายเสียงจากเลนหนึ่งไปอีกเลน เอกสารจะโกหกทันทีโดยไม่มีใครรู้
func _when(id: String) -> String:
	var kinds: Array[String] = []
	for kind in WQBank.FROM_ACTED:
		if String(WQBank.FROM_ACTED[kind]) == id: kinds.append(String(kind))
	if not kinds.is_empty():
		kinds.sort()
		return "core ยิง `acted(%s)`" % ", ".join(kinds)
	if WQBank.UI_IDS.has(id): return "เลน UI — `WQAudio.ui(\"%s\")`" % id
	return "สัญญาณของแมตช์/ผู้เล่น"
