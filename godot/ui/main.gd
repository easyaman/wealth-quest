extends Control
## โครง UI ชั่วคราว — พิสูจน์ว่า core ทำงานใน Godot ได้จริง
## งานถัดไป: แทนที่ด้วย widget จริงตามเลย์เอาต์ในบทที่ 12 ของ GDD

@onready var log_label: RichTextLabel = $Log
var m: WQMatch

func _ready() -> void:
	WQData.load_all()
	m = WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
		{"name": "บอท B", "job_id": "pilot", "is_ai": true},
	]})
	m.month_ended.connect(func(_mo): _refresh())
	_refresh()

func _refresh() -> void:
	var p = m.get_current()
	if p == null: return
	var s := "[b]เดือนที่ %d[/b]  |  %s %s\n" % [m.month, p.job.icon, p.pname]
	s += "เงินสด %d  ·  สุทธิ %d  ·  ⏳ %d/%d ชม.  ·  ❤️ %d\n" % [
		int(p.cash), int(p.get_net_worth()), p.hours, p.get_hours_max(), int(p.health)]
	s += "รายได้จากทรัพย์สิน %d / รายจ่าย %d  (%.0f%%)\n\n" % [
		int(p.get_passive_income()), int(p.get_total_expenses()), p.get_freedom_pct()]
	s += "[b]ตลาดดีล[/b]\n"
	for d in m.deals:
		s += "  %s %s — ดาวน์ %d · %+d/เดือน\n" % [d.icon, d.name, int(d.down), int(d.cashflow)]
	s += "\n[b]บันทึก[/b]\n"
	for i in mini(12, m.logs.size()):
		s += "  [%d] %s\n" % [m.logs[i].month, m.logs[i].text]
	log_label.text = s

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		m.end_turn()   # กด Space = จบตา (ชั่วคราว)
		_refresh()
