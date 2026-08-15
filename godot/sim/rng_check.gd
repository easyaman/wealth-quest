extends SceneTree
func _init():
	var r := WQRng.new(12345)
	var want := [0.9797282677609473, 0.3067522644996643, 0.4842054215259850,
	             0.8179344125092030, 0.5094283693470061]
	var ok := true
	print("=== ทดสอบตัวสุ่ม WQRng.new(12345) เทียบกับ makeRng ของ JS ===")
	for i in 5:
		var got := r.next()
		var same: bool = abs(got - want[i]) < 1e-15
		if not same: ok = false
		print("  %d: ได้ %.16f | ต้องการ %.16f | %s" % [i+1, got, want[i], "ตรง" if same else "ไม่ตรง ❌"])
	print("ผลรวม: ", "✅ ตัวสุ่มตรงกับ JS เป๊ะ" if ok else "❌ ตัวสุ่มไม่ตรง — ต้องแก้ _imul ก่อนทำอย่างอื่น")
	quit(0 if ok else 1)
