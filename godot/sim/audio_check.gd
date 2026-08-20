extends SceneTree
## ตรวจระบบเสียงแบบ headless — ไม่ต้องมีลำโพง
##   godot --headless --path . --script res://sim/audio_check.gd
##
## headless ใช้ไดรเวอร์เสียง `Dummy` เสียงจึงไม่ออกจริง ที่นี่ตรวจได้แค่
## "มีของครบไหม · ยิงถูกจังหวะไหม" ไม่ได้ตรวจว่าฟังแล้วรู้เรื่อง
## ฟังจริงด้วย:  WQ_SFX=<id> godot --path .

var _fails := 0


func _init() -> void:
	_check_bank()
	_check_synth()
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

	var st := WQSynth.stream(spec)
	_eq("สตรีมเป็น 16-bit", st.format, AudioStreamWAV.FORMAT_16_BITS)
	_eq("สตรีมเป็น mono", st.stereo, false)
	_eq("อัตราสุ่มตรงกับ synth", st.mix_rate, WQSynth.RATE)


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
