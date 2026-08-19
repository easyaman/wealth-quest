class_name WQAvatar
extends Node3D
## ตัวละครผู้เล่นในฉากเมือง — เดินไปยังสถานที่ใหม่เมื่อ player.place เปลี่ยน
##
## กฎเหล็ก: การเดินเป็น **แอนิเมชันล้วน** ไม่มีผลต่อสถานะเกม
## และต้องข้ามได้เสมอ — ถ้าผู้เล่นสั่งเดินทางซ้ำระหว่างยังเดินไม่ถึง ให้วาร์ปไปเลย
## ห้ามให้ผู้เล่นต้องนั่งรอแอนิเมชันเพื่อกดปุ่มถัดไป (ART-DIRECTION 4.1)

const WALK_TIME := 0.6
const FLAT_MAT := "res://world/materials/flat.tres"

var _player = null
var _target := Vector3.ZERO
var _tween: Tween
var _resolve: Callable          ## city.gd ส่งฟังก์ชันแปลง place_id -> จุดยืน มาให้


func _init() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	cap.radial_segments = 8     # เหลี่ยมชัด ตามสไตล์ low poly
	cap.rings = 2
	mi.mesh = cap
	mi.position.y = 0.85        # origin ที่ฐาน
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	m.albedo_color = WQPalette.NEUTRAL_2   # ตัวละครห้ามใช้สีเงิน/เวลา/สุขภาพเป็นสีหลัก
	mi.material_override = m
	add_child(mi)


func set_resolver(f: Callable) -> void:
	_resolve = f


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(_on_changed):
		_player.changed.disconnect(_on_changed)
	_player = player
	if _player != null:
		_player.changed.connect(_on_changed)
	_snap_to_player()


## ย้ายทันทีโดยไม่มีแอนิเมชัน — ใช้ตอนผูกผู้เล่นครั้งแรกและตอนสลับผู้เล่น
func _snap_to_player() -> void:
	if _player == null or not _resolve.is_valid(): return
	_target = _resolve.call(String(_player.place))
	_kill_tween()
	position = _target


func _on_changed() -> void:
	if _player == null or not _resolve.is_valid(): return
	var want: Vector3 = _resolve.call(String(_player.place))
	if want.is_equal_approx(_target): return

	# ยังเดินไม่ถึงแล้วมีคำสั่งใหม่เข้ามา = ผู้เล่นไม่ได้รอดูอยู่แล้ว → วาร์ปไปเลย
	var warp := _tween != null and _tween.is_running()
	_target = want
	_kill_tween()
	if warp or not is_inside_tree():
		position = _target
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _target, WALK_TIME)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null
