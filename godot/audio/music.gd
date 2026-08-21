class_name WQMusic
extends RefCounted
## เพลงพื้นหลัง — ตารางโน้ตของทุกเพลง + ตัวเรียบเรียงที่ประกอบเป็น PCM ชุดเดียว
##
## คู่กับ WQSynth เหมือนที่ WQBank เป็นกับเสียงสั้น: WQSynth รู้จักแค่ "หนึ่งโน้ตหน้าตายังไง"
## WQMusic รู้จัก "โน้ตไหนดังตอนไหนและผสมกันยังไง" ส่วน "เพลงไหนดังตอนไหนของเกม"
## เป็นเรื่องของ WQAudio ที่เดียว — ที่นี่ไม่รู้จักเกมเลย
##
## **ต้องได้ไบต์เดิมเป๊ะทุกครั้ง** — ตัวอบใช้ sha256 แยกว่าไฟล์ไหนอบจากโค้ดไฟล์ไหนคนทำมา
## (WQSynth ใช้ RandomNumberGenerator ที่ตั้ง seed ไว้อยู่แล้ว จึงคงที่ให้เอง)
##
## รูปแบบสตริง: หนึ่งช่อง = หนึ่งจังหวะ · "|" คั่นห้อง (ให้คนอ่านและให้เทสต์ตรวจโครง)
##   "C4"  โน้ต (ตัวโน้ต + #/b + อ็อกเทฟ)      "."  เงียบ
##   "-"   ต่อเสียงจากช่องก่อนหน้า (ทำเสียงยาว)   "x"/"X"  กลองเบา/หนัก (เฉพาะช่อง drum)

## คลื่นและระดับเสียงประจำช่อง — รวมกันไม่ถึง 1.0 เพื่อให้มีที่เหลือตอนสามช่องดังพร้อมกัน
const CHANNEL_WAVE := {"lead": "square", "bass": "triangle"}
const CHANNEL_VOL := {"lead": 0.30, "bass": 0.26}

## กลองใช้ช่อง noise ของ WQSynth — f0→f1 คือความถี่ sample-and-hold ไม่ใช่ระดับเสียง
## กวาดลงเร็ว = "ตุบ" (กระเดื่อง) · ถี่คงที่สั้นๆ = "ฉึก" (ไฮแฮต)
## ความยาวกลองไม่ขึ้นกับจังหวะที่ถืออยู่ ไฮแฮตที่ลากยาวหนึ่งจังหวะเต็มไม่ใช่เสียงกลอง
const DRUM := {
	"x": {"f0": 2400.0, "f1": 1800.0, "dur": 0.10, "vol": 0.14},
	"X": {"f0": 700.0, "f1": 160.0, "dur": 0.20, "vol": 0.24},
}

const TRACKS := {
	## ด่าน 1 — "ออกจากสนามแข่งหนู" ยังไม่ชนะแต่ยังไหว: C major เดินคอร์ด C–Am–F–G
	## จังหวะปานกลาง ไม่เร่งเร้า เพราะเพลงนี้ต้องดังอยู่หลายสิบเดือนโดยไม่กวนสมาธิ
	"phase1": {
		"bpm": 110, "beats_per_bar": 4,
		"lead":
			"E4 .  G4 .  | A4 .  G4 E4 | F4 .  A4 .  | G4 -  -  .  | " +
			"E4 .  G4 C5 | B4 .  A4 .  | F4 .  G4 A4 | G4 -  -  .  | " +
			"C5 .  B4 .  | A4 .  G4 E4 | F4 .  E4 D4 | C4 -  -  .  | " +
			"E4 .  G4 .  | A4 .  C5 .  | G4 .  F4 E4 | D4 -  -  . ",
		"bass":
			"C2 -  -  -  | A2 -  -  -  | F2 -  -  -  | G2 -  -  -  | " +
			"C2 -  -  -  | A2 -  -  -  | F2 -  -  -  | G2 -  -  -  | " +
			"C2 -  -  -  | A2 -  -  -  | F2 -  -  -  | G2 -  -  -  | " +
			"C2 -  -  -  | A2 -  -  -  | F2 -  -  -  | G2 -  -  - ",
		"drum":
			"X  .  x  .  | X  .  x  x  | X  .  x  .  | X  .  x  X  | " +
			"X  .  x  .  | X  .  x  x  | X  .  x  .  | X  .  x  X  | " +
			"X  .  x  .  | X  .  x  x  | X  .  x  .  | X  .  x  X  | " +
			"X  .  x  .  | X  .  x  x  | X  .  x  .  | X  .  x  X ",
	},
}


static func ids() -> Array:
	var out := TRACKS.keys()
	out.sort()
	return out


## ตัดขีดคั่นห้องออก คืนช่องทั้งหมดเรียงต่อกัน — "|" เป็นแค่เครื่องหมายให้คนอ่าน
static func cells(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	for tok in line.replace("\n", " ").replace("\t", " ").split(" ", false):
		if tok != "|": out.append(tok)
	return out


## จำนวนช่องของแต่ละห้อง — เทสต์ใช้เทียบว่าทุกช่องมีโครงเดียวกันเป๊ะ
static func bars(line: String) -> Array:
	var out: Array = []
	var n := 0
	for tok in line.replace("\n", " ").replace("\t", " ").split(" ", false):
		if tok == "|":
			out.append(n)
			n = 0
		else:
			n += 1
	out.append(n)
	return out


## ชื่อโน้ต → ความถี่ (A4 = 440 Hz) · คืน 0.0 ถ้าอ่านไม่ออก ให้ผู้เรียกจัดการต่อ
static func note_hz(name: String) -> float:
	const STEP := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	if name.is_empty(): return 0.0
	var letter := name.substr(0, 1).to_upper()
	if not STEP.has(letter): return 0.0
	var semi: int = STEP[letter]
	var rest := name.substr(1)
	while rest.begins_with("#") or rest.begins_with("b"):
		semi += 1 if rest.begins_with("#") else -1
		rest = rest.substr(1)
	if not rest.is_valid_int(): return 0.0
	var midi := (rest.to_int() + 1) * 12 + semi
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)


static func length_sec(id: String) -> float:
	var t: Dictionary = TRACKS[id]
	return float(cells(String(t["lead"])).size()) * 60.0 / float(t["bpm"])


## เรียบเรียงทั้งเพลงเป็น PCM ชุดเดียว
##
## รางผสมเป็น int32 ไม่ใช่ int16 เพราะสามช่องบวกกันเกินช่วง 16 บิตได้ระหว่างทาง
## แล้วค่อยตัดยอดตอนแปลงกลับครั้งเดียว — ถ้าตัดยอดทีละช่องจะเพี้ยนกว่าที่ควร
##
## พารามิเตอร์ `only` มีไว้ให้สูทตรวจสอบว่า **แต่ละช่องดังจริงด้วยตัวเอง**
## ไม่งั้นช่องที่เงียบหายเข้าไปในคนอื่นจะตรวจไม่ได้เลย
## ถ้าตั้ง `only != ""` ให้เรียบเรียงเฉพาะช่องนั้นช่องเดียว (วนข้ามช่องอื่น)
static func render(id: String, only := "") -> PackedByteArray:
	var t: Dictionary = TRACKS[id]
	var spb := 60.0 / float(t["bpm"])
	var frames := int(round(length_sec(id) * float(WQSynth.RATE)))
	var mix := PackedInt32Array()
	mix.resize(frames)

	for ch in ["lead", "bass", "drum"]:
		# ถ้าระบุช่องเฉพาะให้ข้ามช่องอื่นทั้งหมด
		if only != "" and ch != only:
			continue
		var cs := cells(String(t[ch]))
		var i := 0
		while i < cs.size():
			var tok := cs[i]
			if tok == "." or tok == "-":
				i += 1
				continue
			var hold := 1
			while i + hold < cs.size() and cs[i + hold] == "-":
				hold += 1
			_stamp(mix, frames, ch, tok, i, float(hold) * spb, spb)
			i += hold

	var out := PackedByteArray()
	out.resize(frames * 2)
	for i in frames:
		out.encode_s16(i * 2, clampi(mix[i], -32767, 32767))
	return out


## วางโน้ตหนึ่งตัวลงบนรางผสม
##
## หางที่ล้นท้ายเพลงถูก **วนกลับไปบวกที่ต้นเพลง** ไม่ใช่ตัดทิ้ง เพราะเพลงนี้จะถูกเล่นวน
## ถ้าตัดหางทิ้งจะได้ยินเสียง "ป๊อก" ทุกครั้งที่ครบรอบ ซึ่งเป็นข้อที่แก้ทีหลังยากที่สุด
static func _stamp(mix: PackedInt32Array, frames: int, ch: String, tok: String,
		cell: int, dur: float, spb: float) -> void:
	var spec: Array = []
	if ch == "drum":
		var d: Dictionary = DRUM[tok]
		spec = ["noise", float(d["f0"]), float(d["f1"]), float(d["dur"]),
			0.002, float(d["dur"]) * 0.6, float(d["vol"])]
	else:
		var hz := note_hz(tok)
		if hz <= 0.0: return
		spec = [String(CHANNEL_WAVE[ch]), hz, hz, dur,
			0.005, minf(0.09, dur * 0.4), float(CHANNEL_VOL[ch])]

	var pcm := WQSynth.render(spec)
	var at := int(round(float(cell) * spb * float(WQSynth.RATE)))
	for i in int(pcm.size() / 2):
		mix[(at + i) % frames] += pcm.decode_s16(i * 2)


## สตรีมพร้อมเล่นวน — จุดลูปตั้งไว้ให้แล้วเพราะไฟล์ .wav ที่ Godot นำเข้าได้ loop_mode = 0 เสมอ
static func stream(id: String) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = WQSynth.RATE
	st.stereo = false
	st.data = render(id)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.data.size() / 2)
	return st
