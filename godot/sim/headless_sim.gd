extends SceneTree
## เครื่องมือทดสอบสมดุล — รันด้วย:
##   godot --headless --script res://sim/headless_sim.gd
## ต้องรันทุกครั้งที่แก้ตัวเลขใน res://data/*.json
## เกณฑ์ผ่าน: ผู้ชนะควรใช้เวลามัธยฐาน 40–60 เดือน และไม่มีอาชีพไหนชนะ 0% หรือ 100%

const RUNS := 60   # เพิ่มเป็น 250 เมื่อจะปรับสมดุลจริง

func _init() -> void:
	WQData.load_all()
	print("=== WEALTH QUEST — headless balance sim (%d เกม/อาชีพ) ===" % RUNS)
	print("อาชีพ".rpad(28), "| ชม.ว่าง | ออกสนามหนู | เดือน | ทำฝัน% | เดือนฝัน | ล้มละลาย%")
	var all_dreams: Array = []
	for job in WQData.jobs:
		var esc: Array = []
		var dr: Array = []
		var bank := 0
		for s in range(1, RUNS + 1):
			var m := WQMatch.new()
			m.setup({"mode": "solo", "seed": s * 7919,
				"players": [{"name": "AI", "job_id": job.id, "is_ai": true}]})
			var p = m.players[0]
			if p.finished > 0: esc.append(p.finished)
			if p.dream_done > 0: dr.append(p.dream_done); all_dreams.append(p.dream_done)
			if p.bankrupt: bank += 1
		var free := WQMatch.new()
		print("%s | %7d | %9d%% | %5s | %5d%% | %8s | %8d%%" % [
			(job.icon + " " + job.name).rpad(26),
			_free_hours(job),
			roundi(float(esc.size()) / RUNS * 100.0), _avg(esc),
			roundi(float(dr.size()) / RUNS * 100.0), _avg(dr),
			roundi(float(bank) / RUNS * 100.0)])
	all_dreams.sort()
	if all_dreams.size() > 0:
		print("\nมัธยฐานเวลาทำความฝันสำเร็จ: %d เดือน (เร็วสุด %d, ช้าสุด %d)" %
			[all_dreams[all_dreams.size() / 2], all_dreams[0], all_dreams[-1]])
		var med: int = all_dreams[all_dreams.size() / 2]
		print("เกณฑ์ 40–60 เดือน: %s" % ("ผ่าน ✅" if med >= 40 and med <= 60 else "ไม่ผ่าน ❌ — ปรับ yield ใน data/deals.json"))
	quit()

func _free_hours(job: Dictionary) -> int:
	var sleep := int(job.get("sleepNeed", 7)) * 30
	var raw: int = int(WQData.cfg.hours_per_month) - sleep - int(job.work) - int(job.commute) - 30 - int(WQData.cfg.chores_hours)
	return roundi(raw * (0.40 + 0.60 * float(job.health) / 100.0))

func _avg(a: Array) -> String:
	if a.is_empty(): return "—"
	var t := 0.0
	for x in a: t += x
	return "%.1f" % (t / a.size())
