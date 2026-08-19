class_name WQPlaceNode
extends Node3D
## อาคารหนึ่งหลังในฉากเมือง — โหลด world/models/places/<id>.glb ถ้ามี ไม่มีก็ใช้กล่องแทน
##
## กฎเหล็ก (ART-DIRECTION 4.1): โหนดนี้ **อ่านอย่างเดียว** ไม่แตะ state ของเกม
## คลิกแล้วแค่บอก city.gd ว่าโดนคลิก คนตัดสินใจว่าจะเดินทางไหมคือ ui/main.gd

const MODEL_DIR := "res://world/models/places"
const FLAT_MAT := "res://world/materials/flat.tres"
const SIGN_HEIGHT := 0.9        ## ป้ายชื่อลอยเหนือหลังคาเท่าไหร่

var place: Dictionary = {}
var stand_point := Vector3.ZERO ## จุดที่ตัวละครไปยืนเมื่อมาถึงที่นี่

var _body: MeshInstance3D
var _sign: Label3D
var _base_color := Color.WHITE


func setup(p: Dictionary, world_pos: Vector3) -> void:
	place = p
	position = world_pos

	# ความสูงต้องคำนวณจากข้อมูลของสถานที่ ไม่ใช่สุ่ม — ไม่งั้นเมืองจะหน้าตาไม่เหมือนเดิมทุกครั้ง
	# ที่เปิดเกม แล้วผู้เล่นจะจำไม่ได้ว่าตึกไหนคือธนาคาร (ART-DIRECTION 4.1 ข้อสุดท้าย)
	var h := 2.0 + float(int(p.x) % 7) * 0.6
	var w := 2.4 + float(int(p.x) % 3) * 0.4

	_body = MeshInstance3D.new()
	_body.name = "Body"
	var model := _load_model(String(p.id))
	if model != null:
		add_child(model)
		_body.mesh = null
	else:
		var box := BoxMesh.new()
		box.size = Vector3(w, h, w)
		_body.mesh = box
		_body.position.y = h * 0.5      # origin ที่ฐาน เหมือนสเปกโมเดลจริง
		# สีอาคารมาจาก places.json แต่หรี่ลงให้เป็นฉากหลัง ไม่แย่งสายตากับ HUD
		_base_color = Color(String(p.color)).darkened(0.15) if p.has("color") else Color("8b8578")
		_body.material_override = _mat(_base_color)
		add_child(_body)

	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "%s %s" % [p.get("icon", ""), p.get("name", p.id)]
	_sign.font = WQFonts.thai()
	_sign.font_size = 64
	_sign.pixel_size = 0.014
	_sign.position = Vector3(0, h + SIGN_HEIGHT, 0)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.outline_size = 16
	_sign.outline_modulate = WQPalette.BG_DEEP
	add_child(_sign)

	stand_point = position + Vector3(0, 0, w * 0.5 + 1.2)


## ไฮไลต์ตอนเมาส์ชี้ / ตอนเป็นที่ที่ผู้เล่นยืนอยู่ — บอกด้วยความสว่าง ไม่ใช่สีใหม่
## เพราะสีในเกมนี้ถูกจองไว้บอกความหมาย (เงิน/เวลา/สุขภาพ) แล้ว
func set_highlight(on: bool) -> void:
	if _body == null or _body.mesh == null: return
	_body.material_override = _mat(_base_color.lightened(0.35) if on else _base_color)


func _load_model(id: String) -> Node3D:
	var path := "%s/%s.glb" % [MODEL_DIR, id]
	if not ResourceLoader.exists(path): return null
	var packed := load(path)
	return (packed as PackedScene).instantiate() if packed is PackedScene else null


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null      # เมชพื้นฐาน UV กินทั้งแผ่น palette จะได้แถบสีรุ้งแทนสีเดียว
	m.albedo_color = c
	return m
