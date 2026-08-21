extends SceneTree
## อบเพลงใน WQMusic.TRACKS ออกเป็นไฟล์ `.wav` จริง
##   godot --headless --path . --script res://audio/tools/music_bake.gd
##   godot --headless --path . --script res://audio/tools/music_bake.gd -- phase1
##   WQ_MUSIC_FORCE=1 ...      เขียนทับแม้กระทั่งไฟล์ที่คนทำเพลงวางไว้
##
## กติกาตราประทับเหมือน sfx_bake ทุกข้อ: จด sha256 ของไฟล์ที่อบเองไว้ใน baked.json
## แฮชบนดิสก์ไม่ตรงกับที่จด = มีคนวางไฟล์จริงทับ **ตัวอบจะไม่แตะไฟล์นั้นเด็ดขาด**
## และเช็ก "แฮชตรงกับที่เรนเดอร์ตอนนี้เป๊ะไหม" ก่อนเช็กตราเสมอ เพื่อไม่ให้ไฟล์ของตัวอบเอง
## ที่ตราหายไป (โดนขัดจังหวะก่อนบันทึก baked.json) ถูกเข้าใจผิดว่าเป็นของคนทำเพลง
##
## เพลงหนึ่งเพลงยาวหลายสิบวินาที การเรนเดอร์ใช้เวลาหลายวินาทีต่อเพลง — ปกติ ไม่ได้ค้าง

const MUSIC_DIR := "res://audio/music"
const STAMP := "res://audio/music/baked.json"
const TMP := "user://music_bake_tmp.wav"

var _written := 0
var _skipped_human := 0
var _skipped_same := 0
var _fails := 0


func _init() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args(): only.append(String(a))
	var force := OS.get_environment("WQ_MUSIC_FORCE") != ""
	print("=== music_bake%s ===" % ("" if only.is_empty() else " (เฉพาะ %d เพลง)" % only.size()))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	var marks := _load_marks()

	for id in WQMusic.ids():
		if not only.is_empty() and not only.has(id): continue
		_bake(String(id), marks, force)

	# ลบตราของเพลงที่หลุดออกจาก TRACKS ไปแล้ว — ทำเฉพาะรอบที่อบครบทุกเพลงเท่านั้น
	# รอบที่กรองด้วย -- id เห็นแค่บางส่วน ถ้าลบตรงนี้ ตราของเพลงที่ไม่ได้แตะจะหายหมด
	if only.is_empty():
		for k in marks.keys().duplicate():
			if not WQMusic.ids().has(k): marks.erase(k)

	_save_marks(marks)
	print("music_bake: เขียน %d · ข้ามของที่คนทำ %d · ไม่เปลี่ยน %d%s" % [
		_written, _skipped_human, _skipped_same,
		"" if _fails == 0 else " · ล้มเหลว %d ❌" % _fails])
	if _written > 0:
		print("  อย่าลืม: godot --headless --path . --import   แล้วรัน music_check")
	quit(1 if _fails > 0 else 0)


func _bake(id: String, marks: Dictionary, force: bool) -> void:
	var path := "%s/%s.wav" % [MUSIC_DIR, id]
	var abs := ProjectSettings.globalize_path(path)
	var tmp_abs := ProjectSettings.globalize_path(TMP)

	var err := WQMusic.stream(id).save_to_wav(TMP)
	if err != OK:
		_fails += 1
		print("  ❌ %s — เขียนไฟล์ที่พักไม่ได้ (error %d)" % [id, err])
		DirAccess.remove_absolute(tmp_abs)
		return
	var fresh := FileAccess.get_sha256(tmp_abs)

	if FileAccess.file_exists(abs):
		var have := FileAccess.get_sha256(abs)
		if have == fresh:
			if String(marks.get(id, "")) != fresh:
				marks[id] = fresh
				_save_marks(marks)
			_skipped_same += 1
			DirAccess.remove_absolute(tmp_abs)
			return
		if have != String(marks.get(id, "")) and not force:
			_skipped_human += 1
			print("  🙌 %s — มีเพลงที่คนทำอยู่แล้ว ไม่แตะ" % id)
			DirAccess.remove_absolute(tmp_abs)
			return

	if DirAccess.copy_absolute(tmp_abs, abs) != OK:
		_fails += 1
		print("  ❌ %s — ก๊อปจากที่พักไม่ได้" % id)
		DirAccess.remove_absolute(tmp_abs)
		return
	DirAccess.remove_absolute(tmp_abs)
	marks[id] = fresh
	_save_marks(marks)
	_written += 1
	print("  ✅ %s -> %s (%.1f วิ)" % [id, path, WQMusic.length_sec(id)])


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
		print("  ❌ เขียน baked.json ของเพลงไม่ได้")
		return
	f.store_string(JSON.stringify(marks, "\t", true))
	f.close()
