class_name WQPlayer
extends RefCounted
## ผู้เล่นหนึ่งคน — ถือ งบการเงิน + งบเวลา + สุขภาพ
## กฎเหล็ก: ไฟล์นี้ห้าม reference อะไรใน ui/ หรือ world/ เด็ดขาด

signal changed

## อ้างกลับไปหาแมตช์แบบ **อ่อน** — `WQMatch.players` ถือผู้เล่นไว้แบบแข็งอยู่แล้ว
## ถ้าฝั่งนี้ถือแบบแข็งด้วยจะกลายเป็นวงอ้างอิง RefCounted แล้วทั้งแมตช์จะไม่ถูกคืนหน่วยความจำเลย
## (เดิมรัน sim ทีนึงรั่วหลักพัน object) เจ้าของอายุจริงของแมตช์คือคนที่สร้างมันขึ้นมา
var _match_wr: WeakRef
var match_ref: WQMatch:
	get:
		return _match_wr.get_ref() if _match_wr != null else null
	set(value):
		_match_wr = weakref(value) if value != null else null
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
var exercise_this_month := 0

# --- แผนที่และการเดินทาง (ข้อ 3A ของ GDD) ---
var place := "home"          # อยู่ที่ไหนตอนนี้
var travel_used := 0         # ชั่วโมงที่เสียไปกับการเดินทางเดือนนี้
var vehicle := "public"
var devices: Array = []
var gym_pack := ""           # แพ็กเกจฟิตเนสรายเดือนที่ซื้อไว้ ("" = ไม่มี)
var shield := 0.0            # โล่กันเหตุการณ์ร้ายจากการไปพักผ่อน

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

func set_sleep(i: int) -> Dictionary:
	if not can_do_here("sleep"): return _fail("ตั้งค่าการนอนได้ที่บ้านเท่านั้น")
	sleep_idx = clampi(i, 0, WQData.cfg.sleep_options.size() - 1)
	hours = mini(hours, get_hours_max()); changed.emit()
	return {"ok": true}

func set_food(id: String) -> Dictionary:
	if not can_do_here("food"): return _fail("วางแผนอาหารได้ที่บ้านเท่านั้น")
	for f in WQData.cfg.food_options:
		if f.id == id:
			food_id = id
			hours = mini(hours, get_hours_max())
			break
	changed.emit()
	return {"ok": true}

# ========== แผนที่และการเดินทาง ==========
func get_veh() -> Dictionary: return WQData.vehicle(vehicle)
func get_travel_factor() -> float: return float(get_veh().factor)
func has_device(id: String) -> bool: return devices.has(id)

## ชั่วโมงเดินทางระหว่างสองสถานที่ — อย่างน้อย 1 ชม. เสมอ
func travel_cost(to_id: String, from_id := "") -> int:
	var a := WQData.place(from_id if from_id != "" else place)
	var b := WQData.place(to_id)
	if a.is_empty() or b.is_empty() or a.id == b.id: return 0
	return maxi(1, roundi(absf(float(a.x) - float(b.x)) * float(WQData.cfg.travel_rate) * get_travel_factor()))

## ทำ action นี้ได้จากที่ไหน (รวมทางลัดจากอุปกรณ์)
func place_for(act: String) -> String:
	if act == "loan" or act == "repay" or act == "fund":
		return place if has_device("smartphone") else "bank"
	if act == "study": return place if has_device("laptop") else "school"
	if act == "freelance": return place if has_device("laptop") else "cowork"
	for pl in WQData.places:
		if pl.acts.has(act): return pl.id
	return place

func can_do_here(act: String) -> bool: return place_for(act) == place

func place_name(act: String) -> String:
	var p := WQData.place(place_for(act))
	return "" if p.is_empty() else "%s %s" % [p.icon, p.name]

func act_for_kind(kind: String) -> String:
	if kind == "speculation": return "gold"
	return "fund" if kind == "fund" else "estate"

## คืน null ถ้าอยู่ถูกที่แล้ว · คืน {place, hours} ถ้าต้องเดินทางก่อน
func need_travel(act: String):
	var need := place_for(act)
	return null if need == place else {"place": need, "hours": travel_cost(need)}

func travel_to(to_id: String) -> Dictionary:
	if to_id == place: return _fail("อยู่ที่นี่อยู่แล้ว")
	var h := travel_cost(to_id)
	if not can_spend(h):
		return _fail("เวลาไม่พอ ต้องใช้ %d ชม. ในการเดินทาง (เหลือ %d ชม.)" % [h, hours])
	hours -= h; travel_used += h
	var from := WQData.place(place)
	var to := WQData.place(to_id)
	place = to_id
	if not is_ai:
		_log("%s เดินทางจาก%s → %s %s (%d ชม.)" % [get_veh().icon, from.name, to.icon, to.name, h], "move")
	changed.emit()
	return {"ok": true}

## ซื้อพาหนะ — ดาวน์ + กู้ส่วนที่เหลือ · ลดระดับได้โดยขายคันเดิมทิ้ง
func buy_vehicle(id: String) -> Dictionary:
	var v := WQData._by_id(WQData.vehicles, id)
	if v.is_empty(): return _fail("ไม่พบพาหนะ")
	if place != "mall": return _fail("ต้องไปดูรถที่ 🛒 ห้างสรรพสินค้า ก่อน")
	if v.id == vehicle: return _fail("ใช้คันนี้อยู่แล้ว")
	var cur := get_veh()
	var cfg = WQData.cfg
	if WQData.vehicle_index(v.id) < WQData.vehicle_index(cur.id):
		cash += roundf(float(cur.price) * float(cfg.vehicle_downgrade_refund))
		vehicle = v.id
		_log("ขาย %s %s แล้วเปลี่ยนเป็น %s %s" % [cur.icon, cur.name, v.icon, v.name], "sell")
		changed.emit()
		return {"ok": true}
	var down := roundf(float(v.price) * float(v.downPct))
	if down <= 0: down = float(v.price)
	var debt := float(v.price) - down
	if cash < down: return _fail("เงินดาวน์ไม่พอ ต้องใช้ %d บาท" % int(down))
	if debt > get_credit_left(): return _fail("วงเงินกู้ไม่พอ")
	if float(cur.price) > 0: cash += roundf(float(cur.price) * float(cfg.vehicle_tradein))
	cash -= down
	if debt > 0:
		liabilities.append({"name": "ผ่อน" + str(v.name), "balance": debt,
			"rate": float(cfg.vehicle_loan_rate)})
	vehicle = v.id
	_log("🛒 ซื้อ %s %s — ดาวน์ %d บาท • เวลาเดินทางเหลือ %d%% ค่าใช้จ่ายเพิ่ม %d บาท/เดือน" %
		[v.icon, v.name, int(down), roundi(float(v.factor) * 100.0), int(v.upkeep)], "buy")
	changed.emit()
	return {"ok": true}

func buy_device(id: String) -> Dictionary:
	var d := WQData.device(id)
	if d.is_empty(): return _fail("ไม่พบอุปกรณ์")
	if place != "mall" and not has_device("smartphone"):
		return _fail("ต้องไปที่ 🛒 ห้างสรรพสินค้า ก่อน")
	if has_device(id): return _fail("มีอยู่แล้ว")
	if cash < float(d.price): return _fail("เงินสดไม่พอ ต้องใช้ %d บาท" % int(d.price))
	cash -= float(d.price)
	devices.append(id)
	_log("🛒 ซื้อ %s %s — %s" % [d.icon, d.name, d.note], "buy")
	changed.emit()
	return {"ok": true}

# ========== เวลา ==========
func get_sleep_need() -> int:
	return 7 if retired else int(job.get("sleepNeed", 7))

func get_sleep_debt() -> int:
	return maxi(0, get_sleep_need() - int(sleep_opt().h))

func get_work_hours() -> int:
	return 0 if (retired or downsize_left > 0) else int(job.work)

func get_commute_hours() -> int:
	if retired or downsize_left > 0: return 0
	return roundi(float(job.commute) * get_travel_factor())

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

## ค่าดูแลพาหนะ + อุปกรณ์ — ราคาของ "การซื้อเวลา" ที่เดินต่อทุกเดือน
func get_upkeep_cost() -> float:
	var u := float(get_veh().upkeep)
	for id in devices:
		var d := WQData.device(id)
		if not d.is_empty(): u += float(d.upkeep)
	return u

func get_total_expenses() -> float:
	return fixed_expenses + get_food_cost() + child_cost + get_upkeep_cost() + get_debt_payments()

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
	var act := act_for_kind(d.kind)
	if not can_do_here(act): return _fail("ต้องไปที่ %s ก่อน" % place_name(act))
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
	var s_act := act_for_kind(a.kind)
	if not can_do_here(s_act): return _fail("ต้องไปที่ %s ก่อนถึงจะขายได้" % place_name(s_act))
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
	if not can_do_here("loan"):
		return _fail("ต้องไปที่ %s ก่อน (หรือซื้อ 📱 สมาร์ตโฟนเพื่อทำออนไลน์)" % place_name("loan"))
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
	if not can_do_here("repay"):
		return _fail("ต้องไปที่ %s ก่อน (หรือซื้อ 📱 สมาร์ตโฟน)" % place_name("repay"))
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

## งานเสริมมีสองแบบ: OT ที่ออฟฟิศ กับ freelance ที่ co-working (หรือที่บ้านถ้ามีโน้ตบุ๊ก)
func side_job(kind := "ot") -> Dictionary:
	if kind == "ot":
		if retired: return _fail("ลาออกจากงานประจำแล้ว รับ OT ไม่ได้")
		if downsize_left > 0: return _fail("ตอนนี้ไม่มีงานประจำอยู่")
	var act := "ot" if kind == "ot" else "freelance"
	if not can_do_here(act): return _fail("ต้องไปที่ %s ก่อน" % place_name(act))
	var c := int(WQData.cfg.action_cost.side)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	if side_used >= int(WQData.cfg.side_job_max_count): return _fail("รับงานเสริมได้สูงสุด 3 ครั้ง/เดือน")
	hours -= c; side_used += 1
	var mul := 1.5 if job.perkId == "hustle" else 1.0
	# freelance ที่ co-working ได้ดีกว่า OT 25% · ทำที่บ้านได้เท่า OT
	var rate_mul := 1.0
	if kind == "freelance" and place == "cowork": rate_mul = float(WQData.cfg.freelance_cowork_mul)
	var gain := roundf(salary * match_ref.rng.range_f(WQData.cfg.side_job_min, WQData.cfg.side_job_max) * mul * rate_mul)
	cash += gain
	if not is_ai:
		_log("%s %d ชม. ได้ %d บาท" % ["⏱️ รับ OT" if kind == "ot" else "💻 รับงาน freelance", c, int(gain)], "work")
	changed.emit()
	return {"ok": true}

func scout() -> Dictionary:
	if not can_do_here("scout"): return _fail("ต้องไปที่ %s ก่อน" % place_name("scout"))
	var c := int(WQData.cfg.action_cost.scout)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	hours -= c
	for _i in 2:
		if match_ref.deals.size() >= 11: match_ref.deals.remove_at(0)
		match_ref.deals.append(match_ref.make_deal(false, 0.0))
	if not is_ai: _log("ออกดูทำเล พบดีลใหม่ 2 รายการ", "info")
	changed.emit()
	return {"ok": true}

## เรียนที่สถาบันคืบหน้าเร็วกว่าเรียนออนไลน์ที่บ้าน แต่ค่าเรียนแพงกว่า
func study() -> Dictionary:
	if not can_do_here("study"):
		return _fail("ต้องไปที่ %s ก่อน (หรือซื้อ 💻 โน้ตบุ๊กเพื่อเรียนออนไลน์)" % place_name("study"))
	var cfg = WQData.cfg
	var c := int(cfg.action_cost.study)
	if not can_spend(c): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % c)
	var online := place != "school"
	var fee := roundf(salary * float(cfg.study_fee_ratio_online if online else cfg.study_fee_ratio))
	if cash < fee: return _fail("ค่าเรียน %d บาท — เงินสดไม่พอ" % int(fee))
	hours -= c; cash -= fee
	var speed := 1.5 if job.perkId == "hustle" else 1.0
	study_progress += speed * (float(cfg.study_progress_online) if online else 1.0)
	if study_progress >= get_study_need():
		study_progress = 0.0
		study_level += 1
		salary = round(salary * (1.0 + float(cfg.study_raise)))
		_log("🎓 เรียนจบคอร์ส! เงินเดือนขึ้นเป็น %d บาท — และรายจ่ายไม่ได้ขึ้นตาม" % int(salary), "good")
	changed.emit()
	return {"ok": true}

## ออกกำลังกายที่ฟิตเนส — แพ็กเกจรายเดือนจ่ายครั้งเดียวใช้ได้ทั้งเดือน
func exercise(pack_id := "") -> Dictionary:
	if not can_do_here("gym"): return _fail("ต้องไปที่ %s ก่อน" % place_name("gym"))
	var want := pack_id if pack_id != "" else (gym_pack if gym_pack != "" else "daily")
	var pk := WQData.gym_pack(want)
	if pk.is_empty(): pk = WQData.gym_packs[0]
	var owned: bool = pk.get("monthly", false) and gym_pack == pk.id
	var fee: float = 0.0 if owned else float(pk.cost)
	var h := int(pk.hours)
	if not can_spend(h): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % h)
	if cash < fee: return _fail("เงินสดไม่พอ ต้องจ่าย %d บาท" % int(fee))
	hours -= h; cash -= fee; exercise_this_month += 1
	if pk.get("monthly", false) and not owned: gym_pack = pk.id
	var gain: float = float(pk.hp) + (1.0 if job.id == "nurse" else 0.0)
	health = clampf(health + gain, 0, 100)
	if not is_ai:
		_log("🏋️ %s %s — %d ชม. → สุขภาพ +%s" % [pk.icon, pk.name, h, str(gain)], "good")
	changed.emit()
	return {"ok": true}

## ไปพักผ่อนที่โรงแรม/รีสอร์ต — ฟื้นสุขภาพเยอะและได้โล่กันเหตุการณ์ร้าย
func vacation(pack_id := "") -> Dictionary:
	if not can_do_here("resort"): return _fail("ต้องไปที่ %s ก่อน" % place_name("resort"))
	var pk := WQData.resort_pack(pack_id)
	if pk.is_empty(): pk = WQData.resort_packs[0]
	var h := int(pk.hours)
	if not can_spend(h): return _fail("เวลาไม่พอ ต้องใช้ %d ชม." % h)
	if cash < float(pk.cost): return _fail("เงินสดไม่พอ ต้องจ่าย %d บาท" % int(pk.cost))
	hours -= h; cash -= float(pk.cost)
	health = clampf(health + float(pk.hp), 0, 100)
	shield = maxf(shield, float(pk.shield))
	rested_this_month = true
	if not is_ai:
		_log("%s %s — %d ชม. จ่าย %d บาท → สุขภาพ +%d" % [pk.icon, pk.name, h, int(pk.cost), int(pk.hp)], "good")
	changed.emit()
	return {"ok": true}

func rest() -> Dictionary:
	if not can_do_here("rest"): return _fail("ต้องกลับ %s ก่อน" % place_name("rest"))
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
	var dh: float = float(sleep_opt().health) + float(food_opt().health) - 0.35 \
		- get_sleep_debt() * 1.3 + float(get_veh().hp)
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

	# โล่จากการไปพักผ่อนคูณลดโอกาสก่อน แล้วการพักผ่อนธรรมดาค่อยหักออกอีกทีหนึ่ง
	var ev_chance := float(cfg.event_chance) * (1.0 - shield)
	if rested_this_month: ev_chance -= float(cfg.rest_event_reduction)
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
		"assets": assets.size(), "debt": roundi(get_total_debt()), "phase": phase,
		"salary": salary, "sleep": int(sleep_opt().h), "food": food_id,
		"travel": travel_used, "vehicle": vehicle, "devices": "|".join(devices)})

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
	exercise_this_month = 0
	place = "home"          # สิ้นเดือนกลับบ้านเสมอ
	travel_used = 0
	gym_pack = ""           # แพ็กเกจฟิตเนสหมดอายุรายเดือน
	shield = 0.0
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
