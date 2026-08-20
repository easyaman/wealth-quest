extends SceneTree
## ตรวจระบบเสียงแบบ headless — ไม่ต้องมีลำโพง
##   godot --headless --path . --script res://sim/audio_check.gd
##
## headless ใช้ไดรเวอร์เสียง `Dummy` เสียงจึงไม่ออกจริง ที่นี่ตรวจได้แค่
## "มีของครบไหม · ยิงถูกจังหวะไหม" ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง
## ฟังจริงด้วย:  WQ_SFX=<id> godot --path .

const SFX_DIR := "res://audio/sfx"

var _fails := 0


func _init() -> void:
	_check_bank()
	_check_synth()
	_check_files()
	_check_acted()
	print("audio_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## ทุก id ที่ตารางสัญญาณอ้างถึง ต้องมีสเปกอยู่จริง ไม่งั้นเกมจะเงียบเฉพาะบางเหตุการณ์
## โดยไม่มี error ให้เห็น — เป็นบั๊กที่หาเจอยากที่สุดของระบบเสียง
func _check_bank() -> void:
	_eq("มีสเปกเสียงครบ 30 ตัว", WQBank.SPEC.size(), 30)
	for kind in WQBank.FROM_ACTED:
		_eq("acted(%s) ชี้ไปเสียงที่มีจริง" % kind,
			WQBank.SPEC.has(String(WQBank.FROM_ACTED[kind])), true)
	for id in WQBank.UI_IDS:
		_eq("เสียง UI \"%s\" มีสเปก" % id, WQBank.SPEC.has(String(id)), true)
	# claim_dream ต้องไม่อยู่ในตาราง ไม่งั้นเสียงชนะจะดังสองครั้ง
	# เพราะ add_champion() ยิง player_finished ตามมาทันทีอยู่แล้ว
	_eq("acted(dream) ต้องไม่มีเสียงของตัวเอง", WQBank.FROM_ACTED.has("dream"), false)
	for id in WQBank.ids():
		var spec: Array = WQBank.SPEC[id]
		_eq("สเปก \"%s\" มี 7 ช่อง" % id, spec.size(), 7)
		_eq("คลื่นของ \"%s\" เป็นแบบที่ synth รู้จัก" % id,
			["square", "triangle", "noise"].has(String(spec[0])), true)
		_eq("\"%s\" ยาวไม่เกิน 2 วินาที" % id, float(spec[3]) <= 2.0, true)


func _check_synth() -> void:
	var spec: Array = WQBank.SPEC["click"]
	var data := WQSynth.render(spec)
	_eq("ความยาวข้อมูล = วินาที × อัตราสุ่ม × 2 ไบต์",
		data.size(), int(WQSynth.RATE * float(spec[3])) * 2)

	# เสียงต้องไม่เงียบสนิท ไม่งั้นอบไฟล์ครบ 30 ตัวแล้วเกมก็ยังเงียบอยู่ดี
	var peak := 0
	for i in int(data.size() / 2.0):
		peak = maxi(peak, absi(data.decode_s16(i * 2)))
	_eq("เสียงไม่เงียบสนิท", peak > 3000, true)

	# อบซ้ำต้องได้ไบต์เดิมเป๊ะ ไม่งั้น sha256 เปลี่ยนทุกครั้งที่รันตัวอบ
	# แล้วท่อ "ไม่ทับงานคน" จะพังทั้งท่อ (noise ต้องใช้ตัวสุ่มที่ตั้ง seed ไว้)
	_eq("สังเคราะห์ซ้ำได้ผลเหมือนเดิม",
		WQSynth.render(WQBank.SPEC["travel"]), WQSynth.render(WQBank.SPEC["travel"]))

	# f0/f1 ของคลื่น noise ต้องมีผลกับเสียงจริง (sample-and-hold) ไม่ใช่แค่ตัวเลขในตารางที่ไม่ทำอะไร
	# ตั้งความยาว/attack/decay/ระดับเสียงให้เหมือนกันทุกอย่าง เหลือแค่ความถี่ที่ต่างกัน
	var noise_lo := ["noise", 60.0, 60.0, 0.30, 0.0, 0.0, 0.50]
	var noise_hi := ["noise", 4000.0, 4000.0, 0.30, 0.0, 0.0, 0.50]
	_eq("ความถี่ต่างกันของคลื่น noise ต้องได้ไบต์ต่างกัน",
		WQSynth.render(noise_lo) == WQSynth.render(noise_hi), false)

	var st := WQSynth.stream(spec)
	_eq("สตรีมเป็น 16-bit", st.format, AudioStreamWAV.FORMAT_16_BITS)
	_eq("สตรีมเป็น mono", st.stereo, false)
	_eq("อัตราสุ่มตรงกับ synth", st.mix_rate, WQSynth.RATE)


## ไฟล์เสียงต้องครบและต้องไม่มีไฟล์กำพร้า
## ไฟล์กำพร้า = เคยมี id นี้แล้วลบออกจาก bank แต่ลืมลบไฟล์ → repo โตขึ้นเรื่อยๆ โดยไม่มีใครเล่น
func _check_files() -> void:
	var on_disk := {}
	var d := DirAccess.open(SFX_DIR)
	if d == null:
		_fails += 1
		print("  ❌ ไม่มีโฟลเดอร์ %s" % SFX_DIR)
		return
	for f in d.get_files():
		if f.ends_with(".wav"): on_disk[f.get_basename()] = true

	for id in WQBank.ids():
		var path := "%s/%s.wav" % [SFX_DIR, id]
		_eq("มีไฟล์เสียง \"%s\"" % id, ResourceLoader.exists(path), true)
		if not ResourceLoader.exists(path): continue
		var st = load(path)
		_eq("\"%s\" โหลดเป็น AudioStreamWAV ได้" % id, st is AudioStreamWAV, true)
		on_disk.erase(id)

	_eq("ไม่มีไฟล์เสียงกำพร้า", on_disk.keys(), [])

	var stamp := FileAccess.open("%s/baked.json" % SFX_DIR, FileAccess.READ)
	_eq("มี baked.json", stamp != null, true)
	if stamp == null: return
	var marks = JSON.parse_string(stamp.get_as_text())
	stamp.close()
	_eq("baked.json เป็น Dictionary", marks is Dictionary, true)
	if not marks is Dictionary: return

	# เช็กแค่ "จำนวนเท่ากัน" ไม่พอ — 30 รายการที่ key ผิดหรือแฮชเก่าก็นับผ่านได้เหมือนกัน
	# ทั้งที่เป็นความเสียหายแบบเดียวกับที่ตราประทับนี้มีไว้จับ ต้องเทียบ "ชุด id" ตรงเป๊ะ
	# แล้วไล่เทียบแฮชที่จดไว้กับแฮชจริงของไฟล์บนดิสก์ทีละตัว
	var mark_ids: Array = marks.keys()
	mark_ids.sort()
	_eq("baked.json จดครบทุก id ไม่ขาดไม่เกิน", mark_ids, WQBank.ids())

	for id in WQBank.ids():
		var path := "%s/%s.wav" % [SFX_DIR, id]
		if not ResourceLoader.exists(path): continue
		var abs := ProjectSettings.globalize_path(path)
		_eq("แฮชที่จดของ \"%s\" ตรงกับไฟล์บนดิสก์จริง" % id,
			String(marks.get(id, "")), FileAccess.get_sha256(abs))


## `acted` ต้องยิงเมื่อทำสำเร็จ และ **ห้ามยิงเมื่อล้มเหลว**
## ถ้ายิงตอนล้มเหลวด้วย ผู้เล่นจะได้ยินเสียง "กู้เงินสำเร็จ" ทั้งที่วงเงินไม่พอ
func _check_acted() -> void:
	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var p = m.players[0]

	var heard: Array[String] = []
	p.acted.connect(func(kind: String): heard.append(kind))

	# --- สำเร็จ ---
	p.place = "home"
	p.rest()
	_eq("rest สำเร็จแล้วยิง acted", heard, ["rest"] as Array[String])

	heard.clear()
	p.travel_to("office")
	_eq("travel_to สำเร็จแล้วยิง acted", heard, ["travel"] as Array[String])

	heard.clear()
	p.set_sleep(0)          # อยู่ที่ออฟฟิศ ตั้งค่าการนอนไม่ได้ → ต้องเงียบ
	_eq("set_sleep ผิดที่แล้วต้องไม่ยิง", heard, [] as Array[String])

	# --- ล้มเหลว: เวลาหมด ---
	heard.clear()
	p.hours = 0
	_eq("side_job เวลาไม่พอต้องคืน ok=false", bool(p.side_job("ot").get("ok", true)), false)
	_eq("ล้มเหลวแล้วต้องไม่ยิง acted", heard, [] as Array[String])

	# --- ล้มเหลว: เงินไม่พอ ---
	heard.clear()
	p.hours = p.get_hours_max()
	p.cash = 0.0
	p.place = "mall"
	_eq("ซื้อพาหนะเงินไม่พอต้องคืน ok=false",
		bool(p.buy_vehicle("luxury").get("ok", true)), false)
	_eq("ซื้อไม่สำเร็จแล้วต้องไม่ยิง acted", heard, [] as Array[String])

	# ทุก kind ที่ core ยิงได้ ต้องมีที่อยู่ในตาราง (ยกเว้น dream ที่ตั้งใจไม่ให้มีเสียง)
	for kind in ["travel", "buy", "sell", "loan", "repay", "ot", "freelance",
			"scout", "study", "gym", "resort", "rest", "lifestyle", "phase2"]:
		_eq("kind \"%s\" มีที่อยู่ในตาราง" % kind, WQBank.FROM_ACTED.has(kind), true)


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
