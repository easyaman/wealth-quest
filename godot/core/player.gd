class_name WQPlayer
extends RefCounted
## ผู้เล่นหนึ่งคน — ถือ งบการเงิน + งบเวลา + สุขภาพ
## กฎเหล็ก: ไฟล์นี้ห้าม reference อะไรใน ui/ หรือ world/ เด็ดขาด

signal changed

var match_ref: WQMatch             # Godot 4 ผูก class_name ผ่าน global class cache จึงประกาศ type ตรงๆ ได้
var pname: String = ""
var is_ai := false
var job: Dictionary = {}
var roll := 0
var bonus_hours := 0

# --- เงิน ---
var cash := 0.0
var salary := 0.0
var fixed_expenses := 0.0
var food_base := 0.0
var child_cost := 0.0
var assets: Array = []
var liabilities: Array = []

# --- เวลา & สุขภาพ ---
var child_hours := 0
var sleep_idx := 2
var food_id := "street"
var health := 70.0
var time_penalty := 0
var hours := 0
var side_used := 0
var rested_this_month := false

# --- การเรียน ---
var study_level := 0
var study_progress := 0.0

# --- สถานะ ---
var downsize_left := 0
var bankrupt := false
var finished := 0
var phase := 1
var dream: Dictionary = {}
var dream_done := 0
var retired := false
var pending_dream := false
var history: Array = []


func setup(m, opts: Dictionary) -> void:
	match_ref = m
	pname = opts.get("name", "ผู้เล่น")
	is_ai = opts.get("is_ai", false)
	job = WQData.job(opts.get("job_id", "teacher"))
	roll = opts.get("roll", 0)
	bonus_hours = opts.get("bonus_hours", 0)
	cash = job.cash
	salary = job.salary
	fixed_expenses = job.fixed
	food_base = job.food
	health = job.health
	for d in job.debts:
		liabilities.append(d.duplicate(true))
	hours = get_hours_max()

# ========== ไลฟ์สไตล์ ==========
func sleep_opt() -> Dictionary: return WQData.cfg.sleep_options[sleep_idx]

func food_opt() -> Dictionary:
	for f in WQData.cfg.food_options:
		if f.id == food_id: return f
	return WQData.cfg.food_options[1]

func set_sleep(i: int) -> void:
	sleep_idx = clampi(i, 0, WQData.cfg.sleep_options.size() - 1)
	hours = mini(hours, get_hours_max()); changed.emit()

func set_food(id: String) -> void:
	food_id = id
	hours = mini(hours, get_hours_max()); changed.emit()

# ========== เวลา ==========
func get_sleep_need() -> int:
	return 7 if retired else int(job.get("sleepNeed", 7))

func get_sleep_debt() -> int:
	return maxi(0, get_sleep_need() - int(sleep_opt().h))

func get_work_hours() -> int:
	return 0 if (retired or downsize_left > 0) else int(job.work)

func get_commute_hours() -> int:
	return 0 if (retired or downsize_left > 0) else int(job.commute)

func get_committed_hours() -> int:
	return int(sleep_opt().hours) + get_work_hours() + get_commute_hours() \
		+ int(food_opt().hours) + int(WQData.cfg.chores_hours) + child_hours

func get_raw_free_hours() -> int:
	return maxi(0, int(WQData.cfg.hours_per_month) - get_committed_hours() + bonus_hours - time_penalty)

func get_efficiency() -> float:
	var short_pen := get_sleep_debt() * 0.05
	return clampf((0.40 + 0.60 * health / 100.0) * (1.0 - float(sleep_opt().penalty) - short_pen), 0.28, 1.05)

func get_hours_max() -> int:
	return maxi(0, roundi(get_raw_free_hours() * get_efficiency()))

func action_cost(base: int) -> int:
	if job.perkId == "quick" and base == int(WQData.cfg.action_cost.deal):
		return roundi(base * 0.8)
	return base

func can_spend(h: int) -> bool: return hours >= h

# ========== เงิน ==========
func get_food_cost() -> float: return round(food_base * float(food_opt().costMul))

func get_passive_income() -> float:
	var m: Dictionary = match_ref.get_mods()
	var total := 0.0
	for a in assets:
		if a.burned > 0: continue
		var k := 1.0
		if a.kind == "business" or a.kind == "micro": k = m.business
		elif a.kind == "realestate": k = m.realestate
		total += a.income * k
	return total

func asset_net(a: Dictionary) -> float:
	var m: Dictionary = match_ref.get_mods()
	var k := 1.0
	if a.kind == "business" or a.kind == "micro": k = m.business
	elif a.kind == "realestate": k = m.realestate
	var inc: float = 0.0 if a.burned > 0 else a.income * k
	return inc - a.debt * float(WQData.cfg.mortgage) * m.rate

func get_debt_payments() -> float:
	var t := 0.0
	for d in liabilities: t += d.balance * d.rate
	return t * match_ref.get_mods().rate

func get_total_expenses() -> float:
	return fixed_expenses + get_food_cost() + child_cost + get_debt_payments()

func get_current_salary() -> float:
	return 0.0 if (retired or downsize_left > 0) else salary

func get_total_income() -> float: return get_current_salary() + get_passive_income()
func get_monthly_cashflow() -> float: return get_total_income() - get_total_expenses()

func get_total_debt() -> float:
	var t := 0.0
	for d in liabilities: t += d.balance
	return t

func asset_price(a: Dictionary) -> float:
	return a.value * match_ref.market_index * a.drift

func get_asset_value() -> float:
	var t := 0.0
	for a in assets: t += asset_price(a)
	return t

func get_net_worth() -> float: return cash + get_asset_value() - get_total_debt()

func get_freedom_pct() -> float:
	return minf(100.0, get_passive_income() / maxf(1.0, get_total_expenses()) * 100.0)

func get_credit_limit() -> float:
	var base: float = (salary + get_passive_income()) * float(WQData.cfg.credit_multiple) * match_ref.get_mods().credit
	return round(base * (float(WQData.cfg.credit_perk_bonus) if job.perkId == "credit" else 1.0))

func get_credit_left() -> float: return maxf(0.0, get_credit_limit() - get_total_debt())

func get_med_factor() -> float:
	if job.perkId == "stable" or job.id == "doctor": return 0.5
	if job.perkId == "frugal": return 0.6
	return 1.0

func get_study_need() -> int: return 3 + study_level

# ========== การกระทำ ==========
func _fail(msg: String) -> Dictionary: return {"ok": false, "msg": msg}
func _log(t: String, kind := "info") -> void: match_ref.log_line(t, kind, self)

func close_deal(deal_id: int) -> Dictionary:
	var h := action_cost(int(WQData.cfg.action_cost.deal))
	if not can_spend(h): return _fail("เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d)" % [h, hours])
	var i := match_ref.find_deal(deal_id)
	if i < 0: return _fail("ดีลนี้ถูกคนอื่นคว้าไปแล้ว")
	var d: Dictionary = match_ref.deals[i]
	var price: float = round(d.price * 0.9) if job.perkId == "discount" else float(d.price)
	var down := roundf(price * (float(d.down) / float(d.price)))
	var debt := price - down
	if cash < down: return _fail("เงินสดไม่พอจ่ายเงินดาวน์")
	if debt > get_credit_left(): return _fail("วงเงินกู้ไม่พอ ต้องลดหนี้ก่อน")
	hours -= h
	cash -= down
	var income := roundf(d.income * (price / float(d.price)))
	if debt > 0:
		liabilities.append({"name": "สินเชื่อ: " + d.name, "balance": debt,
			"rate": float(WQData.cfg.mortgage), "linked": d.id})
	assets.append({"id": d.id, "kind": d.kind, "icon": d.icon, "name": d.name,
		"value": price, "cost": down, "debt": debt, "income": income,
		"vol": d.vol, "drift": 1.0, "offer": null, "sick": 0, "burned": 0})
	match_ref.deals.remove_at(i)
	_log("ซื้อ %s %s (%d ชม.) → %+d บาท/เดือน" % [d.icon, d.name, h,
		int(income - debt * float(WQData.cfg.mortgage))], "buy")
	changed.emit()
	return {"ok": true}

func sell_asset(asset_id: int) -> Dictionary:
	var c := int(WQData.cfg.action_cost.sell)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	var i := -1
	for k in assets.size():
		if assets[k].id == asset_id: i = k; break
	if i < 0: return _fail("ไม่พบทรัพย์สิน")
	var a: Dictionary = assets[i]
	hours -= c
	var price: float = float(a.offer.price) if a.offer != null else asset_price(a) * float(WQData.cfg.sell_fee)
	cash += price - a.debt
	for k in liabilities.size():
		if liabilities[k].get("linked", -1) == a.id:
			liabilities.remove_at(k); break
	assets.remove_at(i)
	var gain: float = price - float(a.value)
	_log("ขาย %s %s ได้ %d บาท" % [a.icon, a.name, int(price)], "sell" if gain >= 0 else "bad")
	changed.emit()
	return {"ok": true}

func take_loan(amount: float) -> Dictionary:
	var c := int(WQData.cfg.action_cost.loan)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	amount = round(amount / 10000.0) * 10000.0
	if amount <= 0: return _fail("จำนวนไม่ถูกต้อง")
	if amount > get_credit_left(): return _fail("เกินวงเงินกู้")
	hours -= c
	var soft: bool = job.perkId == "credit" or job.perkId == "stable"
	var rate: float = float(WQData.cfg.loan_rate_soft) if soft else float(WQData.cfg.loan_rate)
	liabilities.append({"name": "สินเชื่อส่วนบุคคล", "balance": amount, "rate": rate})
	cash += amount
	_log("กู้เงิน %d บาท (ดอกเบี้ย %d%%/ปี)" % [int(amount), int(rate * 1200)], "debt")
	changed.emit()
	return {"ok": true}

## ชำระหนี้ได้ทั้งก้อนหรือบางส่วน — ไม่เสียเวลา (เป็นแค่การโอนเงิน)
func repay_debt(index: int, amount: float) -> Dictionary:
	if index < 0 or index >= liabilities.size(): return _fail("ไม่พบหนี้")
	if cash <= 0: return _fail("ไม่มีเงินสดเหลือ")
	var d: Dictionary = liabilities[index]
	amount = floor(min(amount, min(d.balance, cash)))
	if amount <= 0: return _fail("จำนวนไม่ถูกต้อง")
	var saved: float = amount * float(d.rate) * match_ref.get_mods().rate
	cash -= amount
	d.balance -= amount
	var closed: bool = d.balance < 1
	_log("ชำระหนี้ \"%s\" %d บาท%s • ประหยัดดอกเบี้ย %d บาท/เดือน ตลอดไป" %
		[d.name, int(amount), " — ปิดหนี้ก้อนนี้เรียบร้อย!" if closed else "", int(saved)], "debt")
	if closed: liabilities.remove_at(index)
	changed.emit()
	return {"ok": true}

func side_job() -> Dictionary:
	if retired: return _fail("ลาออกจากงานประจำแล้ว")
	if downsize_left > 0: return _fail("ตอนนี้ไม่มีงานประจำอยู่")
	var c := int(WQData.cfg.action_cost.side)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	if side_used >= int(WQData.cfg.side_job_max_count): return _fail("รับงานเสริมได้สูงสุด 3 ครั้ง/เดือน")
	hours -= c; side_used += 1
	var mul := 1.5 if job.perkId == "hustle" else 1.0
	var gain := roundf(salary * match_ref.rng.range_f(WQData.cfg.side_job_min, WQData.cfg.side_job_max) * mul)
	cash += gain
	if not is_ai: _log("รับงานเสริม %d ชม. ได้ %d บาท" % [c, int(gain)], "work")
	changed.emit()
	return {"ok": true}

func scout() -> Dictionary:
	var c := int(WQData.cfg.action_cost.scout)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	hours -= c
	for _i in 2:
		if match_ref.deals.size() >= 11: match_ref.deals.remove_at(0)
		match_ref.deals.append(match_ref.make_deal(false, 0.0))
	if not is_ai: _log("ออกดูทำเล พบดีลใหม่ 2 รายการ", "info")
	changed.emit()
	return {"ok": true}

func study() -> Dictionary:
	var c := int(WQData.cfg.action_cost.study)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	var fee := roundf(salary * float(WQData.cfg.study_fee_ratio))
	if cash < fee: return _fail("ค่าเรียน %d บาท — เงินสดไม่พอ" % int(fee))
	hours -= c; cash -= fee
	study_progress += 1.5 if job.perkId == "hustle" else 1.0
	if study_progress >= get_study_need():
		study_progress = 0.0
		study_level += 1
		salary = round(salary * (1.0 + float(WQData.cfg.study_raise)))
		_log("🎓 เรียนจบคอร์ส! เงินเดือนขึ้นเป็น %d บาท — และรายจ่ายไม่ได้ขึ้นตาม" % int(salary), "good")
	changed.emit()
	return {"ok": true}

func exercise() -> Dictionary:
	var c := int(WQData.cfg.action_cost.exercise)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	hours -= c
	health = clampf(health + (6.0 if job.id == "nurse" else 5.0), 0, 100)
	changed.emit()
	return {"ok": true}

func rest() -> Dictionary:
	var c := int(WQData.cfg.action_cost.rest)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	hours -= c
	health = clampf(health + 2.5, 0, 100)
	rested_this_month = true
	changed.emit()
	return {"ok": true}

# ========== ด่าน 2 ==========
func enter_phase2(d: Dictionary, do_retire: bool) -> void:
	phase = 2
	pending_dream = false
	var exp := get_total_expenses()
	dream = d.duplicate(true)
	dream["cost"] = round(exp * float(d.costMul) / 10000.0) * 10000.0
	dream["passiveReq"] = round(exp * float(d.passiveMul) / 100.0) * 100.0
	retired = do_retire
	hours = get_hours_max()
	match_ref.log_line("%s ตั้งเป้าหมายใหม่: %s %s" % [pname, d.icon, d.name], "win", null)

func can_claim_dream() -> bool:
	return phase == 2 and get_net_worth() >= dream.cost and get_passive_income() >= dream.passiveReq

func claim_dream() -> Dictionary:
	if not can_claim_dream(): return _fail("ยังไม่ครบทั้งความมั่งคั่งและรายได้ต่อเดือน")
	phase = 3
	dream_done = match_ref.month
	match_ref.add_champion(self)
	return {"ok": true}

# ========== สิ้นเดือน ==========
func settle() -> void:
	var r = match_ref.rng
	var cfg = WQData.cfg

	for a in assets:
		var bias := 0.508 if (a.kind == "speculation" and job.perkId == "insight") else 0.5
		a.drift *= 1.0 + (r.next() - bias) * a.vol * 0.55
		a.drift = clampf(a.drift, 0.35, 3.2)
		if a.offer != null:
			a.offer.ttl -= 1
			if a.offer.ttl <= 0: a.offer = null
		if a.sick > 0:
			a.sick -= 1
			if a.sick == 0: a.income = a.base_income
		if a.burned > 0: a.burned -= 1
		if a.offer == null and r.next() < float(cfg.offer_chance):
			var base := (1.12 + r.next() * 0.55) if a.kind == "speculation" else (1.08 + r.next() * 0.30)
			a.offer = {"price": round(asset_price(a) * base), "ttl": 2}

	if match_ref.month % 12 == 0:
		fixed_expenses = round(fixed_expenses * float(cfg.inflation_yearly))
		food_base = round(food_base * float(cfg.inflation_yearly))

	cash += get_total_income() - get_total_expenses()
	if downsize_left > 0: downsize_left -= 1

	# --- สุขภาพ ---
	var dh: float = float(sleep_opt().health) + float(food_opt().health) - 0.35 - get_sleep_debt() * 1.3
	var load := get_work_hours() + side_used * int(cfg.action_cost.side)
	if load > 300: dh -= 3.0
	elif load > 255: dh -= 1.5
	if job.perkId == "hustle": dh += 0.8
	health = clampf(health + dh, 0, 100)

	if health < 25 and r.next() < 0.30:
		var bill := roundf(get_total_expenses() * (1.2 + r.next() * 1.6) * get_med_factor())
		cash -= bill
		downsize_left = maxi(downsize_left, 1)
		time_penalty += 90
		health = clampf(health + 18, 0, 100)
		_log("🏥 สุขภาพวิกฤต! ล้มป่วยหนัก ค่ารักษา %d บาท" % int(bill), "bad")

	var ev_chance := float(cfg.event_chance) - (float(cfg.rest_event_reduction) if rested_this_month else 0.0)
	if r.next() < ev_chance: roll_event()
	rested_this_month = false

	for a in assets:
		if (a.kind == "business" or a.kind == "micro") and a.sick == 0 and a.burned == 0 \
				and r.next() < float(cfg.business_slump_chance):
			a["base_income"] = a.income
			a.income = round(a.income * 0.35)
			a.sick = 2 + r.range_i(3)

	if cash < 0:
		var need := ceilf(-cash / 10000.0) * 10000.0
		liabilities.append({"name": "บัตรกดเงินสด (ดอกโหด)", "balance": need, "rate": float(cfg.emergency_rate)})
		cash += need
		_log("🚨 เงินสดไม่พอ! ต้องกดบัตรเงินสด %d บาท" % int(need), "bad")

	history.append({"m": match_ref.month, "passive": roundi(get_passive_income()),
		"exp": roundi(get_total_expenses()), "nw": roundi(get_net_worth()),
		"cash": roundi(cash), "hp": snappedf(health, 0.1), "hours": get_hours_max(),
		"assets": assets.size(), "debt": roundi(get_total_debt()), "phase": phase})

	if not bankrupt and get_debt_payments() > (get_current_salary() + get_passive_income()) * 1.25 \
			and get_net_worth() < 0:
		bankrupt = true
		_log("💀 ล้มละลาย", "bad")

	if finished == 0 and get_passive_income() >= get_total_expenses():
		finished = match_ref.month
		match_ref.log_line("🎉 %s ออกจากสนามแข่งหนูได้แล้ว! (เดือนที่ %d)" % [pname, finished], "win", null)
		if is_ai:
			enter_phase2(WQData.dreams[r.range_i(WQData.dreams.size())],
				get_passive_income() > get_total_expenses() * 1.12)
		else:
			pending_dream = true

	if is_ai and phase == 2 and can_claim_dream(): claim_dream()

	time_penalty = maxi(0, time_penalty - 90)
	side_used = 0
	hours = get_hours_max()
	changed.emit()

func roll_event() -> void:
	var r = match_ref.rng
	var list: Array = WQData.events2 if phase >= 2 else WQData.events1
	var base: float = get_total_expenses() if phase >= 2 else maxf(salary, get_total_expenses() * 0.6)
	var hp_boost := 3.2 if health < 40 else (2.0 if health < 55 else (1.2 if health < 70 else 0.6))
	var total := 0.0
	var weights: Array = []
	for e in list:
		var w: float = float(e.w) * (hp_boost if e.get("health", false) else 1.0)
		weights.append(w); total += w
	var roll := r.next() * total
	var ev: Dictionary = list[0]
	for i in list.size():
		roll -= weights[i]
		if roll <= 0: ev = list[i]; break

	if ev.has("bonusDeals"):
		for _i in int(ev.bonusDeals): match_ref.deals.append(match_ref.make_deal(false, 0.0))
		_log("✨ " + ev.text, "good"); return

	var frugal := 0.5 if job.perkId == "frugal" else 1.0
	var med := get_med_factor() if ev.get("health", false) else 1.0

	if ev.has("costMul"):
		var c := roundf(base * r.range_f(ev.costMul[0], ev.costMul[1]) * frugal * med)
		cash -= c
		_log("❗ %s −%d บาท" % [ev.text, int(c)], "bad")
	elif ev.has("gainMul"):
		var g := roundf(base * r.range_f(ev.gainMul[0], ev.gainMul[1]))
		cash += g
		_log("✨ %s +%d บาท" % [ev.text, int(g)], "good"); return
	elif ev.has("raise"):
		var p := r.range_f(ev.raise[0], ev.raise[1])
		salary = round(salary * (1.0 + p))
		fixed_expenses = round(fixed_expenses * (1.0 + p * 0.55))
		_log("✨ %s — แต่รายจ่ายโตตามทันที" % ev.text, "good"); return
	elif ev.has("market"):
		var mk := r.range_f(ev.market[0], ev.market[1])
		match_ref.market_index = clampf(match_ref.market_index * (1.0 + mk), 0.55, 1.9)
		_log(ev.text, "good" if mk > 0 else "bad"); return
	elif ev.has("childMul"):
		var cc := roundf(base * r.range_f(ev.childMul[0], ev.childMul[1]))
		child_cost += cc
		if ev.has("childHours"): child_hours += int(ev.childHours)
		_log("👶 %s" % ev.text, "bad"); return
	elif ev.has("downsize"):
		if job.perkId == "stable":
			_log("🛡️ มีการปรับโครงสร้าง แต่ตำแหน่งคุณมั่นคง", "good"); return
		downsize_left = int(ev.downsize)
		_log("💥 " + ev.text, "bad"); return

	if ev.has("hpCost"): health = clampf(health - float(ev.hpCost), 0, 100)
	if ev.has("timeCost"): time_penalty += int(ev.timeCost)
