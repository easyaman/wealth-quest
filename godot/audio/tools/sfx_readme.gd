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
	lines.append("เพลงไม่ได้สร้างจากโค้ด — **มันคือช่องว่างที่รอไฟล์จากคนทำเพลง**")
	lines.append("วางไฟล์ลง `audio/music/` ตั้งชื่อตามช่อง แล้ว `godot --headless --path . --import`")
	lines.append("เกมจะเล่นให้เองทันทีโดยไม่ต้องแก้โค้ด · ช่องที่ยังว่างจะยืมไฟล์ของช่องอื่นไปก่อน")
	lines.append("(ส่งมาไฟล์เดียวก็ได้ยินทั้งเกม) · ไม่มีไฟล์เลย = เกมเงียบ ไม่มี error")
	lines.append("")
	lines.append("| ช่อง | ดังตอนไหน | ไฟล์ |")
	lines.append("|---|---|---|")
	var have := 0
	for id in WQMusic.ids():
		var own := WQMusic.own_path(String(id))
		if own != "": have += 1
		var borrowed := WQMusic.path_for(String(id))
		var cell := "⬜ ยังว่าง"
		if own != "":
			cell = "🙌 `%s`" % own.get_file()
		elif borrowed != "":
			cell = "↩︎ ยืม `%s` ไปก่อน" % borrowed.get_file()
		lines.append("| `%s` | %s | %s |" % [id, String(WQMusic.SLOTS[id]), cell])

	lines.append("")
	lines.append("**มีเพลงจริงแล้ว %d/%d ช่อง**" % [have, WQMusic.ids().size()])
	## สองสเปกนี้เคยรวมเป็นหัวข้อเดียว วางไว้ใต้ตารางเพลงพอดี อ่านแล้วเข้าใจผิดว่า
	## "เพลงต้องยาวไม่เกิน 2 วินาที" — แยกให้ชัดว่าสเปกไหนคุมของอะไร (F8)
	lines.append("")
	lines.append("## สเปกสำหรับคนทำเสียงสั้น")
	lines.append("")
	lines.append("- mono · 22050 Hz ขึ้นไป · 16-bit PCM `.wav`")
	lines.append("- ยาวไม่เกิน 2 วินาที (เสียงชนะยาวสุดที่ 1.2 วินาที)")
	lines.append("- ชื่อไฟล์ = id ในตารางเสียงสั้นข้างบนเป๊ะ")
	lines.append("- ทำให้ดังพอๆ กับไฟล์ที่อบไว้ ระบบไม่มี normalize ให้")
	lines.append("")
	lines.append("## สเปกสำหรับคนทำเพลง")
	lines.append("")
	lines.append("- นามสกุลที่ใช้ได้: `%s` — **Godot นำเข้า `.mp4` ไม่ได้**" % " · ".join(WQMusic.EXTS))
	lines.append("  แปลงก่อนด้วย `ffmpeg -i เพลง.mp4 -vn -c:a libvorbis เพลง.ogg`")
	lines.append("- ชื่อไฟล์ = ชื่อช่องในตารางข้างบนเป๊ะ (เช่น `phase1.ogg`)")
	lines.append("- **ลูปได้ไม่มีรอยต่อ** — ต้นเพลงต่อท้ายเพลงต้องไร้รอยสะดุด เพราะเพลงเล่นวนตลอดด่าน")
	lines.append("  (ระบบตั้งจุดลูปให้เองที่หัวและท้ายไฟล์ ไม่มีการตัดเงียบให้)")
	lines.append("- ความยาวเท่าไหร่ก็ได้ แต่ยิ่งยาวยิ่งไม่น่าเบื่อ — เพลงหนึ่งดังอยู่ได้หลายสิบเดือนในเกม")
	lines.append("- ทำให้ดังพอๆ กันทุกช่อง ระบบไม่มี normalize ให้ · ผู้เล่นปรับระดับเพลงแยกจากเสียงเอฟเฟกต์ได้")
	lines.append("")

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
