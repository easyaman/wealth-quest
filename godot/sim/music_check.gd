extends SceneTree
## ตรวจระบบเพลงพื้นหลังแบบ headless
##   godot --headless --path . --script res://sim/music_check.gd
##
## แยกจาก audio_check เพราะนั่นยาว 795 บรรทัดแล้ว และ sim/ แยกสูทตามระบบอยู่แล้ว
## ที่นี่ตรวจได้แค่ "โครงถูกไหม · มีเสียงออกไหม · เลือกเพลงถูกตัวไหม"
## ไม่ได้ตรวจว่าเพราะไหม — อันนั้นต้องเปิดฟังเอง: WQ_MUSIC=phase1 godot --path .

const MUSIC_DIR := "res://audio/music"
const ALL_CHECKS: Array[String] = ["tracks"]

var _fails := 0
## เช็กไหนที่รันจนจบฟังก์ชันจริง — กันสูทเขียวปลอมตอน SCRIPT ERROR หลุดกลางฟังก์ชัน
## (กติกาเดียวกับ sim/audio_check.gd ซึ่งเคยเจอเคสนี้จริงมาแล้ว)
var _completed := {}


func _init() -> void:
	_check_tracks()
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


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
