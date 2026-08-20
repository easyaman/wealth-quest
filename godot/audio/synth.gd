class_name WQSynth
extends RefCounted
## เครื่องสังเคราะห์เสียง chiptune — คลื่นสามแบบพอสำหรับทั้งเกม
##
## ตัวนี้คือ `world/tools/meshkit.gd` ของฝั่งเสียง: ตัวต่อพื้นฐานที่ไม่รู้จักเกมเลย
## รู้แค่ว่า "สเปกหนึ่งชุด → ตัวอย่างเสียง" ส่วนเสียงไหนใช้ตอนไหนเป็นเรื่องของ WQBank
##
## **ต้องได้ไบต์เดิมเป๊ะทุกครั้งที่เรียกด้วยสเปกเดียวกัน** — ตัวอบใช้ sha256 แยกว่า
## ไฟล์ไหนอบจากโค้ดไฟล์ไหนคนทำมา ถ้า noise สุ่มใหม่ทุกครั้ง ทุกไฟล์จะดู "เปลี่ยนแล้ว"
## ตลอดเวลา จึงต้องใช้ RandomNumberGenerator ที่ตั้ง seed ไว้ ไม่ใช่ randf() ของ Godot

const RATE := 22050              ## พอสำหรับ chiptune และทำให้ไฟล์เล็ก (~6.6 KB ต่อ 0.15 วิ)
const NOISE_SEED := 20260820     ## คงที่ตลอดกาล — เปลี่ยนเมื่อไหร่ทุกไฟล์ noise ถูกอบใหม่หมด


## สเปก: [คลื่น, ความถี่เริ่ม, ความถี่จบ, ความยาว(วิ), attack(วิ), decay(วิ), ระดับเสียง]
##
## `noise` ก็ใช้ f0/f1 เหมือนคลื่นอื่น แต่ไม่ใช่ระดับเสียง (pitch) — เป็นความถี่ของ
## "sample-and-hold" (เทคนิค noise channel คลาสสิกของชิปเสียงยุคเก่า): สุ่มค่าใหม่ทุกครั้ง
## ที่ phase ครบรอบ ความถี่ต่ำ = สุ่มค่าห่างๆ ได้เสียงกร้าวหยาบ · ความถี่สูง = สุ่มถี่ ได้เสียงฟู่สว่าง
## f0→f1 ที่ลดลงจึงกลายเป็นเสียงกวาดหยาบลงเรื่อยๆ ที่ฟังออกจริง (เช่น "disaster")
static func render(spec: Array) -> PackedByteArray:
	var wave := String(spec[0])
	var f0 := float(spec[1])
	var f1 := float(spec[2])
	var dur := float(spec[3])
	var attack := float(spec[4])
	var decay := float(spec[5])
	var vol := float(spec[6])

	var n := int(RATE * dur)
	var out := PackedByteArray()
	out.resize(n * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var phase := 0.0
	var held := rng.randf_range(-1.0, 1.0)  ## ค่าที่ค้างไว้จนกว่า phase จะครบรอบครั้งถัดไป
	for i in n:
		var t := float(i) / float(RATE)
		var freq: float = lerpf(f0, f1, t / maxf(dur, 0.0001))
		var prev_phase := phase
		phase = fmod(phase + freq / float(RATE), 1.0)
		if phase < prev_phase:
			held = rng.randf_range(-1.0, 1.0)  ## phase ครบรอบ — สุ่มค่าใหม่มาค้างไว้ (sample-and-hold)
		var s := 0.0
		match wave:
			"square": s = 1.0 if phase < 0.5 else -1.0
			"triangle": s = 4.0 * absf(phase - 0.5) - 1.0
			"noise": s = held
		var v: float = clampf(s * _env(t, dur, attack, decay) * vol, -1.0, 1.0)
		out.encode_s16(i * 2, int(v * 32767.0))
	return out


static func stream(spec: Array) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = render(spec)
	return st


## ซองเสียง attack → คงที่ → decay · ไม่มี sustain แยกเพราะเสียงทุกตัวสั้นกว่า 2 วินาที
static func _env(t: float, dur: float, attack: float, decay: float) -> float:
	if t < attack: return t / maxf(attack, 0.0001)
	var rel := dur - decay
	if t >= rel: return maxf(0.0, (dur - t) / maxf(decay, 0.0001))
	return 1.0
