extends SceneTree
## ตรวจระบบเพลงพื้นหลังแบบ headless
##   godot --headless --path . --script res://sim/music_check.gd
##
## แยกจาก audio_check เพราะนั่นยาว 795 บรรทัดแล้ว และ sim/ แยกสูทตามระบบอยู่แล้ว
## ที่นี่ตรวจได้แค่ "โครงถูกไหม · มีเสียงออกไหม · เลือกเพลงถูกตัวไหม"
## ไม่ได้ตรวจว่าเพราะไหม — อันนั้นต้องเปิดฟังเอง: WQ_MUSIC=phase1 godot --path .

const MUSIC_DIR := "res://audio/music"
const ALL_CHECKS: Array[String] = ["tracks", "files", "lane", "policy"]

var _fails := 0
## เช็กไหนที่รันจนจบฟังก์ชันจริง — กันสูทเขียวปลอมตอน SCRIPT ERROR หลุดกลางฟังก์ชัน
## (กติกาเดียวกับ sim/audio_check.gd ซึ่งเคยเจอเคสนี้จริงมาแล้ว)
var _completed := {}


func _init() -> void:
	_check_tracks()
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


## ตารางโน้ตของทุกเพลงต้องมีโครงตรงกันทุกช่อง ไม่งั้นทำนองกับเบสจะเหลื่อมกันทั้งเพลง
## โดยไม่มี error ให้เห็น — เป็นความผิดพลาดที่เกิดง่ายที่สุดเวลาแก้ทำนอง (ลืมเติม ".")
func _check_tracks() -> void:
	_eq("มีเพลงอย่างน้อยหนึ่งเพลง", WQMusic.ids().size() >= 1, true)

	_eq("A4 = 440 Hz", snappedf(WQMusic.note_hz("A4"), 0.01), 440.0)
	_eq("C4 = 261.63 Hz", snappedf(WQMusic.note_hz("C4"), 0.01), 261.63)
	_eq("A#3 = Bb3", snappedf(WQMusic.note_hz("A#3"), 0.01), snappedf(WQMusic.note_hz("Bb3"), 0.01))
	_eq("โน้ตสูงขึ้นหนึ่งอ็อกเทฟ = ความถี่สองเท่า",
		snappedf(WQMusic.note_hz("A5") / WQMusic.note_hz("A4"), 0.001), 2.0)

	for id in WQMusic.ids():
		var t: Dictionary = WQMusic.TRACKS[id]
		var lead_bars := WQMusic.bars(String(t["lead"]))
		for ch in ["lead", "bass", "drum"]:
			_eq("\"%s\" ช่อง %s มีจำนวนห้องเท่ากับทำนอง" % [id, ch],
				WQMusic.bars(String(t[ch])).size(), lead_bars.size())
			_eq("\"%s\" ช่อง %s มีจำนวนช่องต่อห้องตรงกับทำนองทุกห้อง" % [id, ch],
				WQMusic.bars(String(t[ch])), lead_bars)
		for b in lead_bars:
			_eq("\"%s\" ทุกห้องยาวเท่ากับ beats_per_bar" % id, b, int(t["beats_per_bar"]))

		# โทเคนที่พิมพ์ผิดต้องไม่เงียบหาย — ไม่งั้นโน้ตนั้นหายไปจากเพลงโดยไม่มีใครรู้
		for ch in ["lead", "bass"]:
			for tok in WQMusic.cells(String(t[ch])):
				if tok == "." or tok == "-": continue
				_eq("\"%s\" โน้ต \"%s\" ในช่อง %s อ่านออก" % [id, tok, ch],
					WQMusic.note_hz(tok) > 0.0, true)
		for tok in WQMusic.cells(String(t["drum"])):
			_eq("\"%s\" โทเคนกลอง \"%s\" อ่านออก" % [id, tok],
				tok == "." or tok == "-" or WQMusic.DRUM.has(tok), true)

		# ความยาวต้องลงตัวพอดีห้อง ไม่งั้นรอยต่อลูปเบี้ยว
		var cells := WQMusic.cells(String(t["lead"])).size()
		_eq("\"%s\" ความยาววินาทีตรงกับจำนวนช่อง × จังหวะ" % id,
			snappedf(WQMusic.length_sec(id), 0.0001),
			snappedf(float(cells) * 60.0 / float(t["bpm"]), 0.0001))

		var pcm := WQMusic.render(id)
		_eq("\"%s\" จำนวนแซมเปิลตรงกับความยาวเป๊ะ" % id,
			pcm.size() / 2, int(round(WQMusic.length_sec(id) * float(WQSynth.RATE))))
		_eq("\"%s\" อบซ้ำได้ไบต์เดิมเป๊ะ" % id, WQMusic.render(id) == pcm, true)

		var peak := 0
		var i := 0
		while i + 1 < pcm.size():
			peak = maxi(peak, absi(pcm.decode_s16(i)))
			i += 2
		_eq("\"%s\" ดังพอให้ได้ยิน (พีคเกิน 10%% ของเต็มสเกล)" % id, peak > 3276, true)
		_eq("\"%s\" ไม่ตัดยอดจนแตก (พีคไม่ชนเพดาน)" % id, peak < 32767, true)

		# ตรวจว่าแต่ละช่องดังจริงด้วยตัวเอง — ถ้าช่องไหนเงียบหายเข้าไปในคนอื่นจะจับได้
		for ch in ["lead", "bass", "drum"]:
			var cpcm := WQMusic.render(id, ch)
			var cpeak := 0
			var ci := 0
			while ci + 1 < cpcm.size():
				cpeak = maxi(cpeak, absi(cpcm.decode_s16(ci)))
				ci += 2
			_eq("\"%s\" ช่อง %s ดังจริงด้วยตัวเอง (พีคเกิน 5%% ของเต็มสเกล)" % [id, ch], cpeak > 1638, true)

		var st := WQMusic.stream(id)
		_eq("\"%s\" สตรีมตั้งลูปไว้แล้ว" % id, st.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		_eq("\"%s\" จุดจบลูปอยู่ท้ายเพลงพอดี" % id, st.loop_end, pcm.size() / 2)

	_completed["tracks"] = true


## ไฟล์เพลงต้องครบ ไม่มีกำพร้า และต้องเป็นของที่ตัวอบทำเองจริงๆ
## กติกาเดียวกับ audio/sfx ทุกข้อ — ต่างแค่โฟลเดอร์
func _check_files() -> void:
	var on_disk := {}
	var d := DirAccess.open(MUSIC_DIR)
	if d == null:
		_fails += 1
		print("  ❌ ไม่มีโฟลเดอร์ %s" % MUSIC_DIR)
		return
	for f in d.get_files():
		if f.ends_with(".wav"): on_disk[f.get_basename()] = true

	var stamp := FileAccess.open("%s/baked.json" % MUSIC_DIR, FileAccess.READ)
	_eq("มี baked.json ของเพลง", stamp != null, true)
	if stamp == null: return
	var marks = JSON.parse_string(stamp.get_as_text())
	stamp.close()
	_eq("baked.json ของเพลงเป็น Dictionary", marks is Dictionary, true)
	if not marks is Dictionary: return

	var seen := {}
	for id in WQMusic.ids():
		var path := "%s/%s.wav" % [MUSIC_DIR, id]
		_eq("มีไฟล์เพลง \"%s\"" % id, ResourceLoader.exists(path), true)
		if not ResourceLoader.exists(path): continue
		on_disk.erase(id)

		var abs := ProjectSettings.globalize_path(path)
		_eq("แฮชที่จดของ \"%s\" ตรงกับไฟล์บนดิสก์จริง" % id,
			String(marks.get(id, "")), FileAccess.get_sha256(abs))

		var pcm := WQWavProbe.pcm(abs)
		_eq("\"%s\" มีข้อมูลเสียงอยู่จริงในไฟล์" % id, pcm.size() > 0, true)
		_eq("\"%s\" ดังพอให้ได้ยิน (พีคเกิน 10%% ของเต็มสเกล)" % id,
			WQWavProbe.peak(pcm) > 3276, true)
		_eq("\"%s\" ยาวตรงกับที่ตารางโน้ตบอก" % id,
			pcm.size() / 2, int(round(WQMusic.length_sec(id) * float(WQSynth.RATE))))

		var key := Marshalls.raw_to_base64(pcm).sha256_text()
		_eq("\"%s\" ไม่ได้เป็นเพลงชุดเดียวกับ \"%s\"" % [id, String(seen.get(key, ""))],
			seen.has(key), false)
		seen[key] = id

	_eq("ไม่มีไฟล์เพลงกำพร้า", on_disk.keys(), [])
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

	WQAudio.stop_music()
	_eq("เริ่มมายังไม่มีเพลง", WQAudio.music_now, "")

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

	# สตรีมของเพลงต้องตั้งลูปไว้ — ไฟล์ที่ import มาได้ loop_mode = 0 เสมอ
	var st := WQAudio._music_stream("phase1") as AudioStreamWAV
	_eq("สตรีมเพลงตั้งลูปไว้", st.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	_eq("จุดจบลูปไม่ใช่ศูนย์", st.loop_end > 0, true)

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

	# ยังไม่มีผู้เล่นผูกไว้ (หน้าเลือกอาชีพ) ต้องเป็นเพลงด่าน 1
	WQAudio.bind_player(null)
	WQAudio.stop_music()
	WQAudio._refresh_music()
	_eq("ยังไม่มีแมตช์ ได้เพลงด่าน 1", WQAudio.music_now, "phase1")

	_completed["policy"] = true


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
