class_name WQShowcase
extends MarginContainer
## แท่นโชว์ของ — หัวใจของการนำเสนอตาม ART-DIRECTION ข้อ 1.3 และ 4.2
##
## เกมนี้ขาย "การตัดสินใจซื้อ" ของจึงต้องดูน่าอยากก่อน แล้วปล่อยให้ตัวเลขเป็นคนเบรก
## ใช้ซ้ำทุกที่ที่ผู้เล่นเลือกของ: ดีล · พาหนะ/อุปกรณ์ · แพ็กเกจ · ความฝัน · หน้าเลือกอาชีพ
##
## API: show_item(kind, id, stats, title)
##   **ชื่อเมธอดไม่ใช่ show() ตามที่เขียนไว้ใน ../CLAUDE-CODE-BRIEF.md**
##   เพราะ Control มี show() ของตัวเองอยู่แล้ว ทับแล้ว GDScript จะ parse ไม่ผ่านทั้งไฟล์
##
## กฎเหล็ก: อ่านอย่างเดียว — วิดเจ็ตนี้ไม่แตะ state ของเกม และตัวเลขใน stats
## ต้องถูกคำนวณมาจาก core แล้วเท่านั้น ที่นี่แค่วาด

const MODEL_DIR := "res://world/models"
const FLAT_MAT := "res://world/materials/flat.tres"
const SPIN_DEG_PER_SEC := 12.0
const DRAG_DEG_PER_PIXEL := 0.4
const FOV := 35.0

## พื้นหลัง gradient แยกตาม "กลุ่มของ" เพื่อให้ผู้เล่นรู้ว่ากำลังดูของประเภทไหนโดยไม่ต้องอ่าน
const KIND_BG := {
	"vehicles": [Color("13233f"), Color("2f4d8f")],
	"devices": [Color("13233f"), Color("2f4d8f")],
	"assets": [Color("162b28"), Color("3a6b5c")],
	"places": [Color("162b28"), Color("3a6b5c")],
	"packs": [Color("162b28"), Color("3a6b5c")],
	"dreams": [Color("2a1c3f"), Color("8a6b2f")],
	"character": [Color("1b2d5b"), Color("3d5ba9")],
}

## สีของเมชแทนที่ (ตอนยังไม่มี .glb) — ห้ามใช้สีเงิน/เวลา/สุขภาพ เพราะสามสีนั้นจองไว้บอกสถานะ
const KIND_TINT := {
	"vehicles": Color("3b4a5c"), "devices": Color("4a463f"),
	"assets": Color("7a3b2e"), "places": Color("8b8578"),
	"packs": Color("c9c2b4"), "dreams": Color("7a3b2e"),
	"character": Color("c9c2b4"),
}

var kind := ""
var id := ""

var _vpc: SubViewportContainer
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _title: Label
var _stats_box: VBoxContainer
var _model: Node3D
var _spin := 0.0
var _bg_top := Color("1b2d5b")
var _bg_bot := Color("3d5ba9")
var _dragging := false


## เป็น MarginContainer ไม่ใช่ Control เปล่า เพราะ Control ไม่รายงานขนาดต่ำสุดจากลูก
## แล้ว VBox ที่ถือมันอยู่จะบีบให้เตี้ยกว่าเนื้อหาจริง จนแถบสถิติล้นไปทับวิดเจ็ตตัวถัดไป
## ส่วนพื้นหลัง gradient วาดด้วย _draw() ของตัวเอง — คอนเทนเนอร์วาดก่อนลูกเสมอ
## จึงไม่ต้องมีโหนดพื้นหลังแยกให้ต้องคอยจัดขนาดตาม
func _init() -> void:
	custom_minimum_size = Vector2(300, 340)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 12)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.custom_minimum_size = Vector2(0, 220)
	# ต้องรับอินพุตเองเพื่อให้ลากหมุนได้ แต่ห้ามส่งต่อเข้าไปในโลก 3D
	# (ไม่งั้น InputEvent จะวิ่งเข้า SubViewport แล้วเด้งกลับมาเป็นวงซ้ำ)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_on_view_input)
	col.add_child(_vpc)

	_vp = SubViewport.new()
	_vp.transparent_bg = true          # ให้ gradient 2D ข้างหลังทะลุขึ้นมาเป็นพื้นหลัง
	# own_world_3d ต้องเป็น true เสมอ — ค่าเริ่มต้นของ SubViewport คือ "ใช้โลกร่วมกับพ่อ"
	# ซึ่งจะทำให้ฉากเมืองกับแท่นโชว์ไปกองอยู่ในโลกใบเดียวกัน แล้วต่างฝ่ายต่างเห็นของกันและกัน
	# (เคยเจอจริง: บนแท่นโชว์มีถนนกับตึกโผล่มาอยู่ข้างหลังของที่กำลังโชว์)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X     # low poly ไม่มี AA = ขอบเป็นบันไดทันที
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb0c9")     # ambient ฟ้าอ่อนตาม ART-DIRECTION 2.2
	e.ambient_light_energy = 0.52
	env.environment = e
	_vp.add_child(env)

	# แสงดวงเดียวจากบนซ้าย-หน้า — low poly ต้องการแสงเดียวเพื่อให้แต่ละหน้าได้สีต่างกันชัดๆ
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 30, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	_vp.add_child(light)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = FOV
	_vp.add_child(_cam)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_stats_box)

	set_process(true)


## โชว์ของหนึ่งชิ้นพร้อมแถบสถิติ
##   kind  — โฟลเดอร์ใน world/models/ (vehicles, devices, assets, dreams, packs, places, character)
##   id    — ชื่อไฟล์ .glb และเป็น id เดียวกับใน data/*.json
##   stats — [{label, value, max, color, text?}] วาดเป็น WQStatBar เรียงใต้ภาพ
## ไม่มีไฟล์โมเดล = ใช้กล่องสีแทน ไม่ error (ART-DIRECTION 2.1)
func show_item(item_kind: String, item_id: String, stats: Array, title := "") -> void:
	kind = item_kind
	id = item_id
	_title.text = title
	_title.visible = title != ""
	var bg: Array = KIND_BG.get(item_kind, [Color("1b2d5b"), Color("3d5ba9")])
	_bg_top = bg[0]
	_bg_bot = bg[1]
	queue_redraw()
	_set_model(item_kind, item_id)
	_set_stats(stats)


## โชว์เมชที่คนเรียกปั้นมาเองแล้ว แทนที่จะให้แท่นโชว์ไปหาโมเดลจาก kind/id
##
## มีไว้เพื่อกรณีเดียว: หน้าเลือกอาชีพ ซึ่งต้องโชว์ "ตัวละครในชุดอาชีพ" 16 แบบ
## ที่ประกอบขึ้นตอนรันไทม์จาก WQKitbashChar — ไม่ใช่ไฟล์โมเดล 16 ไฟล์ในเช็กลิสต์
## ทางอื่นทั้งหมดต้องใช้ show_item() ตามเดิม เพื่อให้ของบนแท่นกับไอคอนใน UI เป็นชิ้นเดียวกันเสมอ
func show_built(item_kind: String, item_id: String, node: Node3D, stats: Array,
		title := "") -> void:
	kind = item_kind
	id = item_id
	_title.text = title
	_title.visible = title != ""
	var bg: Array = KIND_BG.get(item_kind, [Color("1b2d5b"), Color("3d5ba9")])
	_bg_top = bg[0]
	_bg_bot = bg[1]
	queue_redraw()
	_install_model(node)
	_set_stats(stats)


static func model_path(item_kind: String, item_id: String) -> String:
	return "%s/%s/%s.glb" % [MODEL_DIR, item_kind, item_id]


## มีโมเดลจริงแล้วหรือยัง — world_check และ icon_bake ใช้ตัวนี้ตรวจ ไม่ต้องเดาเอง
static func has_model(item_kind: String, item_id: String) -> bool:
	return ResourceLoader.exists(model_path(item_kind, item_id))


func _set_model(item_kind: String, item_id: String) -> void:
	_install_model(model_for(item_kind, item_id))


## ล้างของเก่าออกจากแท่นแล้ววางของใหม่ + จัดกล้องให้พอดี
## ใช้ remove_child() + free() ไม่ใช่ queue_free() — เหตุผลเดียวกับวิดเจ็ตอื่นในโปรเจกต์นี้
## (โหนดที่รอลบยังนับเป็นลูกอยู่ ถ้าเปลี่ยนของสองครั้งในเฟรมเดียวของจะซ้อนกันบนแท่น)
func _install_model(node: Node3D) -> void:
	for c in _pivot.get_children():
		_pivot.remove_child(c)
		c.free()
	_model = node
	_pivot.add_child(_model)
	_pivot.add_child(_pedestal())
	_frame_camera(aabb_of(_model))


## ลำดับการหาของมาโชว์ — ที่เดียวในเกมที่ตัดสินใจเรื่องนี้ ตัวอบไอคอนก็เรียกตัวนี้
## เพื่อให้ไอคอนกับของบนแท่นเป็นชิ้นเดียวกันเสมอ ไม่ใช่คนละอย่างที่บังเอิญชื่อเหมือนกัน
##   1. .glb จริง  2. เมชต่อกล่องจาก WQKitbash  3. กล่องเปล่าตามกลุ่มของ (ห้าม error)
static func model_for(item_kind: String, item_id: String) -> Node3D:
	var path := model_path(item_kind, item_id)
	if ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			return (packed as PackedScene).instantiate()
	var kit := WQKitbash.build(item_kind, item_id)
	if kit != null: return kit
	return placeholder_for(item_kind)


## กล่องแทนโมเดลจริง — สูงต่างกันตามกลุ่มของ เพื่อให้เห็นว่าเปลี่ยนของแล้วจริงๆ
## เป็น static เพราะ world/tools/icon_bake.gd ต้องอบไอคอนจากของชิ้นเดียวกันเป๊ะ
static func placeholder_for(item_kind: String) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "Placeholder"
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.7, 1.6) if item_kind == "vehicles" else Vector3(0.9, 1.1, 0.9)
	mi.mesh = box
	mi.position.y = box.size.y * 0.5     # origin ที่ฐาน ตามสเปกโมเดลจริง
	mi.material_override = tinted_flat(KIND_TINT.get(item_kind, Color("8b8578")))
	return mi


static func _pedestal() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "Pedestal"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.95
	cyl.height = 0.1
	cyl.radial_segments = 12             # เหลี่ยมชัดๆ ตามสไตล์ low poly ไม่เอาทรงกลมเนียน
	mi.mesh = cyl
	mi.position.y = -0.05
	mi.material_override = tinted_flat(Color("4a463f"))
	return mi


## ยืมค่า roughness/metallic/specular จาก flat.tres มาให้เหมือนโมเดลจริง
## แต่ถอด palette.png ออก เพราะ UV ของเมชพื้นฐานกินทั้งแผ่น จะได้แถบสีรุ้งแทนสีเดียว
static func tinted_flat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	m.albedo_color = c
	return m


func _set_stats(stats: Array) -> void:
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.free()
	for s in stats:
		_stats_box.add_child(WQStatBar.from_stat(s))


static func aabb_of(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in all_meshes(node):
		var a: AABB = mi.get_aabb()
		a.position += mi.position
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	if first: box = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	return box


static func all_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D: out.append(node)
	for c in node.get_children(): out.append_array(all_meshes(c))
	return out


## จัดกล้องให้ของทุกขนาดเต็มเฟรมเท่ากัน — พาหนะยาว 4 ม. กับมือถือ 15 ซม. ต้องดูใหญ่พอกัน
func _frame_camera(box: AABB) -> void:
	var center := box.get_center()
	var radius := maxf(0.35, box.size.length() * 0.5)
	var dist := radius / tan(deg_to_rad(FOV * 0.5)) * 1.35
	# look_at_from_position ไม่ใช่ look_at เพราะ world_check เรียกตอนโหนดยังไม่เข้า tree
	# (look_at ต้องการให้โหนดอยู่ใน tree แล้ว ไม่งั้นจะขึ้น error ทั้งที่มุมกล้องคำนวณได้ปกติ)
	_cam.look_at_from_position(
		Vector3(0, center.y + radius * 0.45, dist), Vector3(0, center.y, 0), Vector3.UP)


func _process(dt: float) -> void:
	if _dragging: return
	_spin += SPIN_DEG_PER_SEC * dt
	if _pivot != null: _pivot.rotation_degrees.y = _spin


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (e as InputEventMouseButton).pressed
	elif e is InputEventMouseMotion and _dragging:
		# ลากแล้วหมุนเอง จากนั้นปล่อยให้หมุนอัตโนมัติต่อจากมุมที่ค้างไว้ ไม่ดีดกลับ
		_spin += (e as InputEventMouseMotion).relative.x * DRAG_DEG_PER_PIXEL
		if _pivot != null: _pivot.rotation_degrees.y = _spin


## พื้นหลัง gradient สองสี + กรอบสี่เหลี่ยมมนซ้อนหลัง ตามรูปอ้างอิง ../IMG_3632.jpg
func _draw() -> void:
	# ไล่สีบนลงล่างด้วยรูปสี่เหลี่ยมที่ให้สีต่อมุม ถูกกว่าการเขียน shader และไม่ต้องมีไฟล์เพิ่ม
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0),
			Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([_bg_top, _bg_top, _bg_bot, _bg_bot]))
	# กรอบมนซ้อนหลังของ — จางกว่าพื้นหลังนิดเดียว ให้เป็นฉากหลัง ไม่ใช่ตัวเอก
	# วาดด้วย StyleBoxFlat ไม่ใช่สี่เหลี่ยม+วงกลมซ้อนกัน เพราะสีโปร่งที่ซ้อนกันจะทับกัน
	# สองชั้นตรงมุม แล้วเห็นเป็นวงเข้มๆ สี่มุมชัดเจน
	var w := size.x * 0.62
	var h := size.y * 0.30
	draw_style_box(_frame_box(), Rect2((size.x - w) * 0.5, size.y * 0.08, w, h))


static var _frame_style: StyleBoxFlat

static func _frame_box() -> StyleBoxFlat:
	if _frame_style == null:
		_frame_style = StyleBoxFlat.new()
		_frame_style.bg_color = Color(1, 1, 1, 0.10)
		_frame_style.set_corner_radius_all(18)
	return _frame_style
