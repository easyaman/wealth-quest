class_name WQVfx
extends Node3D
## เอฟเฟกต์อนุภาคสี่ตัวของฉากเมือง (Sprint C ข้อ 3) — payday · deal_closed · disaster · win
##
## **ทริกเกอร์จากสัญญาณเท่านั้น** ไม่มีใครเรียก play() จากภายนอกได้นอกจากตัวจัดการสัญญาณข้างล่าง
## เพราะถ้าปล่อยให้ ui/ สั่งยิงเอฟเฟกต์เองได้ วันหนึ่งจะมีเอฟเฟกต์ที่เด้งทั้งที่เกมไม่ได้เกิดอะไรขึ้น
##   payday      · WQMatch.month_ended  (เฉพาะเดือนที่เหลือเก็บเป็นบวก)
##   deal_closed · WQPlayer.deal_closed
##   disaster    · WQMatch.disaster_started
##   win         · WQMatch.player_finished (เฉพาะตอนที่คนที่จบคือคนที่ฉากนี้กำลังตามอยู่)
##
## เมชของอนุภาคเป็นกล่องเหลี่ยม ไม่ใช่ sprite กลมๆ เพื่อให้อยู่ในสไตล์ low poly เดียวกับทั้งฉาก

const FLAT_MAT := "res://world/materials/flat.tres"
const KINDS := ["payday", "deal_closed", "disaster", "win"]

## [สี, จำนวน, อายุ, ความเร็วต่ำ, ความเร็วสูง, แรงโน้มถ่วง, ขนาดกล่อง]
## payday  เหรียญพุ่งขึ้นแล้วตกลง        · สี money
## deal    ประกายเขียวกระจายรอบตัว       · สี win
## disaster เศษของร่วงลงจากด้านบน        · สี danger
## win     ลูกปาสีทองพุ่งสูงและอยู่นาน    · สี money แต่เยอะและนานกว่า payday ชัดเจน
const SPEC := {
	"payday": [WQPalette.MONEY, 26, 1.3, 2.6, 4.2, -9.0, 0.16],
	"deal_closed": [WQPalette.WIN, 22, 0.9, 2.2, 3.6, -3.0, 0.14],
	"disaster": [WQPalette.DANGER, 34, 1.6, 0.6, 1.6, -7.0, 0.2],
	"win": [WQPalette.MONEY, 64, 2.4, 4.0, 6.5, -6.0, 0.18],
}

var played: Array[String] = []          ## ประวัติการยิง — world_check ใช้ตรวจว่าสัญญาณไหนยิงอะไร

var _match: WQMatch
var _player = null
var _emitters: Dictionary = {}          ## kind -> GPUParticles3D


func _init() -> void:
	for kind in KINDS:
		var e := _make(kind)
		_emitters[kind] = e
		add_child(e)


func bind(match_ref: WQMatch) -> void:
	if _match == match_ref: return
	if _match != null:
		if _match.month_ended.is_connected(_on_month_ended):
			_match.month_ended.disconnect(_on_month_ended)
		if _match.disaster_started.is_connected(_on_disaster):
			_match.disaster_started.disconnect(_on_disaster)
		if _match.player_finished.is_connected(_on_finished):
			_match.player_finished.disconnect(_on_finished)
	_match = match_ref
	if _match != null:
		_match.month_ended.connect(_on_month_ended)
		_match.disaster_started.connect(_on_disaster)
		_match.player_finished.connect(_on_finished)


func bind_player(player) -> void:
	if _player == player: return
	if _player != null and _player.deal_closed.is_connected(_on_deal_closed):
		_player.deal_closed.disconnect(_on_deal_closed)
	_player = player
	if _player != null:
		_player.deal_closed.connect(_on_deal_closed)


## เงินเดือนออก — ยิงเฉพาะเดือนที่ "เหลือเก็บเป็นบวก" ไม่ใช่ทุกสิ้นเดือน
## เดือนที่ติดลบแล้วมีเหรียญทองพุ่งขึ้นจะสอนผู้เล่นผิดว่าเดือนนี้ผ่านไปด้วยดี
func _on_month_ended(_month: int) -> void:
	if _player == null: return
	if _player.get_total_income() - _player.get_total_expenses() > 0.0: play("payday")


func _on_deal_closed(_deal: Dictionary) -> void:
	play("deal_closed")


func _on_disaster(_def: Dictionary) -> void:
	play("disaster")


func _on_finished(p) -> void:
	if p == _player: play("win")


## ยิงเอฟเฟกต์ที่ตำแหน่งของโหนดนี้ (city.gd ผูกมันไว้กับตัวละครอยู่แล้ว)
func play(kind: String) -> void:
	var e: GPUParticles3D = _emitters.get(kind)
	if e == null: return
	played.append(kind)
	e.restart()
	e.emitting = true


func _make(kind: String) -> GPUParticles3D:
	var spec: Array = SPEC[kind]
	var p := GPUParticles3D.new()
	p.name = kind
	p.amount = int(spec[1])
	p.lifetime = float(spec[2])
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.85              # ระเบิดออกทีเดียว ไม่ใช่พ่นเรื่อยๆ
	p.position.y = 1.1                  # ออกจากระดับอกของตัวละคร ไม่ใช่จากพื้น

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 45.0 if kind != "disaster" else 80.0
	m.initial_velocity_min = float(spec[3])
	m.initial_velocity_max = float(spec[4])
	m.gravity = Vector3(0, float(spec[5]), 0)
	m.scale_min = 0.7
	m.scale_max = 1.3
	m.angular_velocity_min = -220.0     # หมุนคว้าง ให้เห็นว่าเป็นก้อนเหลี่ยมไม่ใช่จุดสี
	m.angular_velocity_max = 220.0
	p.process_material = m

	var bm := BoxMesh.new()
	var s := float(spec[6])
	bm.size = Vector3(s, s, s)
	p.draw_pass_1 = bm

	var mat: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	mat.albedo_texture = null
	# เอฟเฟกต์คือ "สัญญาณสถานะ" ไม่ใช่ของในฉาก จึงใช้สี money/win/danger ได้ตรงตามความหมาย
	mat.albedo_color = spec[0]
	p.material_override = mat
	return p
