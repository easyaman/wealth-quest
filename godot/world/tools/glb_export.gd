extends SceneTree
## อบเมชต่อกล่องออกเป็นไฟล์ `.glb` จริง — ไม่ต้องใช้ Blender
##   godot --headless --path . --script res://world/tools/glb_export.gd
##   godot --headless --path . --script res://world/tools/glb_export.gd -- places/home props/tree
##   WQ_GLB_FORCE=1 ...        เขียนทับไฟล์ที่อบไว้ก่อนหน้าแม้เนื้อหาไม่เปลี่ยน
##
## **ไฟล์ที่ออกมาไม่ใช่งานปั้นมือ** — มันคือเมชชุดเดียวกับที่ `WQKitbash*` สร้างจากโค้ด
## แค่ย้ายจาก "สร้างตอนรัน" มาเป็น "ไฟล์จริงบนดิสก์" ตามที่ ART-DIRECTION วางท่อไว้
## ประโยชน์ที่ได้จริงคือท่อส่งงานเดินได้ครบวง: อบ → นำเข้า → ตรวจ → เห็นในเกม
## คนปั้นจึงเอา `.glb` ของตัวเองมาวางทับทีละชิ้นได้เลย โดยไม่ต้องรอให้ครบ 38 ชิ้นก่อน
##
## ทุกไฟล์ที่อบจากที่นี่ถูกประทับไว้ที่ช่อง `copyright` ของ glTF (ดู BAKED_MARK)
## เพื่อให้ `WQModelIds.source_of()` แยกออกว่าชิ้นไหน "อบจากโค้ด" ชิ้นไหน "คนปั้นมาจริง"
## แล้วเช็กลิสต์ใน world/models/README.md จะได้ไม่โกหกว่างานอาร์ตเสร็จแล้ว
##
## **ตัวอบจะไม่แตะไฟล์ที่ไม่มีตราประทับเด็ดขาด** — ของที่คนปั้นมาต้องไม่ถูกเขียนทับ

const BAKED_MARK := WQModelIds.BAKED_MARK   ## ตราประทับอยู่ที่ WQModelIds ที่เดียว
const MODEL_DIR := "res://world/models"
const FLAT_MAT := "res://world/materials/flat.tres"

var _written := 0
var _skipped_human := 0
var _skipped_same := 0
var _fails := 0


func _init() -> void:
	WQData.load_all()
	var only := _wanted()
	var force := OS.get_environment("WQ_GLB_FORCE") != ""
	print("=== glb_export%s ===" % ("" if only.is_empty() else " (เฉพาะ %d ชิ้น)" % only.size()))

	for it in WQModelIds.all():
		var kind := String(it.kind)
		var id := String(it.id)
		if not only.is_empty() and not only.has("%s/%s" % [kind, id]): continue
		# ไม่มีเมชต่อกล่องของชิ้นนี้ = ยังไม่มีอะไรให้อบ ต้องรอคนปั้น
		if not WQKitbash.has(kind, id): continue
		_bake(kind, id, force)

	print("glb_export: เขียน %d ชิ้น · ข้ามของที่คนปั้น %d · ไม่เปลี่ยน %d%s" % [
		_written, _skipped_human, _skipped_same,
		"" if _fails == 0 else " · ล้มเหลว %d ❌" % _fails])
	if _written > 0:
		print("  อย่าลืม: godot --headless --path . --import   แล้วรัน model_lint กับ world_check")
	quit(1 if _fails > 0 else 0)


func _wanted() -> Array:
	var out: Array = []
	for a in OS.get_cmdline_user_args(): out.append(String(a))
	return out


func _bake(kind: String, id: String, force: bool) -> void:
	var path := "%s/%s/%s.glb" % [MODEL_DIR, kind, id]
	var abs := ProjectSettings.globalize_path(path)

	if FileAccess.file_exists(abs) and not _is_baked(abs):
		_skipped_human += 1
		print("  🙌 %s/%s — มีของที่คนปั้นอยู่แล้ว ไม่แตะ" % [kind, id])
		return

	var mesh_node := WQKitbash.build(kind, id)
	if mesh_node == null:
		_fails += 1
		print("  ❌ %s/%s — ต่อกล่องไม่ออก" % [kind, id])
		return
	# ชื่อโหนดรากต้องเป็น id เป๊ะ เพราะ model_lint ตรวจชื่อรากของฉากที่โหลดกลับมา
	mesh_node.name = id
	mesh_node.material_override = _export_material()

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.copyright = BAKED_MARK
	var err := doc.append_from_scene(mesh_node, state)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
		err = doc.write_to_filesystem(state, abs)
	mesh_node.free()

	if err != OK:
		_fails += 1
		print("  ❌ %s/%s — เขียนไฟล์ไม่ได้ (error %d)" % [kind, id, err])
		return
	_written += 1
	print("  ✅ %s/%s -> %s" % [kind, id, path])


## วัสดุที่ใส่ลงไฟล์ = flat.tres แต่ **ถอดแผ่น palette ออก**
##
## ถ้าฝัง palette.png ลงไปในไฟล์ ตัวนำเข้าของ Godot จะแกะมันออกมาเป็น `<id>_palette.png`
## ข้างๆ ไฟล์โมเดลทุกชิ้น กลายเป็นไฟล์งอก 42 ไฟล์ในโฟลเดอร์ที่คนปั้นต้องเข้ามาทำงาน
## และแย่กว่านั้นคือ palette ถูกก๊อปไป 21 ชุด — แก้สีที่ `ui/theme/palette.gd` แล้วโมเดลจะไม่เปลี่ยนตาม
## ซึ่งพังกติกาข้อที่ทั้งเกมยืนอยู่ (ART-DIRECTION 2.1: เปลี่ยนสีทั้งเกมได้จากไฟล์เดียว)
##
## ไฟล์จึงเก็บแค่ "UV ชี้ไปช่องที่เท่าไหร่" ส่วนแผ่นสีจริงมาตอนโหลดเข้าเกม
## (`WQShowcase.model_for()` เป็นคนสวม flat.tres ให้ทุกโมเดลที่โหลดจาก .glb)
## คนปั้นที่เปิดไฟล์ใน Blender ให้แปะ `world/materials/palette.png` เอง ตามสเปกใน README
static func _export_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = (load(FLAT_MAT) as StandardMaterial3D).duplicate()
	m.albedo_texture = null
	m.resource_name = "flat"
	return m


## ไฟล์นี้อบมาจากโค้ดหรือคนปั้นมา — ดูจากตราประทับในช่อง copyright ของ glTF
static func _is_baked(abs_path: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK: return false
	return state.copyright == BAKED_MARK
