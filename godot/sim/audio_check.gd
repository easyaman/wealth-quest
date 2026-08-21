extends SceneTree
## ตรวจระบบเสียงแบบ headless — ไม่ต้องมีลำโพง
##   godot --headless --path . --script res://sim/audio_check.gd
##
## headless ใช้ไดรเวอร์เสียง `Dummy` เสียงจึงไม่ออกจริง ที่นี่ตรวจได้แค่
## "มีของครบไหม · ยิงถูกจังหวะไหม" ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง
## ฟังจริงด้วย:  WQ_SFX=<id> godot --path .

const SFX_DIR := "res://audio/sfx"
const ALL_CHECKS: Array[String] = ["bank", "synth", "files", "acted", "audio", "wiring",
	"settings"]

var _fails := 0
## เช็กไหนที่ "รันจนจบฟังก์ชันจริง" — ไม่ใช่แค่ไม่มีบรรทัดไหนล้มด้วย _eq()
## มีเพราะ SCRIPT ERROR (เช่น เข้าถึงพร็อพเพอร์ตี้ที่ยังไม่มี) ทำให้ฟังก์ชันหยุดกลางคันแล้ว
## คืนกลับไปที่ผู้เรียกเงียบๆ — _fails ไม่ขยับเลยเพราะไม่มี _eq() ตัวไหนได้รัน
## ผลคือสูทเขียวทั้งที่เช็กพังตั้งแต่ก่อนถึงบรรทัดสุดท้าย (เคยเกิดจริงตอน TDD ข้อ acted:
## ตอนยังไม่มีสัญญาณ `acted` สคริปต์ error กลางฟังก์ชันแต่ audio_check ก็ยังพิมพ์ "ผ่านทั้งหมด ✅")
var _completed := {}


func _init() -> void:
	_check_bank()
	_check_synth()
	_check_files()
	_check_acted()
	## รอหนึ่งเฟรมก่อนแตะ WQAudio — สคริปต์ที่ `extends SceneTree` เรียก play() ตั้งแต่ _init()
	## ไม่ได้ ("Playback can only happen when a node is inside the scene tree") autoload กับ
	## pool ต้องได้เข้า tree ก่อน ซึ่งเกิดหลัง _init() คืนค่ากลับไปหนึ่งเฟรม
	await process_frame
	_check_audio()
	await _check_wiring()
	await _check_settings()
	for name in ALL_CHECKS:
		if not _completed.get(name, false):
			_fails += 1
			print("  ❌ เช็ก \"%s\" ไม่รันจบฟังก์ชัน — สคริปต์พังกลางทางก่อนถึงเครื่องหมายจบ" % name)
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
	_completed["bank"] = true


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
	_completed["synth"] = true


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

	## **ตรวจได้แค่ว่า "มีเสียงออกมาจริงและไม่ซ้ำกัน" ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง**
	## ต้องมีเพราะสองความเสียหายนี้เงียบสนิทกับเช็กข้างบน: ไฟล์ที่แอมพลิจูดเกือบศูนย์ยัง
	## "มีไฟล์ · โหลดได้ · แฮชตรง" ครบทุกข้อ และสเปกที่ก๊อปมาวางแล้วลืมแก้ก็ให้ไบต์ชุดเดียวกัน
	## เป๊ะ = สองเหตุการณ์คนละเรื่องดังเหมือนกันจนแยกไม่ออก · ส่วน "ฟังรู้เรื่องไหม" ต้องใช้หูคน
	## ฟังทีละตัวจริงๆ ด้วย WQ_SFX=<id> godot --path . (เช็กลิสต์อยู่ใน audio/README.md)
	## อ่าน **ไฟล์ดิบบนดิสก์** ไม่ใช่ตัวที่ load() คืนมา — Godot นำเข้า .wav เป็น QOA (ถูกบีบอัด)
	## `AudioStreamWAV.data` จึงเป็นไบต์ QOA ไม่ใช่ PCM ถอดเป็น s16 แล้วได้ค่าขยะ (ตรวจแล้ว:
	## ทุกไฟล์ให้พีค ~32767 เท่ากันหมด = เช็กที่ผ่านตลอดโดยไม่ได้ตรวจอะไรเลย) และไฟล์ดิบคือ
	## สิ่งที่คนทำเสียงจะเอามาวางทับจริงๆ ด้วย
	var seen_bytes := {}
	for id in WQBank.ids():
		var abs := ProjectSettings.globalize_path("%s/%s.wav" % [SFX_DIR, id])
		if not FileAccess.file_exists(abs): continue
		var pcm := WQWavProbe.pcm(abs)
		_eq("\"%s\" มีข้อมูลเสียงอยู่จริงในไฟล์" % id, pcm.size() > 0, true)
		var peak := WQWavProbe.peak(pcm)
		_eq("\"%s\" ดังพอให้ได้ยิน (พีคเกิน 10%% ของเต็มสเกล)" % id, peak > 3276, true)

		var key := Marshalls.raw_to_base64(pcm).sha256_text()
		_eq("\"%s\" ไม่ได้เป็นเสียงชุดเดียวกับ \"%s\"" % [id, String(seen_bytes.get(key, ""))],
			seen_bytes.has(key), false)
		seen_bytes[key] = id

	_completed["files"] = true


## `acted` ต้องยิงเมื่อทำสำเร็จ และ **ห้ามยิงเมื่อล้มเหลว**
## ถ้ายิงตอนล้มเหลวด้วย ผู้เล่นจะได้ยินเสียง "กู้เงินสำเร็จ" ทั้งที่วงเงินไม่พอ
##
## ทุกจุดยิงทั้ง 17 จุดต้องมีเทสต์บวก (ยิงจริงพร้อม kind ที่ถูก) ไม่ใช่แค่เช็กว่าตารางเสียงมี
## key ครบ (นั่นเช็ก audio/bank.gd ไม่ได้เช็ก player.gd) — ไม่งั้นถ้าใครลบ `acted.emit(...)`
## บรรทัดเดียวออกจาก core แล้วลืม สูทนี้จะยังเขียวอยู่ดี โดยเฉพาะ `buy_vehicle` ที่มีทางออก
## สำเร็จสองทาง (ทางลดระดับรถคืนก่อนจบฟังก์ชัน กับทางซื้อปกติท้ายฟังก์ชัน) ต้องแยกเทสต์
## เพราะเป็นคนละพาธที่ตัดกันเอง (early return) — เทสต์ทางหนึ่งพิสูจน์อะไรไม่ได้เกี่ยวกับอีกทาง
func _check_acted() -> void:
	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var p = m.players[0]

	var heard: Array[String] = []
	## เหมือน `heard` แต่ **ไม่เคยถูกล้าง** — สะสมทุก kind ที่ core ยิงจริงตลอดทั้งฟังก์ชัน
	## ใช้เช็กทิศ "core → ตารางเสียง" ตอนท้าย ซึ่ง `_check_bank()` เช็กแทนไม่ได้เพราะมันวิ่ง
	## จากตารางออกไปหาสเปก ลบ key ทิ้งทั้งบรรทัดลูปก็แค่สั้นลง ไม่มีอะไรล้ม (ลองลบ "gym"
	## ออกจาก FROM_ACTED แล้วสูทยังเขียวมาแล้วจริงๆ = การกระทำนั้นเงียบสนิทโดยไม่มีใครเตือน)
	var all_heard: Array[String] = []
	p.acted.connect(func(kind: String): heard.append(kind))
	p.acted.connect(func(kind: String): all_heard.append(kind))

	# --- สำเร็จ: rest ---
	p.place = "home"
	p.rest()
	_eq("rest สำเร็จแล้วยิง acted", heard, ["rest"] as Array[String])

	# --- สำเร็จ: travel_to ---
	heard.clear()
	p.travel_to("office")
	_eq("travel_to สำเร็จแล้วยิง acted", heard, ["travel"] as Array[String])

	# --- ล้มเหลว: set_sleep ผิดที่ (อยู่ office ไม่ใช่ home) ---
	heard.clear()
	p.set_sleep(0)
	_eq("set_sleep ผิดที่แล้วต้องไม่ยิง", heard, [] as Array[String])

	# --- ล้มเหลว: เวลาหมด ---
	heard.clear()
	p.hours = 0
	_eq("side_job เวลาไม่พอต้องคืน ok=false", bool(p.side_job("ot").get("ok", true)), false)
	_eq("ล้มเหลวแล้วต้องไม่ยิง acted", heard, [] as Array[String])

	# --- ล้มเหลว: เงินไม่พอ (ทางซื้อพาหนะปกติ ไม่ใช่ทางลดระดับ) ---
	heard.clear()
	p.hours = p.get_hours_max()
	p.cash = 0.0
	p.place = "mall"
	_eq("ซื้อพาหนะเงินไม่พอต้องคืน ok=false",
		bool(p.buy_vehicle("luxury").get("ok", true)), false)
	_eq("ซื้อไม่สำเร็จแล้วต้องไม่ยิง acted", heard, [] as Array[String])

	# ========== เทสต์บวก: ทุกจุดยิงทั้ง 17 จุด ==========

	# --- set_sleep สำเร็จ (kind lifestyle) ---
	heard.clear()
	p.place = "home"
	_eq("set_sleep สำเร็จ ok=true", bool(p.set_sleep(1).get("ok", false)), true)
	_eq("set_sleep สำเร็จแล้วยิง acted(lifestyle)", heard, ["lifestyle"] as Array[String])

	# --- set_food สำเร็จ (kind lifestyle) ---
	heard.clear()
	_eq("set_food สำเร็จ ok=true", bool(p.set_food("cook").get("ok", false)), true)
	_eq("set_food สำเร็จแล้วยิง acted(lifestyle)", heard, ["lifestyle"] as Array[String])

	# --- buy_vehicle: ทางซื้อปกติ (ท้ายฟังก์ชัน) — ซื้อ moto จากเดิมที่มี public อยู่ ---
	# ดัชนี moto(1) ไม่ต่ำกว่า public(0) เลยต้องเดินผ่านพาธซื้อปกติ ไม่ใช่พาธลดระดับ
	heard.clear()
	p.place = "mall"
	p.vehicle = "public"
	p.liabilities = []
	p.cash = 200000.0
	var buy_r = p.buy_vehicle("moto")
	_eq("buy_vehicle ซื้อปกติสำเร็จ ok=true", bool(buy_r.get("ok", false)), true)
	_eq("ได้พาหนะใหม่จริง", p.vehicle, "moto")
	_eq("buy_vehicle ทางซื้อปกติสำเร็จแล้วยิง acted(buy)", heard, ["buy"] as Array[String])

	# --- buy_vehicle: ทางลดระดับรถ (early return กลางฟังก์ชัน) — ขาย moto ลงมาเป็น public ---
	# ดัชนี public(0) < moto(1) ต้องเข้าเงื่อนไข downgrade แล้ว return ก่อนถึงบรรทัดพาธปกติ
	# เทสต์นี้แยกจากด้านบนโดยเจตนา — ถ้าลบ acted.emit ที่บรรทัดพาธ downgrade เฉยๆ (ไม่แตะ
	# พาธปกติ) เทสต์ด้านบนจะยังผ่าน แต่เทสต์นี้จะจับได้ทันทีเพราะ heard จะว่างเปล่า
	heard.clear()
	var downgrade_r = p.buy_vehicle("public")
	_eq("buy_vehicle ลดระดับสำเร็จ ok=true", bool(downgrade_r.get("ok", false)), true)
	_eq("ลดระดับพาหนะจริง", p.vehicle, "public")
	_eq("buy_vehicle ทางลดระดับสำเร็จแล้วยิง acted(buy)", heard, ["buy"] as Array[String])

	# --- buy_device สำเร็จ (kind buy) ---
	heard.clear()
	p.devices = []
	p.cash = 100000.0
	var dev_r = p.buy_device("smartphone")
	_eq("buy_device สำเร็จ ok=true", bool(dev_r.get("ok", false)), true)
	_eq("buy_device สำเร็จแล้วยิง acted(buy)", heard, ["buy"] as Array[String])

	# --- sell_asset สำเร็จ (kind sell) — ป้อนทรัพย์สินปลอมเข้า assets โดยตรง ---
	# มี smartphone แล้วจากขั้นก่อน place_for("fund") จึงเท่ากับ place ปัจจุบันเสมอ (ไม่ต้องเดินทาง)
	heard.clear()
	p.assets = [{"id": 9001, "kind": "fund", "icon": "🏦", "name": "กองทุนทดสอบ",
		"value": 10000.0, "cost": 5000.0, "debt": 0.0, "income": 100.0,
		"vol": 0.0, "drift": 1.0, "offer": null, "sick": 0, "burned": 0}]
	p.hours = p.get_hours_max()
	var sell_r = p.sell_asset(9001)
	_eq("sell_asset สำเร็จ ok=true", bool(sell_r.get("ok", false)), true)
	_eq("sell_asset สำเร็จแล้วยิง acted(sell)", heard, ["sell"] as Array[String])

	# --- take_loan สำเร็จ (kind loan) ---
	heard.clear()
	p.liabilities = []
	p.hours = p.get_hours_max()
	var loan_r = p.take_loan(10000.0)
	_eq("take_loan สำเร็จ ok=true", bool(loan_r.get("ok", false)), true)
	_eq("take_loan สำเร็จแล้วยิง acted(loan)", heard, ["loan"] as Array[String])

	# --- repay_debt สำเร็จ (kind repay) — ชำระหนี้ก้อนที่เพิ่งกู้ข้างบน ---
	heard.clear()
	p.cash = 20000.0
	var repay_r = p.repay_debt(0, 5000.0)
	_eq("repay_debt สำเร็จ ok=true", bool(repay_r.get("ok", false)), true)
	_eq("repay_debt สำเร็จแล้วยิง acted(repay)", heard, ["repay"] as Array[String])

	# --- side_job("ot") สำเร็จ (kind ot) ---
	heard.clear()
	p.place = "office"
	p.side_used = 0
	p.hours = p.get_hours_max()
	var ot_r = p.side_job("ot")
	_eq("side_job(ot) สำเร็จ ok=true", bool(ot_r.get("ok", false)), true)
	_eq("side_job(ot) สำเร็จแล้วยิง acted(ot)", heard, ["ot"] as Array[String])

	# --- side_job("freelance") สำเร็จ (kind freelance) ---
	heard.clear()
	p.place = "cowork"
	p.side_used = 0
	p.hours = p.get_hours_max()
	var fl_r = p.side_job("freelance")
	_eq("side_job(freelance) สำเร็จ ok=true", bool(fl_r.get("ok", false)), true)
	_eq("side_job(freelance) สำเร็จแล้วยิง acted(freelance)", heard, ["freelance"] as Array[String])

	# --- scout สำเร็จ (kind scout) ---
	heard.clear()
	p.place = "estate"
	p.hours = p.get_hours_max()
	var scout_r = p.scout()
	_eq("scout สำเร็จ ok=true", bool(scout_r.get("ok", false)), true)
	_eq("scout สำเร็จแล้วยิง acted(scout)", heard, ["scout"] as Array[String])

	# --- study สำเร็จ (kind study) ---
	heard.clear()
	p.place = "school"
	p.hours = p.get_hours_max()
	p.cash = 100000.0
	var study_r = p.study()
	_eq("study สำเร็จ ok=true", bool(study_r.get("ok", false)), true)
	_eq("study สำเร็จแล้วยิง acted(study)", heard, ["study"] as Array[String])

	# --- exercise สำเร็จ (kind gym) ---
	heard.clear()
	p.place = "gym"
	p.hours = p.get_hours_max()
	p.cash = 100000.0
	var gym_r = p.exercise("daily")
	_eq("exercise สำเร็จ ok=true", bool(gym_r.get("ok", false)), true)
	_eq("exercise สำเร็จแล้วยิง acted(gym)", heard, ["gym"] as Array[String])

	# --- vacation สำเร็จ (kind resort) ---
	heard.clear()
	p.place = "resort"
	p.hours = p.get_hours_max()
	p.cash = 100000.0
	var resort_r = p.vacation("day")
	_eq("vacation สำเร็จ ok=true", bool(resort_r.get("ok", false)), true)
	_eq("vacation สำเร็จแล้วยิง acted(resort)", heard, ["resort"] as Array[String])

	# --- enter_phase2 (คืน void เสมอ ไม่มีพาธล้มเหลว) ---
	heard.clear()
	p.enter_phase2(WQData.dreams[0], false)
	_eq("enter_phase2 ยิง acted(phase2)", heard, ["phase2"] as Array[String])

	# --- claim_dream สำเร็จ (kind dream — WQBank.FROM_ACTED ตั้งใจไม่มี key นี้) ---
	heard.clear()
	p.cash = 100000.0
	p.dream.cost = 0.0
	p.dream.passiveReq = 0.0
	var dream_r = p.claim_dream()
	_eq("claim_dream สำเร็จ ok=true", bool(dream_r.get("ok", false)), true)
	_eq("claim_dream สำเร็จแล้วยิง acted(dream)", heard, ["dream"] as Array[String])

	# ========== ทุก kind ที่ "ยิงจริง" ข้างบน ต้องมีที่อยู่ในตารางเสียง ==========
	# รายชื่อมาจากพฤติกรรมจริงที่เพิ่งเห็นกับตา ไม่ใช่ลิสต์ที่พิมพ์ไว้เอง — ลิสต์ที่พิมพ์เองจะค้าง
	# อยู่กับอดีตทันทีที่ core เพิ่ม kind ใหม่ แล้วไม่มีใครรู้ว่ามันไม่ได้ครอบของใหม่
	var kinds := {}
	for kind in all_heard:
		kinds[kind] = true
	# กันเช็กนี้ฝ่อเงียบๆ: ถ้ามีใครลบเทสต์บวกข้างบนออกไป ลูปล่างจะเหลือของให้ตรวจน้อยลง
	# โดยไม่มีอะไรล้ม บรรทัดนี้ทำให้จำนวนที่หายไปกลายเป็นความล้มเหลวที่มองเห็น
	_eq("เทสต์บวกข้างบนเดินผ่าน kind ครบทุกตัวที่ core ยิงได้", kinds.size(), 15)
	for kind in kinds:
		if kind == "dream": continue   # ตั้งใจไม่มีเสียงของตัวเอง (เช็กไว้แล้วใน _check_bank)
		_eq("kind \"%s\" ที่ core ยิงจริง มีที่อยู่ในตาราง" % kind,
			WQBank.FROM_ACTED.has(kind), true)

	_completed["acted"] = true

## เสียงต้องดังเฉพาะของผู้เล่นคนที่ผูกไว้ ไม่ใช่ของบอท
## เกมมีบอทสามตัวทำครบทุกอย่างทุกเดือน ถ้าฟังทุกคนจะได้ยินเสียงรัวตลอดเวลาจนไร้ความหมาย
func _check_audio() -> void:
	## ห้ามแตะไฟล์ตั้งค่าจริงของนักพัฒนา (ท่าเดียวกับที่ flow_check ทำกับ WQSave.dir)
	## และต้องรีเซ็ตสถานะเอง เพราะ autoload อ่านไฟล์จริงไปแล้วตอน _ready() — ถ้าเครื่องไหน
	## เคยปิดเสียงค้างไว้ สูททั้งชุดจะล้มด้วยเหตุผลที่ไม่เกี่ยวกับโค้ดเลย
	WQAudio.settings_path = "user://settings_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WQAudio.settings_path))
	WQAudio.set_muted(false)
	WQAudio.set_level("Master", 1.0)
	WQAudio.set_level("SFX", 1.0)

	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
	]})
	var me = m.players[0]
	var bot = m.players[1]

	WQAudio.bind(m)
	WQAudio.bind_player(me)

	# บัสต้องมีจริง แม้ headless จะเริ่มมาแค่บัสเดียว
	_eq("มีบัส SFX", AudioServer.get_bus_index("SFX") >= 0, true)
	_eq("pool มี 8 ตัว", WQAudio._players.size(), 8)

	WQAudio.played.clear()
	me.place = "home"
	_eq("เราพักผ่อนสำเร็จจริง", bool(me.rest().get("ok", false)), true)
	_eq("acted ของเราทำให้เสียงดัง", WQAudio.played, ["rest"] as Array[String])

	## ล้าง _last ด้วย ไม่งั้นเทสต์นี้เขียวเพราะ COOLDOWN กลืนเสียง "rest" ของบอทให้
	## ไม่ใช่เพราะเราไม่ได้ฟังบอท (พิสูจน์แล้ว: ให้ bind() ต่อสาย acted ของผู้เล่นทุกคน
	## แล้วเทสต์ก็ยังเขียวอยู่ดี) — และต้องยืนยันว่าบอททำสำเร็จจริง ไม่ใช่เงียบเพราะทำไม่ได้
	WQAudio._last.clear()
	WQAudio.played.clear()
	bot.place = "home"
	_eq("บอทพักผ่อนสำเร็จจริง", bool(bot.rest().get("ok", false)), true)
	_eq("acted ของบอทต้องเงียบ", WQAudio.played, [] as Array[String])

	# เลน UI
	WQAudio.played.clear()
	WQAudio.ui("click")
	_eq("ui() เล่นเสียงในรายการได้", WQAudio.played, ["click"] as Array[String])

	WQAudio.played.clear()
	WQAudio.ui("win")     # ไม่อยู่ใน UI_IDS — ต้องถูกปฏิเสธ
	_eq("ui() เล่นเสียงเหตุการณ์ของเกมไม่ได้", WQAudio.played, [] as Array[String])

	# preview() คือเครื่องมือฟังจาก terminal — ต้องเงียบสนิทเมื่อไม่ได้ตั้ง WQ_SFX
	# ไม่งั้นมันจะกลายเป็นประตูหลังให้ ui/ ยิงเสียงเหตุการณ์เองได้ ซึ่งพังกฎสองเลนทั้งข้อ
	WQAudio.played.clear()
	WQAudio.preview("win")
	_eq("preview() นอกโหมด WQ_SFX ต้องเงียบ", WQAudio.played, [] as Array[String])

	# เสียงเดิมที่ยิงซ้ำภายใน COOLDOWN ต้องถูกกลืน — กันเสียงซ้อนตัวเองตอนกดปุ่มรัว
	WQAudio._last.clear()
	WQAudio.played.clear()
	WQAudio.ui("click")
	WQAudio.ui("click")
	_eq("ยิงเสียงเดิมซ้ำติดๆ กันแล้วดังครั้งเดียว", WQAudio.played, ["click"] as Array[String])

	# ปิดเสียงแล้วต้องไม่มีอะไรดัง
	## ล้าง _last ก่อน ไม่งั้นเทสต์นี้เขียวเพราะ COOLDOWN กลืนเสียงให้ ไม่ใช่เพราะ mute ทำงาน
	## (พิสูจน์มาแล้ว: ลบบรรทัด `if muted: return` ใน _play ทิ้ง เทสต์ก็ยังเขียวอยู่ดี)
	WQAudio._last.clear()
	WQAudio.set_muted(true)
	WQAudio.played.clear()
	me.hours = me.get_hours_max()
	me.rest()
	WQAudio.ui("click")
	_eq("ปิดเสียงแล้วเงียบสนิท", WQAudio.played, [] as Array[String])
	WQAudio.set_muted(false)

	# ยิงรัวแล้ว pool ต้องไม่งอก
	for _i in 100: WQAudio.ui("click")
	_eq("pool ไม่โตแม้ยิงรัว 100 ครั้ง", WQAudio._players.size(), 8)

	# ประวัติการเล่นต้องไม่โตไม่รู้จบตลอดเซสชัน
	WQAudio.played.clear()
	for _i in WQAudio.HISTORY + 50:
		WQAudio._last.clear()
		WQAudio.ui("click")
	_eq("ประวัติการเล่นถูกตัดท้ายไว้ที่ HISTORY", WQAudio.played.size(), WQAudio.HISTORY)

	# ระดับเสียงต้องแปลงเป็น dB ลงบัสจริง
	WQAudio.set_level("SFX", 0.5)
	_eq("ระดับเสียงลงบัสจริง",
		snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), 0.01),
		snappedf(linear_to_db(0.5), 0.01))
	WQAudio.set_level("SFX", 1.0)

	# ========== เลนเหตุการณ์: มาจากสัญญาณของแมตช์/ผู้เล่นเท่านั้น ==========
	# ยิงสัญญาณตรงๆ เพราะที่นี่ทดสอบ "ใครฟังอะไรแล้วเล่นเสียงไหน" ส่วนที่ core ยิงถูกจังหวะไหม
	# เป็นงานของ flow_check กับ _check_acted ข้างบน

	WQAudio._last.clear()
	WQAudio.played.clear()
	me.deal_closed.emit({})
	_eq("ปิดดีลแล้วมีเสียง", WQAudio.played, ["deal_closed"] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	m.disaster_started.emit({})
	_eq("ภัยพิบัติมาแล้วมีเสียง", WQAudio.played, ["disaster"] as Array[String])

	# สิ้นเดือนที่เหลือเก็บเป็นบวก → เสียงเงินเดือนออกต่อท้าย
	WQAudio._last.clear()
	WQAudio.played.clear()
	me.retired = false
	me.salary = 1000000.0
	_eq("ตั้งค่าให้เดือนนี้เหลือเก็บเป็นบวกจริง", me.get_monthly_cashflow() > 0.0, true)
	m.month_ended.emit(1)
	_eq("สิ้นเดือนบวกได้ยินทั้งสิ้นเดือนและเงินเดือน", WQAudio.played,
		["month_end", "payday"] as Array[String])

	# เดือนที่ติดลบต้องไม่มีเสียงเหรียญ ไม่งั้นสอนผู้เล่นผิดว่าเดือนนี้ผ่านไปด้วยดี
	WQAudio._last.clear()
	WQAudio.played.clear()
	me.retired = true
	_eq("ตั้งค่าให้เดือนนี้ติดลบจริง", me.get_monthly_cashflow() < 0.0, true)
	m.month_ended.emit(2)
	_eq("สิ้นเดือนติดลบได้ยินแค่สิ้นเดือน", WQAudio.played, ["month_end"] as Array[String])
	me.retired = false

	WQAudio._last.clear()
	WQAudio.played.clear()
	m.player_finished.emit(me)
	_eq("เราถึงฝันแล้วมีเสียงชนะ", WQAudio.played, ["win"] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	m.player_finished.emit(bot)
	_eq("บอทถึงฝันก่อนต้องไม่ได้ยินเสียงชนะ", WQAudio.played, [] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	me.phase = 1
	m.match_over.emit()
	_eq("จบเกมทั้งที่ยังไม่ถึงเฟส 3 มีเสียงแพ้", WQAudio.played, ["lose"] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	me.phase = 3
	m.match_over.emit()
	_eq("จบเกมตอนถึงเฟส 3 แล้วต้องไม่มีเสียงแพ้", WQAudio.played, [] as Array[String])

	# เตือนสุขภาพครั้งเดียวตอนข้ามเข้าโซนวิกฤต — `changed` ยิงหลายสิบครั้งต่อเดือน
	# ล้าง _last ทุกครั้ง ไม่งั้นเทสต์ "ไม่ซ้ำ" จะเขียวเพราะ COOLDOWN ไม่ใช่เพราะจำสถานะได้
	WQAudio._last.clear()
	WQAudio.played.clear()
	me.health = 30.0
	me.changed.emit()
	_eq("สุขภาพตกเข้าโซนวิกฤตแล้วเตือน", WQAudio.played, ["health_low"] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	me.changed.emit()
	_eq("อยู่ในโซนวิกฤตต่อไม่เตือนซ้ำ", WQAudio.played, [] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	me.health = 70.0
	me.changed.emit()
	me.health = 30.0
	me.changed.emit()
	_eq("ออกจากโซนแล้วตกกลับเข้าไปใหม่ ต้องเตือนอีกครั้ง", WQAudio.played,
		["health_low"] as Array[String])

	# ========== ผูกใหม่ต้องปลดสายเก่า ==========
	# ถ้าไม่ปลด เริ่มแมตช์ใหม่หรือเปลี่ยนผู้เล่นแล้วจะได้ยินเสียงของทุกคนที่เคยผูกไว้ซ้อนกัน
	WQAudio._last.clear()
	WQAudio.played.clear()
	WQAudio.bind_player(bot)
	me.place = "home"
	me.hours = me.get_hours_max()
	_eq("คนเก่าพักผ่อนสำเร็จจริง (ไม่ใช่เงียบเพราะทำไม่ได้)",
		bool(me.rest().get("ok", false)), true)
	_eq("ผูกคนใหม่แล้วเสียงของคนเก่าต้องเงียบ", WQAudio.played, [] as Array[String])

	WQAudio._last.clear()
	WQAudio.played.clear()
	bot.place = "home"
	bot.hours = bot.get_hours_max()
	_eq("คนใหม่พักผ่อนสำเร็จจริง", bool(bot.rest().get("ok", false)), true)
	_eq("ผูกคนใหม่แล้วได้ยินเสียงของคนใหม่", WQAudio.played, ["rest"] as Array[String])
	WQAudio.bind_player(me)

	WQAudio._last.clear()
	WQAudio.played.clear()
	WQAudio.bind(null)
	m.disaster_started.emit({})
	_eq("ปลดแมตช์แล้วสัญญาณของแมตช์เก่าต้องเงียบ", WQAudio.played, [] as Array[String])
	WQAudio.bind(m)

	# headless ไม่ยิงเสียงจริง (เหตุผลอยู่ใน audio/audio.gd) ทางโหลดสตรีมจึงไม่ถูกเดินผ่าน _play()
	# ต้องเรียกตรงๆ เอง ไม่งั้นไฟล์เสียงที่โหลดไม่ขึ้นจะไปโผล่ตอนเปิดเกมจริงเท่านั้น
	for id in WQBank.ids():
		_eq("โหลดสตรีมของ \"%s\" ได้" % id, WQAudio._stream(id) is AudioStream, true)
	_eq("แคชสตรีมไว้ตัวเดียวต่อ id", WQAudio._stream("click"), WQAudio._cache["click"])

	_completed["audio"] = true

## หน้าจอจริงต้องผูก WQAudio เข้ากับแมตช์ ไม่ใช่แค่มีระบบเสียงอยู่เฉยๆ
## นี่คือบั๊กแบบที่ flow_check เคยจับได้: ของมีครบทุกชิ้นแต่ไม่มีใครต่อสายให้
func _check_wiring() -> void:
	WQSave.dir = "user://saves_test"      # ห้ามแตะไฟล์เซฟจริงของผู้เล่น (ท่าเดียวกับ flow_check)
	for slot in WQSave.MANUAL_SLOTS + WQSave.AUTO_SLOTS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WQSave.path_for(slot)))

	var main: Control = load("res://ui/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	## เดินเข้าเกมทางเดียวกับผู้เล่นจริง (ท่าเดียวกับ flow_check) ไม่ใช่เรียก _start_match() ตรงๆ
	## เพราะ _ready() สร้างหน้าเลือกอาชีพไปแล้ว การข้ามหน้านั้นคือการทดสอบเส้นทางที่ไม่มีใครเดิน
	main.setup_screen.skip_to_jobs(4)
	main.setup_screen._job.select(String(main.setup_screen.offer.jobs[0].id))
	main.setup_screen._job._confirm.pressed.emit()
	await process_frame

	var human = null
	for p in main.m.players:
		if not p.is_ai: human = p
	_eq("main.gd ผูกแมตช์เข้ากับ WQAudio แล้ว", WQAudio._match, main.m)
	_eq("main.gd ผูกผู้เล่นคนจริงเข้ากับ WQAudio แล้ว", WQAudio._player, human)
	## get_current() เป็นบอทได้ระหว่างตาบอท — main.gd เองก็มี `if p.is_ai: return` กันไว้หลายจุด
	_eq("ที่ผูกไว้ต้องไม่ใช่บอท", bool(WQAudio._player.is_ai), false)

	# เสียงจากสัญญาณของ core ต้องดังผ่านหน้าจอจริง ไม่ใช่ดังแค่ตอนเทสต์ผูกเอง
	WQAudio._last.clear()
	WQAudio.played.clear()
	human.place = "home"
	human.hours = human.get_hours_max()
	_eq("พักผ่อนผ่านหน้าจอจริงสำเร็จ", bool(human.rest().get("ok", false)), true)
	_eq("เสียงของ core ดังผ่านหน้าจอจริง", WQAudio.played, ["rest"] as Array[String])

	# เปิด/ปิดแผงบันทึก
	WQAudio._last.clear()
	WQAudio.played.clear()
	main._open_save_panel("save")
	await process_frame
	_eq("เปิดแผงมีเสียง", WQAudio.played.has("panel_open"), true)

	WQAudio._last.clear()
	WQAudio.played.clear()
	main._close_save_panel()
	await process_frame
	_eq("ปิดแผงมีเสียง", WQAudio.played.has("panel_close"), true)

	# บันทึก/โหลดจริงลงช่องทดสอบ
	WQAudio.set_level("SFX", 0.3)      # ค่าที่ต้อง **ไม่** ติดไปกับไฟล์เซฟ (เช็กหลังโหลดข้างล่าง)
	WQAudio._last.clear()
	WQAudio.played.clear()
	main._on_save_slot(WQSave.MANUAL_SLOTS[0])
	await process_frame
	_eq("บันทึกสำเร็จแล้วมีเสียง", WQAudio.played.has("save"), true)

	WQAudio._last.clear()
	WQAudio.played.clear()
	main._on_load_slot(WQSave.MANUAL_SLOTS[0])
	await process_frame
	_eq("โหลดสำเร็จแล้วมีเสียง", WQAudio.played.has("load"), true)

	## ระดับเสียงต้องไม่ติดไปกับไฟล์เซฟ — เซฟมี 6 ช่อง ถ้าเก็บในเซฟ เสียงจะเปลี่ยนไปมา
	## ทุกครั้งที่ผู้เล่นโหลดคนละช่อง (เพิ่งบันทึกช่องนี้ไปตอนเสียง 0.3)
	WQAudio.set_level("SFX", 0.9)
	main._on_load_slot(WQSave.MANUAL_SLOTS[0])
	await process_frame
	_eq("โหลดเซฟแล้วระดับเสียงต้องไม่เปลี่ยนตาม", WQAudio.get_level("SFX"), 0.9)
	WQAudio.set_level("SFX", 1.0)

	# ปุ่มบน HUD ทั้งสามตัวต้องมีเสียงคลิก
	for btn_name in ["_save", "_load", "_end"]:
		WQAudio._last.clear()
		WQAudio.played.clear()
		(main.hud.get(btn_name) as Button).pressed.emit()
		await process_frame
		_eq("ปุ่ม %s บน HUD มีเสียงคลิก" % btn_name, WQAudio.played.has("click"), true)
		if main.save_panel != null: main._close_save_panel()

	# กดแล้วทำไม่ได้ต้องมีเสียงปฏิเสธ ไม่งั้นผู้เล่นกดแล้วไม่มีอะไรตอบเลย
	var me2 = main.m.get_current()
	me2.place = "home"                    # หาดีลต้องยืนอยู่ที่ตลาดอสังหาฯ
	WQAudio._last.clear()
	WQAudio.played.clear()
	main.action_panel.bind(me2)
	main.action_panel._do("scout")
	_eq("ทำไม่ได้แล้วมีเสียงปฏิเสธ", WQAudio.played, ["denied"] as Array[String])

	# ทำได้ต้องไม่มีเสียงปฏิเสธ — เสียงสำเร็จมาจากสัญญาณ acted ของ core เอง
	me2.hours = me2.get_hours_max()
	WQAudio._last.clear()
	WQAudio.played.clear()
	main.action_panel._do("rest")
	_eq("ทำได้แล้วไม่มีเสียงปฏิเสธ ได้ยินเสียงของ core แทน",
		WQAudio.played, ["rest"] as Array[String])

	# ปุ่ม 🔊 ต้องเปิดแผงปรับเสียงจริง ไม่ใช่แค่มีปุ่มอยู่เฉยๆ
	WQAudio._last.clear()
	WQAudio.played.clear()
	main.hud._audio.pressed.emit()
	await process_frame
	_eq("กดปุ่ม 🔊 แล้วแผงปรับเสียงเปิดจริง", main.audio_panel != null, true)
	_eq("กดปุ่ม 🔊 มีเสียงคลิก", WQAudio.played.has("click"), true)
	_eq("เปิดแผงปรับเสียงมีเสียงเปิดแผง", WQAudio.played.has("panel_open"), true)

	main.audio_panel._close.pressed.emit()
	await process_frame
	_eq("กดปิดในแผงแล้วแผงหายไปจริง", main.audio_panel == null, true)

	# ลูกเต๋า — ภาพเคลื่อนไหวล้วน จึงอยู่เลน UI
	var d := WQDice.new()
	root.add_child(d)
	WQAudio._last.clear()
	WQAudio.played.clear()
	d.roll_to(4)
	_eq("เริ่มทอยแล้วมีเสียง", WQAudio.played, ["dice_roll"] as Array[String])
	d.finish_now()
	_eq("ลูกเต๋าหยุดแล้วมีเสียง", WQAudio.played,
		["dice_roll", "dice_land"] as Array[String])
	root.remove_child(d)
	d.free()

	# การสอนขึ้นสเต็ปใหม่
	_eq("เกมใหม่ต้องกำลังสอนอยู่", bool(main.tutorial.running), true)
	WQAudio._last.clear()
	WQAudio.played.clear()
	main.tutorial._next.pressed.emit()
	await process_frame
	_eq("ขึ้นสเต็ปใหม่แล้วมีเสียง", WQAudio.played.has("tutorial_step"), true)

	## `refresh()` ถูกเรียกทุกครั้งที่สถานะเกมเปลี่ยน ไม่ใช่แค่ตอนเปลี่ยนสเต็ป
	## ล้าง _last ก่อน ไม่งั้นเทสต์นี้เขียวเพราะ COOLDOWN ไม่ใช่เพราะการ์ดยังเป็นใบเดิม
	WQAudio._last.clear()
	WQAudio.played.clear()
	main.tutorial.refresh()
	await process_frame
	_eq("การ์ดใบเดิมถูก refresh ซ้ำ ต้องไม่มีเสียงอีก",
		WQAudio.played.has("tutorial_step"), false)

	root.remove_child(main)
	main.free()
	_completed["wiring"] = true

## ระดับเสียงต้องอยู่ข้ามการเปิดเกมใหม่ และต้อง **ไม่** อยู่ในไฟล์เซฟ
## (เซฟมี 6 ช่อง ถ้าเก็บในเซฟ เสียงจะเปลี่ยนไปมาตามช่องที่โหลด)
func _check_settings() -> void:
	WQAudio.set_level("SFX", 0.3)
	WQAudio.set_muted(true)

	var cfg := ConfigFile.new()
	_eq("เขียนไฟล์ตั้งค่าแล้ว", cfg.load(WQAudio.settings_path), OK)
	_eq("จำระดับเสียง SFX", float(cfg.get_value("audio", "sfx", -1.0)), 0.3)
	_eq("จำสถานะปิดเสียง", bool(cfg.get_value("audio", "muted", false)), true)

	# โหลดกลับมาต้องได้ค่าเดิม — เหมือนเปิดเกมใหม่
	WQAudio._levels["SFX"] = 1.0
	WQAudio.muted = false
	WQAudio._load_settings()
	_eq("โหลดค่าเดิมกลับมาได้", WQAudio.get_level("SFX"), 0.3)
	_eq("โหลดสถานะปิดเสียงกลับมาได้", WQAudio.muted, true)

	WQAudio.set_muted(false)
	WQAudio.set_level("SFX", 1.0)

	var panel := WQAudioPanel.new()
	root.add_child(panel)
	await process_frame
	_eq("สไลเดอร์ตั้งค่าตามที่ WQAudio จำไว้", panel._sfx.value, 1.0)

	panel._sfx.value = 0.5
	await process_frame
	_eq("ขยับสไลเดอร์แล้วเสียงเปลี่ยนจริง", WQAudio.get_level("SFX"), 0.5)
	_eq("ขยับสไลเดอร์แล้วลงบัสจริงด้วย",
		snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), 0.01),
		snappedf(linear_to_db(0.5), 0.01))

	panel._mute.button_pressed = true
	await process_frame
	_eq("ติ๊กปิดเสียงแล้วปิดจริง", WQAudio.muted, true)
	panel._mute.button_pressed = false
	await process_frame

	# ปุ่มปิดแผงต้องบอกคนที่เปิดมันด้วย ไม่งั้นแผงค้างจนเปิดใหม่ไม่ได้
	var closed_heard := [false]
	panel.closed.connect(func(): closed_heard[0] = true)
	WQAudio._last.clear()
	WQAudio.played.clear()
	panel._close.pressed.emit()
	_eq("กดปิดแผงแล้วยิงสัญญาณ closed", closed_heard[0], true)
	_eq("กดปิดแผงแล้วมีเสียง", WQAudio.played.has("panel_close"), true)

	WQAudio.set_level("SFX", 1.0)
	root.remove_child(panel)
	panel.free()
	_completed["settings"] = true


## คืนช่วง PCM ของไฟล์ .wav — ไล่หา chunk "data" จริงๆ ไม่ใช่ข้ามหัว 44 ไบต์ตายตัว
## เพราะไฟล์ที่คนทำเสียงส่งมามักมี chunk เสริม (LIST/INFO ของโปรแกรมตัดต่อ) คั่นอยู่ก่อน
func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
