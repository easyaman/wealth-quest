class_name WQMatch
extends RefCounted
## ตลาดกลาง + ลำดับตา + ปฏิทิน + ภัยพิบัติ
## Match คือ single source of truth — ตอนทำ online ให้ย้ายคลาสนี้ไปรันบนเซิร์ฟเวอร์

signal month_ended(month: int)
signal disaster_started(def: Dictionary)
signal player_finished(p)
signal champion_added(entry: Dictionary)
signal match_over

const MAX_MONTHS := 600

var mode := "solo"
var rng: WQRng
var month := 1
var market_index := 1.0
var market_trend := 0.0
var deal_id_seq := 1
var deals: Array = []
var logs: Array = []
var state := "playing"
var active_disasters: Array = []
var disaster_cooldown := 12
var disaster_history: Array = []
var champions: Array = []
var players: Array = []
var start_index := 0
var turn := 0


func setup(opts: Dictionary) -> void:
	WQData.load_all()
	mode = opts.get("mode", "solo")
	rng = WQRng.new(opts.get("seed", 12345))
	disaster_cooldown = int(WQData.cfg.disaster_min) - 1 + rng.range_i(int(WQData.cfg.disaster_max) - int(WQData.cfg.disaster_min) + 2)
	for po in opts.players:
		var p := WQPlayer.new()
		p.setup(self, po)
		players.append(p)
	refill_market()
	begin_month()

# ========== ตัวคูณจากภัยพิบัติ ==========
func get_mods() -> Dictionary:
	var m := {"business": 1.0, "realestate": 1.0, "rate": 1.0, "credit": 1.0}
	for d in active_disasters:
		var x: Dictionary = d.def.get("mods", {})
		for k in m.keys():
			if x.has(k): m[k] *= float(x[k])
	return m

func log_line(text: String, kind := "info", who = null) -> void:
	logs.push_front({"month": month, "text": text, "kind": kind,
		"who": (who.pname if who != null else "")})
	if logs.size() > 140: logs.pop_back()

func find_deal(id: int) -> int:
	for i in deals.size():
		if deals[i].id == id: return i
	return -1

# ========== ลำดับตา ==========
func get_order() -> Array:
	var o: Array = []
	for i in players.size():
		o.append(players[(start_index + i) % players.size()])
	return o

func get_current():
	var o := get_order()
	return o[turn] if turn < o.size() else null

func begin_month() -> void:
	turn = 0
	run_ai_turns()

func run_ai_turns() -> void:
	while state == "playing" and turn < players.size():
		var p = get_current()
		if p.is_ai:
			if not p.bankrupt and p.phase < 3: WQAi.take_turn(p)
			turn += 1
		elif p.bankrupt or p.phase == 3:
			turn += 1
		else:
			break
	if turn >= players.size(): end_month()

func end_turn() -> void:
	if state != "playing": return
	get_current().hours = 0
	turn += 1
	run_ai_turns()

func add_champion(p) -> void:
	var entry := {"name": p.pname, "icon": p.job.icon, "job": p.job.name,
		"dream": p.dream.name, "dream_icon": p.dream.icon, "month": p.dream_done,
		"is_ai": p.is_ai, "rank": champions.size() + 1}
	champions.append(entry)
	log_line("👑 อันดับ %d — %s ทำความฝันสำเร็จในเดือนที่ %d!" % [entry.rank, p.pname, p.dream_done], "win", null)
	champion_added.emit(entry)
	player_finished.emit(p)

# ========== ภัยพิบัติ ==========
func tick_disasters() -> void:
	for i in range(active_disasters.size() - 1, -1, -1):
		active_disasters[i].left -= 1
		if active_disasters[i].left <= 0:
			var d = active_disasters[i]
			active_disasters.remove_at(i)
			log_line("%s สถานการณ์ \"%s\" คลี่คลายแล้ว" % [d.def.icon, d.def.name], "good", null)

	disaster_cooldown -= 1
	if disaster_cooldown > 0: return
	disaster_cooldown = int(WQData.cfg.disaster_min) + rng.range_i(int(WQData.cfg.disaster_max) - int(WQData.cfg.disaster_min) + 1)

	var def: Dictionary = WQData.disasters[rng.range_i(WQData.disasters.size())]
	active_disasters.append({"def": def, "left": int(def.dur)})
	disaster_history.append({"month": month, "id": def.id, "name": def.name, "icon": def.icon})
	log_line("⛔ ภัยพิบัติ: %s %s — %s (มีผล %d เดือน)" % [def.icon, def.name, def.desc, int(def.dur)], "disaster", null)
	disaster_started.emit(def)

	if def.has("market"):
		market_index = clampf(market_index * (1.0 + float(def.market)), 0.5, 1.9)
	for p in players:
		if p.bankrupt or p.phase == 3: continue
		if def.has("hp"): p.health = clampf(p.health + float(def.hp), 0, 100)
		if def.has("inflate"):
			p.fixed_expenses = round(p.fixed_expenses * (1.0 + float(def.inflate)))
			p.food_base = round(p.food_base * (1.0 + float(def.inflate)))
		if def.has("cashCostMul"):
			var frugal := 0.6 if p.job.perkId == "frugal" else 1.0
			var c := round(p.get_total_expenses() * rng.range_f(def.cashCostMul[0], def.cashCostMul[1]) * frugal)
			p.cash -= c
			log_line("%s ผลกระทบจาก%s −%d บาท" % [def.icon, def.name, int(c)], "bad", p)
		if def.get("burnAsset", false):
			var targets: Array = []
			for a in p.assets:
				if (a.kind == "business" or a.kind == "micro") and a.burned == 0: targets.append(a)
			if targets.size() > 0 and rng.next() < 0.5:
				var a = targets[rng.range_i(targets.size())]
				a.burned = 4
				log_line("🔥 %s %s ถูกไฟไหม้! ไม่มีรายได้ 4 เดือน" % [a.icon, a.name], "bad", p)

# ========== ตลาด ==========
func pick_template(pool: Array, max_down: float) -> Dictionary:
	var cand: Array = pool
	if max_down > 0:
		cand = []
		for t in pool:
			if float(t.min) * float(t.downPct[0]) <= max_down: cand.append(t)
		if cand.is_empty(): cand = pool
	var total := 0.0
	for t in cand: total += float(t.get("w", 1))
	var x := rng.next() * total
	for t in cand:
		x -= float(t.get("w", 1))
		if x <= 0: return t
	return cand[cand.size() - 1]

func make_deal(force_big := false, max_down := 0.0) -> Dictionary:
	var richest := 0.0
	var any_phase2 := false
	for p in players:
		richest = maxf(richest, p.get_net_worth())
		if p.phase >= 2: any_phase2 = true
	var mg := float(WQData.cfg.mortgage)

	if max_down <= 0 and any_phase2 and rng.next() < 0.38:
		var t: Dictionary = WQData.mega_deals[rng.range_i(WQData.mega_deals.size())]
		var price := maxf(1000000.0, round(richest * (0.15 + rng.next() * 0.5) / 100000.0) * 100000.0)
		var dp := rng.range_f(t.downPct[0], t.downPct[1])
		var down := round(price * dp)
		var income := round(price * rng.range_f(t.yield[0], t.yield[1]))
		return _deal(t, price, down, price - down, income, true, true)

	var big := force_big or (max_down <= 0 and richest > 4000000.0 and rng.next() < 0.30)
	var pool: Array = WQData.big_deals if big else WQData.deal_pool
	var t2 := pick_template(pool, max_down)
	var step := 100000.0 if float(t2.min) >= 1000000 else (10000.0 if float(t2.min) >= 100000 else 1000.0)
	var hi := float(t2.max)
	if max_down > 0: hi = minf(hi, maxf(float(t2.min), max_down / float(t2.downPct[0])))
	var price2 := round(rng.range_f(float(t2.min), hi) / step) * step
	var down2 := round(price2 * rng.range_f(t2.downPct[0], t2.downPct[1]))
	var income2 := round(price2 * rng.range_f(t2.yield[0], t2.yield[1]))
	return _deal(t2, price2, down2, price2 - down2, income2, big, false)

func _deal(t: Dictionary, price: float, down: float, debt: float, income: float, big: bool, mega: bool) -> Dictionary:
	var d := {"id": deal_id_seq, "kind": t.kind, "icon": t.icon,
		"name": t.names[rng.range_i(t.names.size())],
		"price": price, "down": down, "debt": debt, "income": income,
		"cashflow": round(income - debt * float(WQData.cfg.mortgage)),
		"vol": t.vol, "ttl": 2 + rng.range_i(3), "big": big, "mega": mega}
	deal_id_seq += 1
	return d

func refill_market() -> void:
	var target := 4 + players.size()
	while deals.size() < target: deals.append(make_deal())
	var alive: Array = []
	for p in players:
		if not p.bankrupt and p.phase < 3: alive.append(p)
	if alive.is_empty(): return
	var poorest := 1e18
	for p in alive: poorest = minf(poorest, p.cash)
	poorest = maxf(30000.0, poorest)
	var guard := 0
	while _count_cheap(poorest) < 2 and guard < 6:
		guard += 1
		if deals.size() >= target + 2: deals.remove_at(0)
		deals.append(make_deal(false, poorest))

func _count_cheap(limit: float) -> int:
	var n := 0
	for d in deals:
		if d.down <= limit: n += 1
	return n

# ========== สิ้นเดือน ==========
func end_month() -> void:
	if month >= MAX_MONTHS: state = "over"; match_over.emit(); return
	market_trend = market_trend * 0.6 + (rng.next() - 0.5) * 0.04
	market_index = clampf(market_index * (1.0 + market_trend), 0.55, 1.9)

	tick_disasters()
	for p in players:
		if not p.bankrupt and p.phase < 3: p.settle()

	for i in range(deals.size() - 1, -1, -1):
		deals[i].ttl -= 1
		if deals[i].ttl <= 0: deals.remove_at(i)
	refill_market()
	month_ended.emit(month)

	# เกมจบเมื่อ "คนจริง" ทุกคนจบ — บอทชนะไม่ทำให้เกมจบ
	var humans: Array = []
	for p in players:
		if not p.is_ai: humans.append(p)
	var watch: Array = humans if humans.size() > 0 else players
	var still := 0
	for p in watch:
		if not p.bankrupt and p.phase < 3: still += 1
	if still == 0:
		state = "over"; match_over.emit(); return

	month += 1
	start_index = (start_index + 1) % players.size()
	begin_month()

func standings() -> Array:
	var arr := players.duplicate()
	arr.sort_custom(func(a, b):
		if a.dream_done > 0 and b.dream_done > 0: return a.dream_done < b.dream_done
		if a.dream_done > 0: return true
		if b.dream_done > 0: return false
		if a.phase != b.phase: return a.phase > b.phase
		return a.get_freedom_pct() > b.get_freedom_pct())
	return arr
