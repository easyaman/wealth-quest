class_name WQRng
extends RefCounted
## mulberry32 — ต้อง deterministic และ serialize state ได้
## ห้ามเปลี่ยนอัลกอริทึม ไม่งั้นไฟล์เซฟเก่าจะให้ผลต่างจากเดิม

var s: int = 0

func _init(seed_value: int = 12345) -> void:
	s = seed_value & 0xFFFFFFFF

func next() -> float:
	var a := (s + 0x6D2B79F5) & 0xFFFFFFFF
	s = a
	var t := _imul(a ^ (a >> 15), 1 | a)
	t = (t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF
	t = t ^ (t >> 14)
	return float(t & 0xFFFFFFFF) / 4294967296.0

func range_f(lo: float, hi: float) -> float:
	return lo + next() * (hi - lo)

func range_i(n: int) -> int:
	return int(next() * n)

func pick(arr: Array):
	return arr[range_i(arr.size())]

## จำลอง Math.imul ของ JS (คูณ 32-bit signed)
func _imul(a: int, b: int) -> int:
	a = a & 0xFFFFFFFF
	b = b & 0xFFFFFFFF
	var ah := (a >> 16) & 0xFFFF
	var al := a & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	return ((al * bl) + ((((ah * bl) + (al * bh)) << 16) & 0xFFFFFFFF)) & 0xFFFFFFFF
