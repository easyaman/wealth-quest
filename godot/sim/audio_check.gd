extends SceneTree
## ตรวจระบบเสียงแบบ headless — ไม่ต้องมีลำโพง
##   godot --headless --path . --script res://sim/audio_check.gd
##
## headless ใช้ไดรเวอร์เสียง `Dummy` เสียงจึงไม่ออกจริง ที่นี่ตรวจได้แค่
## "มีของครบไหม · ยิงถูกจังหวะไหม" ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง
## ฟังจริงด้วย:  WQ_SFX=<id> godot --path .

const SFX_DIR := "res://audio/sfx"
const ALL_CHECKS: Array[String] = ["bank", "synth", "files", "acted"]

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


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
