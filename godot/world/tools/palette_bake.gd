extends SceneTree
## สร้าง world/materials/palette.png จากค่าใน ui/theme/palette.gd
##   godot --headless --path . --script res://world/tools/palette_bake.gd
##
## รันใหม่ทุกครั้งที่แก้สีใน palette.gd — **ห้ามแก้ palette.png ด้วยมือ**
## เมชทุกชิ้นในเกม map UV มาที่แผ่นนี้ ดังนั้นเปลี่ยนสีที่นี่ = เปลี่ยนทั้งเกม

const OUT := "res://world/materials/palette.png"


func _init() -> void:
	var img := Image.create(WQPalette.TEX_WIDTH, WQPalette.TEX_HEIGHT, false, Image.FORMAT_RGBA8)
	var slot_w := WQPalette.TEX_WIDTH / WQPalette.SLOT_COUNT

	# ช่องที่ยังไม่มีสีทาเป็นชมพูฉูดฉาด เพื่อให้เห็นทันทีถ้าเมชชี้ UV ผิดช่อง
	img.fill(Color.MAGENTA)
	for i in WQPalette.SLOTS.size():
		var c := WQPalette.by_name(WQPalette.SLOTS[i])
		img.fill_rect(Rect2i(i * slot_w, 0, slot_w, WQPalette.TEX_HEIGHT), c)

	var path := ProjectSettings.globalize_path(OUT)
	var err := img.save_png(path)
	if err != OK:
		printerr("palette_bake: เขียน %s ไม่ได้ (error %d)" % [path, err])
		quit(1)
		return
	print("palette_bake: %d ช่องสี (ใช้จริง %d) -> %s" % [
		WQPalette.SLOT_COUNT, WQPalette.SLOTS.size(), OUT])
	quit(0)
