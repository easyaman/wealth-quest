extends SceneTree
## ดัมพ์สถานะรายเดือนของเกมเดียว เพื่อหาว่าพอร์ตเริ่มต่างจาก engine.js ที่เดือนไหน
##   godot --headless --path . --script res://sim/trace_dump.gd -- <job_id> <seed_index>
## จุดถ่ายภาพคือสัญญาณ month_ended ซึ่งตรงกับจุดสิ้นสุด endMonth ของฝั่ง JS
## บรรทัดผลลัพธ์ขึ้นต้นด้วย "T " เสมอ

var _m: WQMatch
var _i := 0

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var job_id: String = argv[0] if argv.size() > 0 else "cleaner"
	var s: int = argv[1].to_int() if argv.size() > 1 else 1
	WQData.load_all()
	WQAi.trace = OS.get_environment("WQ_TRACE_AI") != ""
	_m = WQMatch.new()
	_m.month_ended.connect(_snap)
	_m.setup({"mode": "solo", "seed": s * 7919,
		"players": [{"name": "AI", "job_id": job_id, "is_ai": true}]})
	quit()

func _snap(_month: int) -> void:
	var p = _m.players[0]
	var devs: Array = p.devices.duplicate()
	devs.sort()
	print("T %d rng=%d cash=%d hp=%.1f hmax=%d place=%s veh=%s dev=%s assets=%d nw=%d debt=%d sp=%.2f sal=%d mi=%.4f deals=%d" % [
		_i, _m.rng.s, roundi(p.cash), p.health, p.get_hours_max(), p.place, p.vehicle,
		"|".join(devs), p.assets.size(), roundi(p.get_net_worth()), roundi(p.get_total_debt()),
		p.study_progress, roundi(p.salary), _m.market_index, _m.deals.size()])
	_i += 1
