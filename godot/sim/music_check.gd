extends SceneTree
## ตรวจระบบเพลงพื้นหลังแบบ headless
##   godot --headless --path . --script res://sim/music_check.gd
##
## แยกจาก audio_check เพราะนั่นยาว 795 บรรทัดแล้ว และ sim/ แยกสูทตามระบบอยู่แล้ว
## ที่นี่ตรวจได้แค่ "ช่องครบไหม · ไฟล์ที่วางไว้ใช้ได้ไหม · เลือกเพลงถูกช่องไหม"
## ไม่ได้ตรวจว่าเพราะไหม — อันนั้นต้องเปิดฟังเอง: WQ_MUSIC=phase1 godot --path .
##
## **ตอนนี้โปรเจกต์ยังไม่มีไฟล์เพลงสักไฟล์** (เจ้าของฟังเพลงที่โค้ดแต่งเองแล้วสั่งทิ้ง รอไฟล์จริง)
## สูทนี้จึงต้องเขียวทั้งตอนที่ยังไม่มีไฟล์ และตอนที่วางไฟล์แล้ว — ทั้งสองสถานะถูกต้องพอๆ กัน

const ALL_CHECKS: Array[String] = ["slots", "files", "lane", "policy"]

var _fails := 0
## เช็กไหนที่รันจนจบฟังก์ชันจริง — กันสูทเขียวปลอมตอน SCRIPT ERROR หลุดกลางฟังก์ชัน
## (กติกาเดียวกับ sim/audio_check.gd ซึ่งเคยเจอเคสนี้จริงมาแล้ว)
var _completed := {}


func _init() -> void:
	_check_slots()
	_check_files()
	## รอหนึ่งเฟรมก่อนแตะ WQAudio — autoload WQAudioBoot เข้า tree หลัง _init() คืนค่า
	## กลับไปหนึ่งเฟรม เหมือนกันกับ audio_check.gd (กติกาเดียวกัน เหตุผลเดียวกัน)
	await process_frame
	await _check_lane()
	_check_policy()
	for name in ALL_CHECKS:
		if not _completed.get(name, false):
			_fails += 1
			print("  ❌ เช็ก \"%s\" ไม่รันจบฟังก์ชัน — สคริปต์พังกลางทางก่อนถึงเครื่องหมายจบ" % name)
	print("music_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## ช่องเพลงต้องครบและต้องชี้ไปที่ที่ถูก — ถ้าช่องหายไปเงียบๆ นโยบายจะสั่งเพลงที่ไม่มีอยู่จริง
## แล้ว WQAudio จะเตือนแล้วเงียบ ซึ่งอ่านจากในเกมไม่ออกเลยว่าเพราะอะไร
func _check_slots() -> void:
	_eq("มีช่องเพลงครบสามช่อง", WQMusic.ids(), ["crisis", "phase1", "phase2"])

	for id in WQMusic.ids():
		_eq("ช่อง \"%s\" บอกว่าดังตอนไหน" % id,
			String(WQMusic.SLOTS[id]).strip_edges().is_empty(), false)

	## ทุกช่องที่นโยบายเลือกได้ต้องมีอยู่จริงในตาราง — ไล่จากฝั่ง WQAudio เข้ามา ไม่ใช่จากตารางออกไป
	## (ทิศนี้จับได้ว่า "นโยบายสั่งช่องที่ไม่มี" ส่วนทิศตรงข้ามจับได้แค่ "มีช่องที่ไม่มีใครสั่ง")
	for id in ["phase1", "phase2", "crisis"]:
		_eq("นโยบายสั่งช่อง \"%s\" ได้จริง" % id, WQMusic.SLOTS.has(id), true)

	_eq("ไม่มี mp4 ในนามสกุลที่รองรับ (Godot นำเข้าไม่ได้)", WQMusic.EXTS.has("mp4"), false)
	_eq("รองรับ ogg mp3 wav", WQMusic.EXTS, ["ogg", "mp3", "wav"])

	## ยังไม่มีไฟล์ = ทุกช่องต้องคืน "" ไม่ใช่ path ที่ชี้ไปที่ไฟล์ที่ไม่มีอยู่
	if not WQMusic.has_any():
		for id in WQMusic.ids():
			_eq("ยังไม่มีไฟล์ ช่อง \"%s\" จึงคืนทางว่าง" % id, WQMusic.path_for(String(id)), "")

	_completed["slots"] = true


## ไฟล์ที่คนทำเพลงวางไว้ต้องใช้ได้จริง และ **การไม่มีไฟล์ต้องไม่ทำให้อะไรพัง**
##
## สองสถานะนี้ถูกต้องพอๆ กัน: ยังไม่มีใครส่งเพลงมา (ตอนนี้) กับส่งมาแล้วบางช่อง
## เช็กที่นี่จึงไม่ยืนกรานว่าต้องมีไฟล์ แต่ยืนกรานว่า **ถ้ามี มันต้องเล่นได้จริง**
## — ไฟล์ที่โหลดไม่ขึ้นหรือเงียบสนิทคือความเสียหายที่เงียบที่สุดของระบบเสียง
func _check_files() -> void:
	var d := DirAccess.open(WQMusic.DIR)
	_eq("มีโฟลเดอร์ %s ให้วางไฟล์" % WQMusic.DIR, d != null, true)
	if d == null: return

	## ไฟล์ที่ไม่มีช่องรองรับ = ไฟล์กำพร้า ไม่มีใครเล่นมันตลอดกาล และเจ้าของไฟล์จะไม่มีวันรู้
	## (ข้ามไฟล์ .import ที่ Godot สร้างคู่กับทุกไฟล์เสียง)
	for f in d.get_files():
		if f.ends_with(".import"): continue
		var base := f.get_basename()
		var ext := f.get_extension()
		_eq("ไฟล์ \"%s\" มีช่องรองรับ" % f, WQMusic.SLOTS.has(base), true)
		_eq("ไฟล์ \"%s\" เป็นนามสกุลที่ Godot นำเข้าได้" % f, WQMusic.EXTS.has(ext), true)

	var seen := {}
	for id in WQMusic.ids():
		var path := WQMusic.own_path(String(id))
		if path == "": continue          # ช่องนี้ยังว่าง — ถูกต้อง ไม่ใช่ข้อบกพร่อง

		var st = load(path)
		_eq("ไฟล์ของช่อง \"%s\" โหลดเป็นเสียงได้" % id, st is AudioStream, true)
		if not (st is AudioStream): continue
		_eq("ไฟล์ของช่อง \"%s\" ยาวเกินครึ่งวินาที (ไม่ใช่ไฟล์เปล่า)" % id,
			(st as AudioStream).get_length() > 0.5, true)

		## สองไฟล์ที่เป็นไบต์ชุดเดียวกันเป๊ะ = เผลอก๊อปไฟล์เดิมไปวางสองช่อง
		## ซึ่งฟังแล้วเหมือน "เพลงไม่เปลี่ยน" ทั้งที่โค้ดสลับเพลงถูกต้องทุกอย่าง
		var key := FileAccess.get_sha256(ProjectSettings.globalize_path(path))
		_eq("ไฟล์ของช่อง \"%s\" ไม่ใช่ไฟล์เดียวกับช่อง \"%s\"" % [id, String(seen.get(key, ""))],
			seen.has(key), false)
		seen[key] = id

	_completed["files"] = true


## เพลงต้องเปลี่ยนด้วยการเฟดไขว้ ไม่ใช่ตัดทันที และเพลงเดิมต้องไม่เริ่มใหม่
## `changed` ยิงหลายสิบครั้งต่อเดือน ถ้าไม่จำว่าเพลงไหนดังอยู่ เพลงจะเริ่มใหม่ตลอดเวลา
func _check_lane() -> void:
	WQAudio.settings_path = "user://settings_music_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WQAudio.settings_path))
	WQAudio.set_muted(false)
	WQAudio.set_level("Music", 1.0)

	_eq("มีบัส Music", AudioServer.get_bus_index("Music") >= 0, true)
	_eq("มีตัวเล่นเพลงสองตัว", WQAudio._music.size(), 2)
	_eq("ตัวเล่นเพลงอยู่บนบัส Music", WQAudio._music[0].bus, "Music")

	## ของจริง (_ready() ของ WQAudioBoot) สั่งเพลง phase1 ไปแล้วตั้งแต่ก่อนสูทนี้เริ่ม เพราะ
	## ยังไม่มีผู้เล่นผูกไว้ตอนนั้น `_want_music()` จึงตกกลับไปที่ phase1 — เล่นเพลงไว้ก่อนตรงนี้
	## ให้ชัดเจนว่ามีอะไรให้ stop_music() หยุดจริง ไม่งั้นจะ assert แค่ "หลังเรียก stop_music()
	## แล้ว music_now กลายเป็น ''" ซึ่งล้มไม่ได้เลยไม่ว่า music_now ก่อนหน้าจะเป็นอะไร (F10)
	WQAudio.play_music("phase1")
	_eq("ก่อนหยุด มีเพลงดังอยู่จริง (ให้มีอะไรให้ stop_music หยุด)", WQAudio.music_now, "phase1")
	WQAudio.stop_music()
	_eq("หยุดเพลงแล้ว music_now ว่างจริง", WQAudio.music_now, "")

	WQAudio.play_music("phase1")
	_eq("สั่งเล่นแล้วจำว่าเพลงไหนดังอยู่", WQAudio.music_now, "phase1")

	## เพลงเดิมสั่งซ้ำต้องไม่ทำอะไรเลย — นับที่ music_switches ไม่ใช่ที่ตัวเล่นที่เป็นตัวหลัก
	## เพราะ headless เข้า _silent แล้วคืนก่อนจะสลับตัวเล่นอยู่แล้ว เทสต์ที่ดูตัวเล่นจึงเขียวเสมอ
	## ไม่ว่าโค้ดจะกันการสั่งซ้ำจริงหรือไม่ (เขียวปลอมแบบเดียวกับที่ audio_check เคยโดนมาแล้ว)
	var n := WQAudio.music_switches
	WQAudio.play_music("phase1")
	_eq("สั่งเพลงเดิมซ้ำต้องไม่นับเป็นการเปลี่ยนเพลง", WQAudio.music_switches, n)

	# id ที่ไม่มีในตารางต้องไม่เปลี่ยนอะไร
	WQAudio.play_music("ไม่มีเพลงนี้")
	_eq("สั่งเพลงที่ไม่มีต้องไม่เปลี่ยนเพลงที่ดังอยู่", WQAudio.music_now, "phase1")

	WQAudio.stop_music()
	_eq("สั่งหยุดแล้วไม่มีเพลง", WQAudio.music_now, "")

	# ปิดเสียงทั้งหมดต้องครอบเพลงด้วย ไม่ใช่เงียบแค่เสียงสั้น
	WQAudio.set_muted(true)
	_eq("ปิดเสียงแล้วบัส Music ถูกปิดด้วย",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), true)
	WQAudio.set_muted(false)
	_eq("เปิดเสียงกลับแล้วบัส Music กลับมาดัง",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), false)

	## สตรีมเพลง — ทั้งสองสถานะต้องถูก: ยังไม่มีไฟล์ = null (เกมเงียบอย่างสงบ)
	## มีไฟล์แล้ว = ต้องถูกตั้งลูปไว้ ไม่ว่านามสกุลไหน เพราะไฟล์ที่ import มาไม่ได้ลูปให้เอง
	##
	## **ต้องไล่ทุกช่อง ไม่ใช่เช็กแค่ phase1** — แต่ละนามสกุลตั้งลูปคนละพร็อพเพอร์ตี้ (.wav ใช้
	## loop_mode · .ogg/.mp3 ใช้ loop) ถ้าเช็กช่องเดียว เส้นทางของนามสกุลที่ไม่ได้อยู่ในช่องนั้น
	## จะไม่มีใครตรวจเลย (พิสูจน์มาแล้ว: ลบการตั้ง loop ของ ogg/mp3 ทิ้ง สูทยังเขียวสนิท
	## เพราะตอนนั้นช่อง phase1 บังเอิญเป็น .wav)
	for id in WQMusic.ids():
		var st = WQAudio._music_stream(String(id))
		if WQMusic.path_for(String(id)) == "":
			_eq("ช่อง \"%s\" ยังไม่มีไฟล์ สตรีมจึงเป็น null" % id, st, null)
		else:
			_eq("ช่อง \"%s\" มีไฟล์แล้ว ต้องถูกตั้งลูปไว้ (%s)" % [id, WQMusic.path_for(String(id)).get_file()],
				_loops(st), true)

	# ระดับเสียงเพลงต้องลงบัสจริงและถูกจำลงไฟล์ตั้งค่า
	WQAudio.set_level("Music", 0.4)
	_eq("ระดับเสียงเพลงลงบัสจริง",
		snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), 0.01),
		snappedf(linear_to_db(0.4), 0.01))
	var cfg := ConfigFile.new()
	_eq("เขียนไฟล์ตั้งค่าแล้ว", cfg.load(WQAudio.settings_path), OK)
	_eq("จำระดับเสียงเพลง", float(cfg.get_value("audio", "music", -1.0)), 0.4)
	WQAudio._levels["Music"] = 1.0
	WQAudio._load_settings()
	_eq("โหลดระดับเสียงเพลงกลับมาได้", WQAudio.get_level("Music"), 0.4)
	WQAudio.set_level("Music", 1.0)

	# แผงปรับเสียงต้องมีสไลเดอร์เพลง และขยับแล้วมีผลจริง
	var panel := WQAudioPanel.new()
	root.add_child(panel)
	await process_frame
	_eq("สไลเดอร์เพลงตั้งค่าตามที่จำไว้", panel._music.value, 1.0)
	panel._music.value = 0.5
	await process_frame
	_eq("ขยับสไลเดอร์เพลงแล้วระดับเสียงเปลี่ยนจริง", WQAudio.get_level("Music"), 0.5)
	WQAudio.set_level("Music", 1.0)
	root.remove_child(panel)
	panel.free()

	_completed["lane"] = true


## เพลงต้องเปลี่ยนตามสถานะจริงของผู้เล่นที่ผูกไว้ ไม่ใช่ให้ ui/ สั่ง (กฎเหล็กข้อ 6)
## และวิกฤตต้องชนะทุกเงื่อนไข — ตอนสุขภาพจะหมดหรือภัยพิบัติลงแล้วยังได้ยินเพลงเดินเรื่อยๆ
## คือเกมโกหกผู้เล่นว่าทุกอย่างปกติดี
func _check_policy() -> void:
	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260821, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
	]})
	var me = m.players[0]

	WQAudio.bind(m)
	WQAudio.bind_player(me)

	me.health = 70.0
	me.phase = 1
	m.active_disasters = []
	me.changed.emit()
	_eq("ด่าน 1 ปกติ ได้เพลงด่าน 1", WQAudio.music_now, "phase1")

	me.phase = 2
	me.changed.emit()
	_eq("เข้าด่าน 2 แล้วเปลี่ยนเพลง", WQAudio.music_now, "phase2")

	me.health = 30.0
	me.changed.emit()
	_eq("สุขภาพต่ำกว่าเกณฑ์ วิกฤตชนะเงื่อนไขด่าน", WQAudio.music_now, "crisis")

	me.health = 70.0
	me.changed.emit()
	_eq("สุขภาพกลับมา ได้เพลงด่าน 2 คืน", WQAudio.music_now, "phase2")

	m.active_disasters = [{"def": {}, "left": 2}]
	m.month_ended.emit(3)
	_eq("มีภัยพิบัติค้างอยู่ ได้เพลงวิกฤต", WQAudio.music_now, "crisis")

	m.active_disasters = []
	m.month_ended.emit(4)
	_eq("ภัยพิบัติหมดอายุแล้ว กลับไปเพลงด่าน", WQAudio.music_now, "phase2")

	# ========== F5: ฮิสเทอรีซิสกันเพลงกระพริบตอนสุขภาพแกว่งคาบเกี่ยวเกณฑ์ 40 ==========
	# สุขภาพจริงวิ่งขึ้นลงหลักหน่วยทุกเดือน (`changed` ยิงหลายสิบครั้ง) — ถ้าตัดสินจาก
	# < CRISIS_HEALTH ดิบๆ การแกว่ง 39↔41 จะเฟดไขว้ไปกลับเต็มรอบและเพลงเริ่มใหม่จากห้องแรก
	# ทุกครั้ง ต้อง "เข้า" ที่ 40 แต่ "ออก" ต่อเมื่อถึง CRISIS_EXIT (45) เท่านั้น
	var switches_before := WQAudio.music_switches
	me.health = 39.0
	me.changed.emit()
	_eq("ตกต่ำกว่า 40 เข้าวิกฤต", WQAudio.music_now, "crisis")

	me.health = 41.0
	me.changed.emit()
	me.health = 39.0
	me.changed.emit()
	me.health = 41.0
	me.changed.emit()
	_eq("แกว่ง 41<->39 คาบเกี่ยว 40 (ยังไม่ถึง 45) ต้องยังวิกฤตอยู่ ไม่ใช่ออกแล้วเข้าใหม่",
		WQAudio.music_now, "crisis")
	_eq("แกว่งรอบเกณฑ์ 4 ครั้งไม่ทำให้ music_switches บาน (สลับแค่ตอนเข้าวิกฤตครั้งแรกครั้งเดียว)",
		WQAudio.music_switches, switches_before + 1)

	me.health = 42.0
	me.changed.emit()
	_eq("สุขภาพ 42 (ระหว่าง 40 กับ 45) หลังเคยตกวิกฤต ยังเป็นเพลงวิกฤตอยู่ ไม่ใช่ phase2",
		WQAudio.music_now, "crisis")

	me.health = 45.0
	me.changed.emit()
	_eq("สุขภาพถึง CRISIS_EXIT (45) แล้วออกจากวิกฤตจริง กลับไปเพลงด่าน", WQAudio.music_now, "phase2")

	me.health = 70.0
	me.changed.emit()

	# ========== F7: ภัยพิบัติกลางเดือน (disaster_started) ต้องได้เพลงวิกฤตทันที ==========
	# เทสต์เดิมสร้างภัยพิบัติด้วยการเซ็ต active_disasters แล้วยิงแค่ month_ended เท่านั้น
	# _on_disaster() จึงลบทิ้งได้โดยไม่มีเทสต์ไหนล้ม ทั้งที่ disaster_started คือจังหวะจริงที่
	# ผู้เล่นเจอกลางเดือน (ไม่ใช่แค่ตอนสิ้นเดือน) — ยิงสัญญาณจริงตรงๆ แบบเดียวกับที่ core ยิง
	me.phase = 2
	m.active_disasters = []
	me.changed.emit()
	_eq("ก่อนภัยพิบัติ เพลงด่าน 2 อยู่", WQAudio.music_now, "phase2")
	m.active_disasters = [{"def": {}, "left": 2}]
	m.disaster_started.emit({})
	_eq("disaster_started ยิงกลางเดือนจริง ได้เพลงวิกฤตทันที", WQAudio.music_now, "crisis")
	m.active_disasters = []
	m.month_ended.emit(5)
	_eq("ภัยพิบัติจากสัญญาณตรงหมดอายุแล้ว กลับไปเพลงด่าน", WQAudio.music_now, "phase2")

	# ยังไม่มีผู้เล่นและยังไม่มีแมตช์ผูกไว้เลย (หน้าเลือกอาชีพ) ต้องเป็นเพลงด่าน 1
	# เดิม assert นี้เรียกแค่ bind_player(null) ป้ายเขียนว่า "ยังไม่มีแมตช์" แต่ไม่เคยปลด
	# แมตช์จริง (F11) — เติม bind(null) ให้ตรงกับที่ป้ายบอก แล้วได้เช็กเพิ่มฟรีหนึ่งข้อ
	WQAudio.bind_player(null)
	WQAudio.bind(null)
	_eq("ปลดแมตช์แล้ว ไม่มีแมตช์ผูกอยู่จริง", WQAudio._match, null)
	WQAudio.stop_music()
	WQAudio._refresh_music()
	_eq("ยังไม่มีแมตช์ ได้เพลงด่าน 1", WQAudio.music_now, "phase1")

	_completed["policy"] = true


## สตรีมนี้ถูกตั้งให้เล่นวนแล้วหรือยัง — แต่ละชนิดไฟล์ใช้คนละพร็อพเพอร์ตี้
func _loops(st) -> bool:
	if st is AudioStreamWAV:
		return (st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD \
			and (st as AudioStreamWAV).loop_end > 0
	if st is AudioStreamOggVorbis or st is AudioStreamMP3:
		return bool(st.loop)
	return false


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
