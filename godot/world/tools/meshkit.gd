class_name WQMeshKit
extends RefCounted
## ตัวต่อพื้นฐานของเมชที่สร้างจากโค้ด — กล่อง · ปริซึม · ทรงกระบอก
##
## แยกออกมาจาก world/tools/kitbash.gd ตอน Sprint C เพราะอาคารกับ prop ในฉากเมือง
## ต้องใช้ตัวต่อชุดเดียวกับพาหนะเป๊ะ ถ้าก๊อปไปไว้สองที่ วันที่แก้สูตร UV จะแก้ไม่ครบ
##
## กติกาที่ทุกตัวต่อในไฟล์นี้รักษาไว้ให้ (ART-DIRECTION 2.1):
##   · ทุกหน้าได้ normal ของตัวเอง = flat shading จริง ไม่มีการเกลี่ยข้ามหน้า
##   · UV ทุกจุดชี้ไป "กลางช่องสี" บนแผ่น palette.png ไม่ใช่ขอบช่อง
##     (ขอบจะเพี้ยนเมื่อมี mipmap หรือ filter — เห็นเป็นเส้นสีแปลกปลอมตามขอบเมช)
##   · ไม่มีการตั้ง albedo_color รายชิ้น — สีมาจากช่องบน palette ทั้งหมด

const FLAT_MAT := "res://world/materials/flat.tres"


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## ปิดงานเป็น MeshInstance3D ที่ผ่านกฎ "วัสดุเดียวชื่อ flat" ของ model_lint
static func finish(st: SurfaceTool, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = load(FLAT_MAT)
	return mi


static func uv(slot: StringName) -> Vector2:
	return Vector2(WQPalette.slot_u(slot), 0.5)


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, slot: StringName) -> void:
	var n := (b - a).cross(c - a).normalized()
	var t := uv(slot)
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(t)
		st.add_vertex(v)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		slot: StringName) -> void:
	tri(st, a, b, c, slot)
	tri(st, a, c, d, slot)


static func box(st: SurfaceTool, center: Vector3, size: Vector3, slot: StringName) -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(center + Vector3(
			h.x if (i & 1) else -h.x,
			h.y if (i & 2) else -h.y,
			h.z if (i & 4) else -h.z))
	quad(st, p[4], p[5], p[7], p[6], slot)   # +Z
	quad(st, p[1], p[0], p[2], p[3], slot)   # −Z
	quad(st, p[5], p[1], p[3], p[7], slot)   # +X
	quad(st, p[0], p[4], p[6], p[2], slot)   # −X
	quad(st, p[2], p[6], p[7], p[3], slot)   # +Y
	quad(st, p[0], p[1], p[5], p[4], slot)   # −Y


## กล่องที่ด้านบนแคบกว่าด้านล่าง — ใช้ทำหลังคาลาด ยอดตึก และพุ่มไม้
## top_scale = 0 คือปลายแหลมเป็นพีระมิด
static func taper(st: SurfaceTool, base_center: Vector3, size: Vector3, height: float,
		top_scale: float, slot: StringName) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var tx := hx * top_scale
	var tz := hz * top_scale
	var y0 := base_center.y
	var y1 := base_center.y + height
	var b := [
		base_center + Vector3(-hx, 0, -hz), base_center + Vector3(hx, 0, -hz),
		base_center + Vector3(hx, 0, hz), base_center + Vector3(-hx, 0, hz)]
	var t := [
		Vector3(base_center.x - tx, y1, base_center.z - tz),
		Vector3(base_center.x + tx, y1, base_center.z - tz),
		Vector3(base_center.x + tx, y1, base_center.z + tz),
		Vector3(base_center.x - tx, y1, base_center.z + tz)]
	for i in 4:
		var j := (i + 1) % 4
		if top_scale <= 0.001:
			tri(st, b[i], b[j], t[0], slot)
		else:
			quad(st, b[i], b[j], t[j], t[i], slot)
	if top_scale > 0.001:
		quad(st, t[0], t[1], t[2], t[3], slot)
	quad(st, b[3], b[2], b[1], b[0], slot)
	# y0 ถูกใช้ผ่าน b[] แล้ว — เก็บไว้ให้อ่านง่ายว่าฐานอยู่ระดับไหน
	assert(y0 <= y1)


## ทรงกระบอกแกนนอนตาม X — ล้อรถ
static func cylinder_x(st: SurfaceTool, center: Vector3, r: float, half_w: float,
		segments: int, slot: StringName) -> void:
	var ring := _ring(r, segments)
	for i in segments:
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % segments]
		var a0 := center + Vector3(-half_w, p0.y, p0.x)
		var b0 := center + Vector3(half_w, p0.y, p0.x)
		var a1 := center + Vector3(-half_w, p1.y, p1.x)
		var b1 := center + Vector3(half_w, p1.y, p1.x)
		quad(st, a0, b0, b1, a1, slot)
		tri(st, center + Vector3(half_w, 0, 0), b0, b1, slot)
		tri(st, center + Vector3(-half_w, 0, 0), a1, a0, slot)


## ทรงกระบอกแกนตั้งตาม Y (ฐานอยู่ที่ base.y) — เสาไฟ ลำต้นไม้ เสาอาคาร
static func cylinder_y(st: SurfaceTool, base: Vector3, r: float, h: float,
		segments: int, slot: StringName) -> void:
	var ring := _ring(r, segments)
	var top := base + Vector3(0, h, 0)
	for i in segments:
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % segments]
		var a0 := base + Vector3(p0.x, 0, p0.y)
		var a1 := base + Vector3(p1.x, 0, p1.y)
		quad(st, a0, a1, a1 + Vector3(0, h, 0), a0 + Vector3(0, h, 0), slot)
		tri(st, top, a0 + Vector3(0, h, 0), a1 + Vector3(0, h, 0), slot)
		tri(st, base, a1, a0, slot)


## วงหลายเหลี่ยมที่เลื่อนเฟสครึ่งช่อง ให้มีจุดยอดแตะจุดต่ำสุดของวงพอดี
## (ถ้าไม่เลื่อน ล้อ/เสาจะลอยเหนือพื้นราว 5% ของรัศมี แล้ว model_lint จะจับได้ว่าฐานไม่อยู่ที่ y=0)
static func _ring(r: float, segments: int) -> Array[Vector2]:
	var ring: Array[Vector2] = []
	for i in segments:
		var a := TAU * (float(i) + 0.5) / float(segments)
		ring.append(Vector2(cos(a) * r, sin(a) * r))
	return ring
