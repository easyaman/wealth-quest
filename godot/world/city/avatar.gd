class_name WQAvatar
extends Node3D
## ตัวละครผู้เล่นในฉากเมือง — เดินไปยังสถานที่ใหม่เมื่อ player.place เปลี่ยน
## พร้อมแอนิเมชัน 6 แบบที่ทำด้วยการขยับชิ้นส่วนเอง (Sprint C ข้อ 4)
##
## กฎเหล็ก: การเดินและแอนิเมชันทั้งหมดเป็น **ภาพล้วน** ไม่มีผลต่อสถานะเกม
## และต้องข้ามได้เสมอ — ถ้าผู้เล่นสั่งเดินทางซ้ำระหว่างยังเดินไม่ถึง ให้วาร์ปไปเลย
## ห้ามให้ผู้เล่นต้องนั่งรอแอนิเมชันเพื่อกดปุ่มถัดไป (ART-DIRECTION 4.1)
##
## **ยังไม่มีริกจริง** จึงเป็นท่าที่คำนวณจากเวลา (bob/tilt/แกว่งแขน) ตามที่ Sprint C อนุญาตไว้
## วันที่ได้ตัวละครมีกระดูกมาแล้ว ให้แทนที่ `_pose()` ด้วย AnimationPlayer โดยที่ชื่อท่าทั้งหกไม่ต้องเปลี่ยน
##
## ท่าไหนถูกเลือกมาจากสถานะของ core ล้วนๆ ไม่มีใครสั่งท่าจากภายนอกได้:
##   walk      กำลังเดินไปสถานที่ใหม่
##   celebrate ทำความฝันสำเร็จแล้ว (dream_done > 0)
##   hit       สุขภาพเพิ่งลดลงจากครั้งก่อน
##   tired     สุขภาพต่ำกว่า 40
##   work      ยืนอยู่ที่ออฟฟิศหรือ co-working
##   idle      นอกนั้นทั้งหมด

const WALK_TIME := 0.6
const HIT_TIME := 0.7            ## ท่าโดนกระแทกค้างไว้เท่านี้แล้วกลับไปท่าปกติ
const TIRED_HEALTH := 40.0       ## ต่ำกว่านี้ = ท่าเหนื่อย (ตรงกับเกณฑ์สีแถบสุขภาพใน ui/main.gd)
const WORK_PLACES := ["office", "cowork"]
const FLAT_MAT := "res://world/materials/flat.tres"

var state := "idle"              ## ท่าที่กำลังเล่นอยู่ — อ่านได้จากภายนอกเพื่อทดสอบ

var _player = null
var _target := Vector3.ZERO
var _tween: Tween
var _resolve: Callable           ## city.gd ส่งฟังก์ชันแปลง place_id -> จุดยืน มาให้
var _rig: Node3D                 ## โหนดกลางที่ยก/เอียงทั้งตัว
var _torso: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _mask: MeshInstance3D
var _t := 0.0                    ## นาฬิกาของแอนิเมชัน
var _hit_left := 0.0
var _last_health := 100.0


func _init() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# แยกเป็นชิ้นๆ เพราะท่าทั้งหกต้องขยับคนละส่วนกัน — แคปซูลใบเดียวจาก Sprint A
	# ทำได้แค่ยกขึ้นลงทั้งตัว ซึ่งแยกไม่ออกว่า "เดิน" ต่างจาก "ดีใจ" ตรงไหน
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position.y = 0.72
	_rig.add_child(_torso)
	_torso.add_child(_part(Vector3(0, 0.28, 0), Vector3(0.46, 0.56, 0.28), WQPalette.ACCENT_STEEL))

	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = 0.62
	_torso.add_child(_head)
	_head.add_child(_part(Vector3(0, 0.16, 0), Vector3(0.3, 0.32, 0.3), WQPalette.NEUTRAL_2))
	_head.add_child(_part(Vector3(0, 0.34, 0), Vector3(0.34, 0.08, 0.34), WQPalette.NEUTRAL_5))

	# หน้ากากอนามัย — โผล่เฉพาะตอนมีโรคระบาด (WQDisasterLayer เป็นคนสั่ง)
	_mask = _part(Vector3(0, 0.12, 0.16), Vector3(0.26, 0.14, 0.04), WQPalette.NEUTRAL_1)
	_mask.name = "Mask"
	_mask.visible = false
	_head.add_child(_mask)

	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.3, 0.5, 0)
		_torso.add_child(arm)
		arm.add_child(_part(Vector3(0, -0.22, 0), Vector3(0.13, 0.48, 0.13), WQPalette.NEUTRAL_2))
		_arms.append(arm)

		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.13, 0.72, 0)
		_rig.add_child(leg)
		leg.add_child(_part(Vector3(0, -0.36, 0), Vector3(0.16, 0.72, 0.18), WQPalette.NEUTRAL_4))
		_legs.append(leg)

	set_process(true)


func set_resolver(f: Callable) -> void:
	_resolve = f


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(_on_changed):
		_player.changed.disconnect(_on_changed)
	_player = player
	if _player != null:
		_player.changed.connect(_on_changed)
		_last_health = _player.health
	_hit_left = 0.0
	_snap_to_player()
	_pick_state()


## หน้ากากอนามัยตอนมีโรคระบาด — เปิด/ปิดจาก WQDisasterLayer เท่านั้น
func set_masked(on: bool) -> void:
	if _mask != null: _mask.visible = on


func is_masked() -> bool:
	return _mask != null and _mask.visible


## ย้ายทันทีโดยไม่มีแอนิเมชัน — ใช้ตอนผูกผู้เล่นครั้งแรกและตอนสลับผู้เล่น
func _snap_to_player() -> void:
	if _player == null or not _resolve.is_valid(): return
	_target = _resolve.call(String(_player.place))
	_kill_tween()
	position = _target


func _on_changed() -> void:
	if _player == null or not _resolve.is_valid(): return

	# สุขภาพลดลงตั้งแต่ครั้งก่อน = เพิ่งโดนอะไรมา → เล่นท่าโดนกระแทกสั้นๆ
	# (อ่านจาก state ของ core อย่างเดียว ไม่ได้ให้ใครมาสั่งท่าจากข้างนอก)
	if _player.health < _last_health - 0.01: _hit_left = HIT_TIME
	_last_health = _player.health

	var want: Vector3 = _resolve.call(String(_player.place))
	if want.is_equal_approx(_target):
		_pick_state()
		return

	# ยังเดินไม่ถึงแล้วมีคำสั่งใหม่เข้ามา = ผู้เล่นไม่ได้รอดูอยู่แล้ว → วาร์ปไปเลย
	var warp := _tween != null and _tween.is_running()
	_target = want
	_kill_tween()
	if warp or not is_inside_tree():
		position = _target
		_pick_state()
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _target, WALK_TIME)
	_tween.tween_callback(_pick_state)
	_pick_state()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _is_walking() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## ลำดับความสำคัญของท่า — ท่าที่บอกเรื่องเร่งด่วนกว่าชนะเสมอ
func _pick_state() -> void:
	var want := "idle"
	if _is_walking(): want = "walk"
	elif _player == null: want = "idle"
	elif _player.dream_done > 0: want = "celebrate"
	elif _hit_left > 0.0: want = "hit"
	elif _player.health < TIRED_HEALTH: want = "tired"
	elif WORK_PLACES.has(String(_player.place)): want = "work"
	if want != state:
		state = want
		_t = 0.0


func _process(dt: float) -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(0.0, _hit_left - dt)
		if _hit_left == 0.0: _pick_state()
	_pick_state()
	_t += dt
	_pose()


## ท่าทั้งหกทำจากคลื่นไซน์ล้วน — ไม่มี randf() เพราะท่าที่สุ่มจะกระตุกและอ่านไม่ออกว่าเป็นท่าอะไร
func _pose() -> void:
	var swing := 0.0
	var bob := 0.0
	var lean := 0.0
	var arm_lift := 0.0
	var head_tilt := 0.0

	match state:
		"walk":
			swing = sin(_t * 11.0) * 32.0
			bob = absf(sin(_t * 11.0)) * 0.07
			lean = -6.0
		"work":
			# ก้มหน้าทำงาน แขนขยับสั้นๆ เหมือนพิมพ์งาน
			swing = 0.0
			bob = sin(_t * 3.0) * 0.012
			lean = 9.0
			arm_lift = -58.0 + sin(_t * 9.0) * 5.0
			head_tilt = 13.0
		"tired":
			# หายใจช้าและหนัก ไหล่ห่อ หัวตก — อ่านออกจากระยะไกลว่า "ไม่ไหวแล้ว"
			bob = sin(_t * 1.7) * 0.035 - 0.06
			lean = 13.0
			head_tilt = 20.0
			arm_lift = 9.0
		"celebrate":
			bob = absf(sin(_t * 7.0)) * 0.22
			arm_lift = -150.0 + sin(_t * 7.0) * 18.0
			head_tilt = -12.0
		"hit":
			# สะบัดถอยหลังแล้วค่อยๆ กลับ — ใช้เวลาที่เหลือเป็นตัวลดความแรง
			var k := _hit_left / HIT_TIME
			lean = -30.0 * k
			bob = -0.1 * k
			arm_lift = 40.0 * k
		_:
			bob = sin(_t * 2.2) * 0.022
			swing = sin(_t * 2.2) * 2.5

	_rig.position.y = bob
	_rig.rotation_degrees.x = lean
	_head.rotation_degrees.x = head_tilt
	for i in _arms.size():
		var dir := 1.0 if i == 0 else -1.0
		_arms[i].rotation_degrees.x = swing * dir + arm_lift
	for i in _legs.size():
		var dir2 := -1.0 if i == 0 else 1.0
		_legs[i].rotation_degrees.x = swing * dir2


func _part(at: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = at
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	# ตัวละครห้ามใช้สีเงิน/เวลา/สุขภาพเป็นสีหลัก — สามสีนั้นจองไว้บอกสถานะ
	m.albedo_color = color
	mi.material_override = m
	return mi
