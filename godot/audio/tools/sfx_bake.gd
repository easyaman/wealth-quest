extends SceneTree
## อบสเปกใน WQBank ออกเป็นไฟล์ `.wav` จริง — ไม่ต้องใช้โปรแกรมทำเสียงข้างนอก
##   godot --headless --path . --script res://audio/tools/sfx_bake.gd
##   godot --headless --path . --script res://audio/tools/sfx_bake.gd -- click travel
##   WQ_SFX_FORCE=1 ...        เขียนทับแม้กระทั่งไฟล์ที่คนทำเสียงวางไว้
##
## **ไฟล์ที่ออกมาไม่ใช่เสียงที่คนทำ** — มันคือคลื่นสังเคราะห์จาก WQSynth
## ประโยชน์คือท่อเดินครบวง: อบ → นำเข้า → เกมมีเสียง → คนทำเสียงวางไฟล์ทับทีละตัวได้เลย
##
## `save_to_wav()` เขียนแค่ chunk fmt กับ data ไม่มีช่องใส่ตราประทับแบบที่ glTF มี `copyright`
## จึงจด sha256 ของไฟล์ที่อบเองไว้ใน baked.json แทน — ถ้าแฮชของไฟล์บนดิสก์ไม่ตรงกับที่จด
## แปลว่ามีคนวางไฟล์จริงทับ **ตัวอบจะไม่แตะไฟล์นั้นเด็ดขาด**
##
## `baked.json` ถูกบันทึกทันทีหลังเขียน/ซ่อมตราของแต่ละไฟล์ ไม่ใช่รอจบทั้งชุด — ถ้าตัวอบโดน
## ขัดจังหวะกลางทาง (ปิดเครื่อง, ctrl-C) ไฟล์ที่เขียนไปแล้วก่อนหน้าต้องมีตราจดครบ ไม่งั้นรอบถัดไป
## จะเจอไฟล์ที่แฮชตรงกับของตัวเองเป๊ะแต่ไม่มีตราจด แล้วเข้าใจผิดว่าเป็นของคนทำเสียง — ไฟล์นั้นจะถูก
## ปฏิเสธไม่ให้แตะไปตลอดกาลจนกว่าจะใช้ WQ_SFX_FORCE ทั้งที่มันเป็นผลผลิตของตัวอบเองแท้ๆ
## (ดู _bake(): เช็ก "แฮชตรงกับที่ synth ผลิตตอนนี้เป๊ะไหม" ก่อนเช็กตราเสมอ เพื่อไม่ให้เกิดเคสนี้)

const SFX_DIR := "res://audio/sfx"
const STAMP := "res://audio/sfx/baked.json"
const TMP := "user://sfx_bake_tmp.wav"

var _written := 0
var _skipped_human := 0
var _skipped_same := 0
var _fails := 0


func _init() -> void:
	var only := _wanted()
	var force := OS.get_environment("WQ_SFX_FORCE") != ""
	print("=== sfx_bake%s ===" % ("" if only.is_empty() else " (เฉพาะ %d ตัว)" % only.size()))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	var marks := _load_marks()

	for id in WQBank.ids():
		if not only.is_empty() and not only.has(id): continue
		_bake(String(id), marks, force)

	# ลบตราของ id ที่หลุดออกจาก WQBank.SPEC ไปแล้ว — ไม่งั้น baked.json จะมีคีย์ค้างเก่าตลอดไป
	# ทำเฉพาะรอบที่อบครบทุกตัว (ไม่ได้กรองด้วย -- id...) เท่านั้น — รอบที่กรองเห็นแค่บางส่วน
	# ถ้าลบตรงนี้ตอนกรองไว้ ตราของ id ที่ไม่ได้แตะรอบนี้จะหายไปทั้งหมด แล้วรอบถัดไปจะเจอ
	# ปัญหาเดียวกับที่คอมเมนต์บนสุดอธิบายไว้ (ไฟล์ตัวเองถูกเข้าใจผิดว่าเป็นของคนทำ) กับทุก id ที่เหลือ
	if only.is_empty():
		for k in marks.keys().duplicate():
			if not WQBank.ids().has(k): marks.erase(k)

	_save_marks(marks)
	print("sfx_bake: เขียน %d ตัว · ข้ามของที่คนทำ %d · ไม่เปลี่ยน %d%s" % [
		_written, _skipped_human, _skipped_same,
		"" if _fails == 0 else " · ล้มเหลว %d ❌" % _fails])
	if _written > 0:
		print("  อย่าลืม: godot --headless --path . --import   แล้วรัน audio_check")
	quit(1 if _fails > 0 else 0)


func _wanted() -> Array:
	var out: Array = []
	for a in OS.get_cmdline_user_args(): out.append(String(a))
	return out


func _bake(id: String, marks: Dictionary, force: bool) -> void:
	var path := "%s/%s.wav" % [SFX_DIR, id]
	var abs := ProjectSettings.globalize_path(path)
	var tmp_abs := ProjectSettings.globalize_path(TMP)

	# อบลงที่พักก่อน เพื่อเทียบแฮชได้โดยไม่ต้องแตะไฟล์จริง
	var err := WQSynth.stream(WQBank.SPEC[id]).save_to_wav(TMP)
	if err != OK:
		_fails += 1
		print("  ❌ %s — เขียนไฟล์ที่พักไม่ได้ (error %d)" % [id, err])
		DirAccess.remove_absolute(tmp_abs)
		return
	var fresh := FileAccess.get_sha256(tmp_abs)

	if FileAccess.file_exists(abs):
		var have := FileAccess.get_sha256(abs)

		# แฮชของไฟล์บนดิสก์ตรงกับที่ synth ผลิตตอนนี้เป๊ะ = ไฟล์นี้เป็นของตัวอบเองแน่นอน
		# ไม่ว่า baked.json จะมีตราจดไว้หรือไม่ก็ตาม — เช็กข้อนี้ก่อนเช็กตราเสมอ ไม่งั้นไฟล์ของตัวอบเอง
		# ที่ตราหายไป (เช่นตัวอบโดนขัดจังหวะก่อนบันทึก baked.json) จะโดนเข้าใจผิดว่าเป็นของคนทำ
		if have == fresh:
			if String(marks.get(id, "")) != fresh:
				marks[id] = fresh
				_save_marks(marks)  # ซ่อมตราที่หายไปทันที ไม่รอจบทั้งชุด
			_skipped_same += 1
			DirAccess.remove_absolute(tmp_abs)
			return

		if have != String(marks.get(id, "")) and not force:
			_skipped_human += 1
			print("  🙌 %s — มีเสียงที่คนทำอยู่แล้ว ไม่แตะ" % id)
			DirAccess.remove_absolute(tmp_abs)
			return

	if DirAccess.copy_absolute(tmp_abs, abs) != OK:
		_fails += 1
		print("  ❌ %s — ก๊อปจากที่พักไม่ได้" % id)
		DirAccess.remove_absolute(tmp_abs)
		return
	DirAccess.remove_absolute(tmp_abs)
	marks[id] = fresh
	_save_marks(marks)  # จดตราทันทีหลังเขียนไฟล์ — ถ้าตัวอบโดนขัดจังหวะพอดีหลังจากนี้ ไฟล์จะไม่ถูกเข้าใจผิดว่าเป็นของคนทำ
	_written += 1
	print("  ✅ %s -> %s" % [id, path])


func _load_marks() -> Dictionary:
	var f := FileAccess.open(STAMP, FileAccess.READ)
	if f == null: return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _save_marks(marks: Dictionary) -> void:
	var f := FileAccess.open(STAMP, FileAccess.WRITE)
	if f == null:
		_fails += 1
		print("  ❌ เขียน baked.json ไม่ได้")
		return
	f.store_string(JSON.stringify(marks, "\t", true))
	f.close()
