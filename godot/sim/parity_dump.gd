extends SceneTree
## ดัมพ์ผลรายเมล็ดสุ่มเพื่อเทียบกับเอนจิน JS ทีละเกม
##   godot --headless --path . --script res://sim/parity_dump.gd -- 60
## ใช้เมล็ดชุดเดียวกับ tools/parity_dump.js และ headless_sim.gd (s * 7919)
## บรรทัดผลลัพธ์ขึ้นต้นด้วย "ROW " เสมอ เพื่อกรอง log ของ Godot ออกได้ง่าย

func _init() -> void:
	var runs := 60
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int(): runs = a.to_int()
	WQData.load_all()
	for job in WQData.jobs:
		for s in range(1, runs + 1):
			var m := WQMatch.new()
			m.setup({"mode": "solo", "seed": s * 7919,
				"players": [{"name": "AI", "job_id": job.id, "is_ai": true}]})
			var p = m.players[0]
			var devs: Array = p.devices.duplicate()
			devs.sort()
			print("ROW %s %d %d %d %d %d %d %d %d %s %s %d" % [
				job.id, s, p.finished, p.dream_done, 1 if p.bankrupt else 0, m.month,
				roundi(p.health), roundi(p.get_net_worth()), p.assets.size(),
				p.vehicle, "|".join(devs), p.study_level])
	quit()
