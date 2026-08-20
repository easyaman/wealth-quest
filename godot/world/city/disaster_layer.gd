class_name WQDisasterLayer
extends Node3D
## สภาพภัยพิบัติที่มองเห็นได้ในฉากเมือง (Sprint C ข้อ 2)
##
## ฟังสองสัญญาณจาก WQMatch เท่านั้น:
##   · `disaster_started` — ภัยพิบัติลูกใหม่เริ่ม
##   · `month_ended`      — สิ้นเดือน ใช้เช็กว่าลูกไหนหมดอายุแล้วบ้าง
## (WQMatch ไม่มีสัญญาณ "ภัยพิบัติจบ" — `tick_disasters()` แค่ลบออกจาก `active_disasters`
##  เงียบๆ ก่อนจะยิง `month_ended` ดังนั้นการอ่านรายการใหม่ทุกสิ้นเดือนคือทางเดียวที่รู้ว่าจบแล้ว)
##
## **id ทั้งเจ็ดมาจาก data/disasters.json ของจริง ไม่ได้เดาเอา:**
##   flood · plague · crisis · rate · quake · inflation · fire
## ถ้าวันหนึ่งมี id ใหม่ใน JSON แล้วที่นี่ยังไม่รู้จัก ฉากจะไม่เปลี่ยนอะไรเลย (ไม่ error)
## และ `sim/world_check.gd` จะฟ้องว่ามี id ที่ยังไม่มีสภาพในฉาก
##
## กฎเหล็ก: ชั้นนี้ **อ่านอย่างเดียว** — ไม่แตะ state ของเกม ไม่หัก hp ไม่ลดเงิน
## ตัวเลขผลกระทบทั้งหมดเป็นงานของ core/match.gd ที่นี่แค่ทำให้ "มองเห็น" ว่ากำลังเกิดอะไรขึ้น

const FLAT_MAT := "res://world/materials/flat.tres"
const WATER_LEVEL := 0.55        ## ระดับน้ำท่วมเมื่อขึ้นเต็มที่
const RISE_TIME := 1.4
const SHAKE_TIME := 1.1

## id ที่มีสภาพในฉากแล้ว — world_check ใช้ตัวนี้เทียบกับ data/disasters.json
const KNOWN := ["flood", "plague", "crisis", "rate", "quake", "inflation", "fire"]

signal shake_requested(seconds: float)   ## แผ่นดินไหว — city.gd เป็นคนสั่นกล้องให้

var active: Array[String] = []           ## id ที่กำลังมีผลอยู่ตอนนี้ (อ่านได้จากภายนอกเพื่อทดสอบ)

var _match: WQMatch
var _env: Environment
var _fog_color := Color.BLACK
var _fog_density := 0.0
var _water: MeshInstance3D
var _sale_signs: Node3D
var _rate_board: Node3D
var _cracks: Node3D
var _price_arrows: Node3D
var _smoke: GPUParticles3D
var _avatar: WQAvatar
var _tween: Tween


## ต้องรู้จัก Environment ของฉากเมือง เพราะ "เศรษฐกิจตก = fog เทา" แก้ที่ Environment ตัวเดียวกัน
## กับที่ฉากใช้อยู่ ไม่ใช่สร้างหมอกก้อนใหม่มาซ้อน
func setup(env: Environment, avatar: WQAvatar, places: Dictionary) -> void:
	_env = env
	_avatar = avatar
	if _env != null:
		_fog_color = _env.fog_light_color
		_fog_density = _env.fog_density

	_water = _make_water()
	add_child(_water)
	_sale_signs = _make_sale_signs(places)
	add_child(_sale_signs)
	_rate_board = _make_rate_board(places)
	add_child(_rate_board)
	_cracks = _make_cracks()
	add_child(_cracks)
	_price_arrows = _make_price_arrows(places)
	add_child(_price_arrows)
	_smoke = _make_smoke(places)
	add_child(_smoke)
	_apply()


func bind(match_ref: WQMatch) -> void:
	if _match == match_ref: return
	if _match != null:
		if _match.disaster_started.is_connected(_on_started):
			_match.disaster_started.disconnect(_on_started)
		if _match.month_ended.is_connected(_on_month_ended):
			_match.month_ended.disconnect(_on_month_ended)
	_match = match_ref
	if _match != null:
		_match.disaster_started.connect(_on_started)
		_match.month_ended.connect(_on_month_ended)
	_sync()


func _on_started(def: Dictionary) -> void:
	_sync()
	# แผ่นดินไหวสั่นแค่ตอน "เริ่ม" ไม่ใช่สั่นค้างสองเดือน — สั่นค้างนานๆ ทำให้เล่นไม่ไหว
	if String(def.get("id", "")) == "quake": shake_requested.emit(SHAKE_TIME)


func _on_month_ended(_month: int) -> void:
	_sync()


## อ่านรายการที่กำลังมีผลจาก match แล้วทาสภาพลงฉาก — เรียกซ้ำกี่ครั้งก็ได้ผลเท่าเดิม
func _sync() -> void:
	var now: Array[String] = []
	if _match != null:
		for d in _match.active_disasters:
			now.append(String(d.def.id))
	if now == active: return
	active = now
	_apply()


func has(id: String) -> bool:
	return active.has(id)


func _apply() -> void:
	_raise_water(has("flood"))
	if _avatar != null: _avatar.set_masked(has("plague"))
	_sale_signs.visible = has("crisis")
	_rate_board.visible = has("rate")
	_cracks.visible = has("quake")
	_price_arrows.visible = has("inflation")
	_smoke.emitting = has("fire")
	_apply_fog()


## เศรษฐกิจตก = หมอกเทาทึบขึ้น ทั้งเมืองดูซีดลงโดยไม่ต้องเปลี่ยนสีของสักชิ้น
## (เปลี่ยนสีอาคารทีละหลังทำไม่ได้ เพราะเมชทุกชิ้นใช้แผ่น palette ร่วมกัน — ART-DIRECTION 2.1)
func _apply_fog() -> void:
	if _env == null: return
	if has("crisis"):
		_env.fog_light_color = Color("6b7076")
		_env.fog_density = _fog_density * 2.0
	else:
		_env.fog_light_color = _fog_color
		_env.fog_density = _fog_density


## น้ำท่วม = แผ่นน้ำโปร่งยกขึ้นจากใต้พื้น ไม่ใช่โผล่มาทันที
## ต้องเห็นว่า "กำลังขึ้น" ผู้เล่นถึงจะรู้สึกว่าเมืองกำลังเจอเหตุ ไม่ใช่แค่ฉากเปลี่ยนสี
func _raise_water(on: bool) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	var to := WATER_LEVEL if on else -0.6
	if not is_inside_tree():
		_water.position.y = to
		_water.visible = on
		return
	_water.visible = true
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_water, "position:y", to, RISE_TIME)
	if not on: _tween.tween_callback(func(): _water.visible = false)


# ========== ชิ้นส่วนของแต่ละสภาพ ==========

func _make_water() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Flood"
	var pm := PlaneMesh.new()
	# แผ่นน้ำต้องกว้างเท่าพื้นของฉาก ไม่งั้นจะเห็นขอบแผ่นน้ำเป็นเส้นทแยงคมๆ กลางจอ
	# ซึ่งอ่านเป็น "ขอบของโลก" ไม่ใช่ "น้ำท่วมทั้งเมือง"
	pm.size = Vector2(210, 160)
	mi.mesh = pm
	mi.position = Vector3(0, -0.6, 0.0)
	var m := _mat(WQPalette.WATER)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(WQPalette.WATER, 0.62)
	mi.material_override = m
	mi.visible = false
	return mi


## ป้ายลดราคาหน้าร้านทุกหลัง — ภาษาภาพของ "ของขายไม่ออก" ที่อ่านได้โดยไม่ต้องมีตัวหนังสือ
func _make_sale_signs(places: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SaleSigns"
	for id in places:
		var node: WQPlaceNode = places[id]
		var sign_root := Node3D.new()
		sign_root.position = node.position + Vector3(0.0, 0.0, node.bounds.end.z + 0.25)
		# ขาป้าย + แผ่นป้ายเอียงเข้าหากล้อง ให้เห็นหน้าป้ายจากมุม isometric
		sign_root.add_child(_box_node(Vector3(0, 0.45, 0), Vector3(0.07, 0.9, 0.07),
			WQPalette.NEUTRAL_4))
		sign_root.add_child(_box_node(Vector3(0, 1.05, 0.05), Vector3(0.85, 0.6, 0.06),
			WQPalette.DANGER))
		sign_root.add_child(_box_node(Vector3(0, 1.05, 0.09), Vector3(0.6, 0.14, 0.03),
			WQPalette.NEUTRAL_1))
		root.add_child(sign_root)
	root.visible = false
	return root


## ดอกเบี้ยพุ่ง = ป้ายลูกศรชี้ขึ้นเหนือธนาคาร — ที่เดียวในเมืองที่พูดเรื่องดอกเบี้ย
func _make_rate_board(places: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RateBoard"
	var bank: WQPlaceNode = places.get("bank")
	if bank != null:
		root.position = bank.position + Vector3(0, bank.bounds.end.y + 1.6, 0)
		root.add_child(_box_node(Vector3.ZERO, Vector3(1.5, 1.0, 0.1), WQPalette.DANGER))
		# ลูกศรชี้ขึ้น: ก้าน + หัวลูกศรที่ทำจากกล่องเล็กสองใบเหลื่อมกัน
		root.add_child(_box_node(Vector3(0, 0, 0.08), Vector3(0.18, 0.6, 0.06),
			WQPalette.NEUTRAL_1))
		root.add_child(_box_node(Vector3(0, 0.34, 0.08), Vector3(0.5, 0.16, 0.06),
			WQPalette.NEUTRAL_1))
		root.add_child(_box_node(Vector3(0, 0.46, 0.08), Vector3(0.28, 0.16, 0.06),
			WQPalette.NEUTRAL_1))
	root.visible = false
	return root


## แผ่นดินไหว = รอยแตกบนถนน วางเป็นระยะคำนวณจาก index ไม่ใช่สุ่ม
func _make_cracks() -> Node3D:
	var root := Node3D.new()
	root.name = "Cracks"
	for i in 11:
		var t := float(i) / 10.0
		var x := -24.0 + t * 48.0
		for j in 3:
			var seg := _box_node(
				Vector3(x + float(j) * 0.55 - 0.55, 0.16, 7.0 + float((i + j) % 3) * 1.4),
				Vector3(0.5 - float(j) * 0.12, 0.02, 0.16), WQPalette.BG_DEEP)
			seg.rotation_degrees.y = float((i * 7 + j * 23) % 60) - 30.0
			root.add_child(seg)
	root.visible = false
	return root


## ค่าครองชีพพุ่ง = ลูกศรราคาลอยเหนือที่ที่ต้องจ่ายเงิน (ห้าง ร้านทอง บ้าน)
func _make_price_arrows(places: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "PriceArrows"
	for id in ["mall", "gold", "home"]:
		var node: WQPlaceNode = places.get(id)
		if node == null: continue
		var a := Node3D.new()
		a.position = node.position + Vector3(0, node.bounds.end.y + 1.1, 0)
		a.add_child(_box_node(Vector3.ZERO, Vector3(0.16, 0.8, 0.16), WQPalette.DANGER))
		a.add_child(_box_node(Vector3(0, 0.46, 0), Vector3(0.46, 0.18, 0.46), WQPalette.DANGER))
		a.add_child(_box_node(Vector3(0, 0.6, 0), Vector3(0.24, 0.18, 0.24), WQPalette.DANGER))
		root.add_child(a)
	root.visible = false
	return root


## ไฟไหม้ย่านการค้า = ควันลอยขึ้นจากศูนย์อสังหาฯ & ตลาดธุรกิจ
## (ภัยพิบัตินี้เผา asset ประเภท business/micro ซึ่งทั้งหมดซื้อขายกันที่ estate)
func _make_smoke(places: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "FireSmoke"
	var at := Vector3(0, 4.0, 0)
	var node: WQPlaceNode = places.get("estate")
	if node != null: at = node.position + Vector3(0, node.bounds.end.y + 0.3, 0)
	p.position = at
	p.amount = 28
	p.lifetime = 2.6
	p.emitting = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 18.0
	m.initial_velocity_min = 1.1
	m.initial_velocity_max = 2.2
	m.gravity = Vector3(0, 0.35, 0)
	m.scale_min = 0.6
	m.scale_max = 1.8
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.7
	p.process_material = m
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.42, 0.42)
	p.draw_pass_1 = bm
	p.material_override = _mat(WQPalette.NEUTRAL_4)
	return p


func _box_node(at: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = at
	mi.material_override = _mat(color)
	return mi


## ของในชั้นนี้ไม่ใช่ "โมเดล" จึงย้อมสีตรงๆ ได้ (ART-DIRECTION 2.1 ห้ามย้อมเฉพาะเมชของโมเดล)
## เพราะมันคือสัญญาณสถานะ ไม่ใช่ของที่ผู้เล่นซื้อขายได้ และต้องใช้สี DANGER ให้อ่านออกทันที
func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	m.albedo_color = c
	return m
