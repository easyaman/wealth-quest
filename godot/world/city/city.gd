class_name WQCity
extends Control
## ฉากเมือง 3D — กล้อง isometric orthographic ตาม ART-DIRECTION ข้อ 2.3
##
## แผนที่ใน GDD เป็นเส้นตรง (สถานที่มีแค่พิกัด x เดียว) จึงวางอาคารเรียงตามถนนสายเดียว
## แล้วดัดถนนให้โค้งนิดหน่อย เพื่อไม่ให้ดูเป็นแถวตรงเป๊ะแบบผังตาราง
##
## กฎเหล็ก (ART-DIRECTION 4.1): world/ **ห้ามแก้ state**
## คลิกอาคาร → ยิง place_clicked(place_id) ให้ ui/main.gd เป็นคนเรียก travel_to() เอง

signal place_clicked(place_id: String)

const CAM_SIZE := 22.0
const CAM_ROT := Vector3(-30, 45, 0)
const CAM_DIST := 40.0
const ROAD_SPAN := 50.0          ## x 0–100 ใน places.json → −25..+25 หน่วยในโลก
const ROAD_CURVE := 2.0
const CLICK_RADIUS_PX := 70.0
const LAMP_COUNT := 9            ## เสาไฟตลอดถนน — คี่ เพื่อให้มีต้นหนึ่งอยู่กลางถนนพอดี

## ผังหน้าตัดของถนน (แกน Z) — อาคารอยู่ท้ายสุด แล้วไล่ออกมาหาผู้ชม
## ตัวเลขพวกนี้ต้องอยู่หลังหน้าอาคารที่ยื่นมามากที่สุด (โรงแรมยื่นสระว่ายน้ำมาถึง z=5.0)
## ถ้าตั้งใกล้กว่านี้ บันไดธนาคาร สระโรงแรม และเสาป้ายห้างจะไปตั้งอยู่กลางถนน
const WALK_Z := 6.0              ## กึ่งกลางทางเท้า
const WALK_DEPTH := 1.8
const LAMP_Z := 6.55
const TREE_Z := 5.75
const BENCH_Z := 6.5
const ROAD_Z := 9.6              ## กึ่งกลางผิวจราจร
const CAM_LOOK_UP := 2.2         ## เล็งสูงกว่าพื้นเท่านี้ ให้ตัวอาคารอยู่กลางเฟรมไม่ใช่ท้องถนน
const CAM_LOOK_Z := 3.2          ## เล็งกลางระหว่างแนวอาคารกับทางเท้า
const FLAT_MAT := "res://world/materials/flat.tres"

var _match: WQMatch
var _player = null
var _vpc: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _avatar: WQAvatar
var _places: Dictionary = {}     ## place_id -> WQPlaceNode
var _cam_target_x := 0.0
var _env: Environment
var _disasters: WQDisasterLayer
var _vfx: WQVfx
var _shake_left := 0.0           ## วินาทีที่เหลือของการสั่นกล้องตอนแผ่นดินไหว


func _init() -> void:
	custom_minimum_size = Vector2(300, 200)

	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_on_view_input)
	add_child(_vpc)

	_vp = SubViewport.new()
	# own_world_3d ต้องเป็น true เสมอ — ค่าเริ่มต้นของ SubViewport คือ "ใช้โลกร่วมกับพ่อ"
	# ซึ่งจะทำให้ฉากเมืองกับแท่นโชว์ไปกองอยู่ในโลกใบเดียวกัน แล้วต่างฝ่ายต่างเห็นของกันและกัน
	# (เคยเจอจริง: บนแท่นโชว์มีถนนกับตึกโผล่มาอยู่ข้างหลังของที่กำลังโชว์)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = WQPalette.BG_DEEP
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb0c9")
	# Sprint A ตั้งไว้ 0.45 ตอนที่อาคารยังเป็นกล่องเปล่า พอมีหน้าต่างกับรายละเอียดจริง
	# ค่านั้นทำให้ด้านที่ไม่โดนแสงตรงกลายเป็นก้อนดำอ่านไม่ออกเลย
	e.ambient_light_energy = 0.78
	# หมอกสีเดียวกับพื้นหลัง เพื่อละลายขอบฉากไม่ให้เห็นว่าถนนจบตรงไหน (ART-DIRECTION 2.2)
	e.fog_enabled = true
	e.fog_light_color = WQPalette.BG_DEEP
	e.fog_density = 0.010
	env.environment = e
	_env = e
	_vp.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	_vp.add_child(light)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_SIZE
	_cam.rotation_degrees = CAM_ROT
	_cam.far = 200.0
	_vp.add_child(_cam)
	_move_camera_to(0.0, true)

	_vp.add_child(_ground())

	_avatar = WQAvatar.new()
	_avatar.set_resolver(_stand_point_of)
	_vp.add_child(_avatar)

	# เอฟเฟกต์เป็นลูกของตัวละคร จะได้ตามตัวละครไปเองทุกครั้งที่เดินทาง
	# ไม่ต้องมีใครคอยอัปเดตตำแหน่งให้ทุกเฟรม
	_vfx = WQVfx.new()
	_vfx.name = "Vfx"
	_avatar.add_child(_vfx)

	_disasters = WQDisasterLayer.new()
	_disasters.name = "Disasters"
	_disasters.shake_requested.connect(_shake)
	_vp.add_child(_disasters)

	set_process(true)


## สร้างอาคารจาก data/places.json — เรียกได้ครั้งเดียวพอ ผังเมืองไม่เปลี่ยนระหว่างเกม
func bind(match_ref: WQMatch) -> void:
	_match = match_ref
	if _places.is_empty():
		_build_places()
		# ชั้นภัยพิบัติต้องรู้ตำแหน่งอาคารก่อน (ป้ายลดราคาแขวนหน้าร้าน ป้ายดอกเบี้ยลอยเหนือธนาคาร)
		# จึง setup ตรงนี้ ไม่ใช่ใน _init เหมือนโหนดอื่น
		_disasters.setup(_env, _avatar, _places)
	_disasters.bind(match_ref)
	_vfx.bind(match_ref)


func bind_player(player) -> void:
	if _player == player: return
	_player = player
	_avatar.bind(player)
	_vfx.bind_player(player)
	_refresh_highlight()


func _build_places() -> void:
	for p in WQData.places:
		var node := WQPlaceNode.new()
		node.name = "Place_" + String(p.id)
		_vp.add_child(node)
		node.setup(p, world_pos_of(float(p.x)))
		_places[String(p.id)] = node
	_vp.add_child(_street_props())


## ต้นไม้กับม้านั่งบนทางเท้า — **ทุกชิ้นคำนวณจาก x ของสถานที่ ห้ามสุ่ม** (ART-DIRECTION 4.1 ข้อ 3)
##
## prop อยู่บนทางเท้าไม่ใช่ข้างอาคาร เพราะช่องของอาคารบางหลังกว้างแค่ 3 หน่วย
## ต้นไม้กว้าง 1.35 ม. ถ้าปลูกข้างตึกมันจะไปทะลุผนังของตึกที่อยู่ติดกัน
## ระยะเยื้อง ±0.5 ทำให้ต้นไม้ของสถานที่ที่ใกล้กันที่สุด (ห่าง 3 หน่วย) ยังห่างกันอย่างน้อย 2 หน่วย
func _street_props() -> Node3D:
	var root := Node3D.new()
	root.name = "StreetProps"
	for p in WQData.places:
		var x := int(p.x)
		var at := world_pos_of(float(x))
		var tree := WQKitbashPlaces.prop_instance("tree")
		tree.position = at + Vector3(float(x % 5) * 0.25 - 0.5, 0.14, TREE_Z)
		# หมุนรอบแกนตั้งทีละ 30° ให้ต้นไม้ที่ใช้เมชใบเดียวกันไม่ดูเป็นแฝดกันทั้งเมือง
		tree.rotation_degrees.y = float(x % 12) * 30.0
		root.add_child(tree)
		if x % 4 != 0: continue
		var bench := WQKitbashPlaces.prop_instance("bench")
		bench.position = at + Vector3(0.5 - float(x % 5) * 0.25, 0.14, BENCH_Z)
		root.add_child(bench)
	return root


## x 0–100 ใน places.json → −25..+25 หน่วย พร้อมความโค้งของถนนที่คำนวณจาก x
## (ต้องคำนวณจาก x เสมอ ห้ามสุ่ม ไม่งั้นเมืองจะสลับที่ทุกครั้งที่เปิดเกม)
func world_pos_of(x: float) -> Vector3:
	var wx := (x - 50.0) / 100.0 * ROAD_SPAN
	return Vector3(wx, 0.0, sin(x / 100.0 * PI) * ROAD_CURVE)


func _stand_point_of(place_id: String) -> Vector3:
	var node: WQPlaceNode = _places.get(place_id)
	if node != null: return node.stand_point
	var p: Dictionary = WQData.place(place_id)
	return world_pos_of(float(p.x)) if p.has("x") else Vector3.ZERO


func _ground() -> Node3D:
	var root := Node3D.new()
	root.name = "Ground"
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	# พื้นต้องกว้างพอที่ขอบจะจมหายไปในหมอกก่อนถึงขอบเฟรม ไม่งั้นจะเห็นเป็นเส้นทแยงคมๆ
	# ตัดกลางฉาก ซึ่งอ่านเป็น "ขอบของโลก" ทันที
	pm.size = Vector2(ROAD_SPAN + 160.0, 160.0)
	plane.mesh = pm
	plane.material_override = _mat(WQPalette.NEUTRAL_5)
	root.add_child(plane)

	# ถนนเป็นแผ่นสั้นๆ ต่อกัน เพื่อให้โค้งตามเส้นเดียวกับที่วางอาคาร
	for i in 26:
		var t := float(i) / 25.0 * 100.0
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ROAD_SPAN / 25.0 + 0.15, 0.08, 5.0)
		seg.mesh = bm
		seg.position = world_pos_of(t) + Vector3(0, 0.04, ROAD_Z)
		seg.material_override = _mat(WQPalette.NEUTRAL_4)
		root.add_child(seg)

	# ทางเท้าคั่นระหว่างอาคารกับถนน — เส้นสว่างเส้นเดียวนี้ทำให้ฉากอ่านออกว่า
	# "อาคารเรียงอยู่ริมถนน" ไม่ใช่ "กล่องลอยอยู่ใกล้แถบสีเทา"
	for i in 26:
		var t := float(i) / 25.0 * 100.0
		var walk := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(ROAD_SPAN / 25.0 + 0.15, 0.14, WALK_DEPTH)
		walk.mesh = wm
		walk.position = world_pos_of(t) + Vector3(0, 0.07, WALK_Z)
		walk.material_override = _mat(WQPalette.NEUTRAL_3)
		root.add_child(walk)

	# เสาไฟริมถนน — ระยะห่างคำนวณจาก t เหมือนตัวถนน ห้ามสุ่ม (ART-DIRECTION 4.1 ข้อ 3)
	# ไม่งั้นเสาไฟจะย้ายที่ทุกครั้งที่เปิดเกม ทั้งที่มันคือสิ่งที่ผู้เล่นใช้กะระยะบนถนน
	for i in LAMP_COUNT:
		var t := float(i) / float(LAMP_COUNT - 1) * 100.0
		var lamp := WQKitbashPlaces.prop_instance("lamp")
		lamp.position = world_pos_of(t) + Vector3(0, 0.14, LAMP_Z)
		root.add_child(lamp)
	return root


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	m.albedo_color = c
	return m


## กล้องเลื่อนตาม x ของสถานที่ที่ผู้เล่นอยู่ (ART-DIRECTION 2.3) — ถนนยาว 50 หน่วย
## แต่กล้อง orthographic เห็นทีละ 22 หน่วย ถ้าไม่เลื่อนตามจะมองไม่เห็นปลายถนนเลย
func _move_camera_to(world_x: float, instant := false) -> void:
	_cam_target_x = world_x
	if instant:
		_cam.position = _cam_look_at(world_x) + _cam.transform.basis.z * CAM_DIST


## แผ่นดินไหว — เขย่ากล้องแทนที่จะเขย่าฉาก เพราะฉากมีอาคารสิบหลังกับ prop อีกหลายสิบชิ้น
## ขยับกล้องตัวเดียวได้ผลตาเดียวกันในราคาที่ถูกกว่ามาก
func _shake(seconds: float) -> void:
	_shake_left = maxf(_shake_left, seconds)


func _process(dt: float) -> void:
	if _player == null: return
	_cam_target_x = _stand_point_of(String(_player.place)).x
	var look := _cam_look_at(_cam_target_x) + _cam.transform.basis.z * CAM_DIST
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - dt)
		# คลื่นไซน์สองความถี่ที่ไม่ลงตัวกัน ให้ดูไม่เป็นจังหวะซ้ำ โดยไม่ต้องใช้ randf()
		var k := _shake_left * 0.28
		look += Vector3(sin(_shake_left * 47.0), cos(_shake_left * 31.0), 0.0) * k
	_cam.position = _cam.position.lerp(look, clampf(dt * 4.0, 0.0, 1.0))


func _cam_look_at(world_x: float) -> Vector3:
	return Vector3(world_x, CAM_LOOK_UP, CAM_LOOK_Z)


## เลือกอาคารด้วยการฉายตำแหน่ง 3D กลับมาเป็นพิกัดจอ แล้วหาหลังที่ใกล้เมาส์ที่สุด
## (ไม่ใช้ physics picking เพราะไม่อยากผูกฉากกับ collider — ฉากนี้เป็นถนนเส้นเดียว
##  ตำแหน่งอาคารรู้ล่วงหน้าอยู่แล้ว วิธีนี้จึงถูกกว่าและทดสอบแบบ headless ได้)
func place_at_screen(pos: Vector2) -> String:
	if not _cam.is_inside_tree(): return ""
	var best := ""
	var best_d := CLICK_RADIUS_PX
	for id in _places:
		var node: WQPlaceNode = _places[id]
		var at := node.position + Vector3(0, 1.2, 0)
		if _cam.is_position_behind(at): continue
		var d := _cam.unproject_position(at).distance_to(pos)
		if d < best_d:
			best_d = d
			best = String(id)
	return best


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover(place_at_screen((e as InputEventMouseMotion).position))
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id := place_at_screen((e as InputEventMouseButton).position)
		if id != "": place_clicked.emit(id)


func _hover(id: String) -> void:
	for pid in _places:
		var here: bool = _player != null and String(_player.place) == pid
		(_places[pid] as WQPlaceNode).set_highlight(here or pid == id)


func _refresh_highlight() -> void:
	_hover("")
