extends SceneTree
## ตรวจโมเดลทุกชิ้นก่อนเอาเข้าเกม — headless
##   godot --headless --path . --script res://world/tools/model_lint.gd
##
## ตรวจตามเช็กลิสต์ก่อน export ใน ART-DIRECTION ข้อ 5.4:
##   origin ที่ฐาน · flat shade · วัสดุเดียวชื่อ flat · tris ไม่เกิน budget · ชื่อ = id
##
## ตรวจทั้ง `.glb` จริงและเมชต่อกล่องจาก WQKitbash ด้วยเกณฑ์เดียวกัน
## เพราะเมชต่อกล่องคือของที่ผู้เล่นเห็นจริงตอนนี้ ถ้าไม่ตรวจก็เท่ากับไม่ได้ตรวจอะไรเลย

const BASE_TOLERANCE := 0.01     ## ฐานโมเดลต้องอยู่ที่ y=0 ±1 ซม.

var _fails := 0
var _warns := 0
var _checked := 0


func _init() -> void:
	WQData.load_all()
	print("=== model_lint ===")
	for it in WQModelIds.all():
		_lint(String(it.kind), String(it.id))
	print("model_lint: ตรวจ %d ชิ้น · %s%s" % [_checked,
		"ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ชิ้น ❌" % _fails,
		"" if _warns == 0 else "  (ข้อสังเกต %d ข้อ)" % _warns])
	quit(1 if _fails > 0 else 0)


func _lint(kind: String, id: String) -> void:
	var src := WQModelIds.source_of(kind, id)
	if src == "": return                   # ยังไม่มีของชิ้นนี้ — ไม่ใช่ความผิด ดู world/models/README.md
	if not WQModelIds.BUDGET.has(kind):
		_fail(kind, id, "ไม่ได้ตั้งงบสามเหลี่ยมของกลุ่มนี้ไว้ใน model_lint")
		return

	var node := WQShowcase.model_for(kind, id)
	if node == null:
		_fail(kind, id, "โหลดโมเดลไม่ได้")
		return
	_checked += 1

	# 1. ชื่อโหนดต้องตรงกับ id ใน data — โค้ดโหลดโมเดลจาก id ตรงๆ ไม่มีตารางแปลงชื่อ
	if node.name != id:
		_fail(kind, id, "ชื่อโหนดเป็น \"%s\" ต้องเป็น \"%s\"" % [node.name, id])

	var meshes := WQShowcase.all_meshes(node)
	if meshes.is_empty():
		_fail(kind, id, "ไม่มีเมชอยู่ในโมเดลเลย")
		return

	# 2. งบสามเหลี่ยม — เกินเพดานคือผิด ต่ำกว่าพื้นเป็นแค่ข้อสังเกต (ประหยัดกว่าไม่ผิด)
	var tris := 0
	for mi in meshes: tris += _tris_of(mi)
	var budget: Array = WQModelIds.BUDGET[kind]
	if tris > int(budget[1]):
		_fail(kind, id, "%d tris เกินเพดาน %d" % [tris, budget[1]])
	elif tris < int(budget[0]):
		_warn(kind, id, "%d tris ต่ำกว่าช่วงที่วางไว้ (%d) — ไม่ผิด แต่จะดูเรียบกว่าที่ตั้งใจ" % [
			tris, budget[0]])

	# 3. วัสดุเดียวทั้งชิ้น — หลายวัสดุ = หลาย draw call และหลุดสไตล์ palette แผ่นเดียว
	var mats := {}
	for mi in meshes:
		var m: Material = mi.material_override
		if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		mats[m.resource_path if m != null and m.resource_path != "" else str(m)] = true
	if mats.size() != 1:
		_fail(kind, id, "มี %d วัสดุ ต้องมีวัสดุเดียว (%s)" % [mats.size(), ", ".join(mats.keys())])

	# 4. origin ที่ฐาน — ถ้าฐานไม่อยู่ที่ y=0 ของจะลอยหรือจมพื้นตอนวางลงฉากเมือง
	var box := WQShowcase.aabb_of(node)
	if absf(box.position.y) > BASE_TOLERANCE:
		_fail(kind, id, "ฐานอยู่ที่ y=%.3f ต้องเป็น 0 (origin ต้องอยู่ที่ฐาน)" % box.position.y)

	print("  %-9s %-12s %-8s %4d tris  สูง %.2f ม." % [kind, id, src, tris, box.size.y])
	node.free()


func _tris_of(mi: MeshInstance3D) -> int:
	var mesh := mi.mesh
	if mesh == null: return 0
	var n := 0
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		# เมชที่สร้างจาก SurfaceTool โดยไม่ index จะไม่มี ARRAY_INDEX เลย (เป็น null ไม่ใช่ array ว่าง)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _fail(kind: String, id: String, msg: String) -> void:
	_fails += 1
	print("  ❌ %s/%s: %s" % [kind, id, msg])


func _warn(kind: String, id: String, msg: String) -> void:
	_warns += 1
	print("  ⚠ %s/%s: %s" % [kind, id, msg])
