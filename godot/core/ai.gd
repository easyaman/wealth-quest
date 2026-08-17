class_name WQAi
extends RefCounted
## กลยุทธ์บอท — แยกไฟล์ไว้เผื่อทำหลายระดับความยาก
## ลำดับความสำคัญนี้ผ่านการจำลอง 4,000 เกมแล้ว อย่าเปลี่ยนโดยไม่รัน sim ใหม่
##
## หลังพอร์ตระบบแผนที่ (ข้อ 3A) บอทต้องวางแผนเส้นทางเองแล้ว:
##   คะแนน = ผลตอบแทน ÷ (เวลาทำ + เวลาเดินทาง)
## แปลตรงจาก aiTurn / aiBestMove / aiShop / aiWantsShop ใน ../engine.js

const GUARD_MAX := 40

## เปิดจาก sim/ เพื่อพิมพ์ทุกการตัดสินใจออกมาเทียบกับ engine.js — ปกติปิดไว้ ไม่มีผลกับเกม
static var trace := false

static func take_turn(p) -> void:
	var cfg = WQData.cfg

	# ไลฟ์สไตล์ตั้งได้ที่บ้านเท่านั้น — ต้นเดือนบอทอยู่บ้านอยู่แล้ว
	if p.place == "home":
		var need_idx := -1
		for i in cfg.sleep_options.size():
			if int(cfg.sleep_options[i].h) >= int(p.job.get("sleepNeed", 7)): need_idx = i; break
		if p.health < 55:
			p.sleep_idx = 3
			p.set_food("cook")
		elif p.cash < p.get_total_expenses() * 2:
			p.sleep_idx = maxi(need_idx, 2)
			p.set_food("cook")
		else:
			p.sleep_idx = maxi(need_idx, 2)
			p.set_food("street")
		if p.has_device("smartphone"): shop(p)
	if p.place == "mall": shop(p)

	var guard := 0
	while p.hours > 0 and guard < GUARD_MAX:
		guard += 1
		if p.phase == 2 and p.can_claim_dream(): p.claim_dream(); return
		var best = best_move(p)
		if trace:
			print("A m=%d h=%d cash=%d hp=%.1f -> %s" % [p.match_ref.month, p.hours,
				roundi(p.cash), p.health,
				"none" if best == null else "%s@%s tr=%d sc=%.4f" % [best.tag, best.place, best.travel, best.score]])
		if best == null: break
		if best.travel > 0:
			if not p.travel_to(best.place).ok: break
		var r = best.run.call()
		if r == null or not r.ok: break
	p.hours = 0

## บอทอยากไปห้างไหม — ใช้ตัดสินใจว่าคุ้มที่จะเสียเวลาเดินทางไปซื้อของหรือยัง
static func wants_shop(p) -> bool:
	if p.place == "mall": return false
	if not p.has_device("smartphone") and p.cash > 90000: return true
	if not p.has_device("laptop") and p.cash > 160000: return true
	var val: float = maxf(300.0, (p.salary + p.get_passive_income()) / maxf(40.0, float(p.get_hours_max())))
	var cur_i: int = WQData.vehicle_index(p.vehicle)
	for i in range(WQData.vehicles.size() - 1, 0, -1):
		var v: Dictionary = WQData.vehicles[i]
		if cur_i >= i: break
		var save_h: float = (float(p.job.commute) + 40.0) * (p.get_travel_factor() - float(v.factor))
		var cost: float = float(v.upkeep) + (float(v.price) - float(v.price) * float(v.downPct)) * float(WQData.cfg.vehicle_loan_rate)
		var down := roundf(float(v.price) * float(v.downPct))
		if save_h * val > cost * 1.25 and p.cash > down + p.get_total_expenses() * 3: return true
	return false

## ตัดสินใจซื้อของอำนวยความสะดวก — ตีมูลค่าเวลาที่ประหยัดได้เทียบกับค่าผ่อน
static func shop(p) -> void:
	var val: float = maxf(300.0, (p.salary + p.get_passive_income()) / maxf(40.0, float(p.get_hours_max())))
	if not p.has_device("smartphone") and p.cash > 90000: p.buy_device("smartphone")
	if not p.has_device("laptop") and p.cash > 160000: p.buy_device("laptop")
	for i in range(WQData.vehicles.size() - 1, 0, -1):
		var v: Dictionary = WQData.vehicles[i]
		if WQData.vehicle_index(p.vehicle) >= i: break
		var save_h: float = (float(p.job.commute) + 40.0) * (p.get_travel_factor() - float(v.factor))
		var cost: float = float(v.upkeep) + (float(v.price) - float(v.price) * float(v.downPct)) * float(WQData.cfg.vehicle_loan_rate)
		var down := roundf(float(v.price) * float(v.downPct))
		if save_h * val > cost * 1.25 and p.cash > down + p.get_total_expenses() * 3 \
				and (float(v.price) - down) <= p.get_credit_left():
			p.buy_vehicle(v.id)
			break

## คืนตัวเลือกที่คุ้มที่สุด (รวมเวลาเดินทางในการคิดแล้ว) หรือ null ถ้าทำอะไรไม่ได้แล้ว
static func best_move(p):
	var cfg = WQData.cfg
	var cands: Array = []
	var add := func(tag: String, pl: String, h: int, score: float, run: Callable) -> void:
		var travel: int = 0 if pl == p.place else p.travel_cost(pl)
		var total := h + travel
		if total > p.hours or total <= 0: return
		cands.append({"tag": tag, "place": pl, "travel": travel, "score": score / total, "run": run})

	# ขายทรัพย์สินที่มีข้อเสนอดี
	for a in p.assets:
		if a.offer == null: continue
		var need := 1.22 if a.kind == "speculation" else 1.28
		if float(a.offer.price) <= float(a.value) * need: continue
		var aid: int = a.id
		add.call("sell", p.place_for(p.act_for_kind(a.kind)), int(cfg.action_cost.sell),
			(float(a.offer.price) - float(a.value)) / 1000.0,
			func(): return p.sell_asset(aid))

	# ซื้อดีล
	for d in p.match_ref.deals:
		var price: float = float(d.price) * 0.9 if p.job.perkId == "discount" else float(d.price)
		var down: float = price * (float(d.down) / float(d.price))
		var debt := price - down
		var cf: float = float(d.income) * (price / float(d.price)) - debt * float(cfg.mortgage)
		var roi: float = 0.022 if d.kind == "speculation" else cf / maxf(1.0, down)
		if p.cash - down < p.get_total_expenses() * 0.5 or debt > p.get_credit_left() or roi < 0.018: continue
		var did: int = d.id
		add.call("deal", p.place_for(p.act_for_kind(d.kind)), p.action_cost(int(cfg.action_cost.deal)),
			cf / 40.0 + roi * 400.0,
			func(): return p.close_deal(did))

	# สุขภาพ
	if p.health < 80:
		var urgency: float = 60.0 if p.health < 50 else (25.0 if p.health < 65 else 8.0)
		var pk: Dictionary = WQData.gym_pack(p.gym_pack) if p.gym_pack != "" \
			else (WQData.gym_packs[1] if p.cash > 40000 else WQData.gym_packs[0])
		var pkid: String = pk.id
		add.call("gym", "gym", int(pk.hours), urgency, func(): return p.exercise(pkid))
		if p.health < 45 and p.cash > 60000:
			add.call("vacation", "resort", int(WQData.resort_packs[1].hours), urgency * 1.1,
				func(): return p.vacation("weekend"))
		add.call("rest", "home", int(cfg.action_cost.rest), urgency * 0.35, func(): return p.rest())

	# เรียนเพิ่มช่วงต้นเกม
	if p.phase == 1 and p.study_level < 2 and p.match_ref.month < 24 and p.cash > p.salary * 2.5:
		add.call("study", p.place_for("study"), int(cfg.action_cost.study), 14.0, func(): return p.study())

	# เงินตึง → งานเสริม
	if p.cash < p.get_total_expenses() * 2.5 and p.side_used < 3:
		if not p.retired and p.downsize_left == 0:
			add.call("ot", "office", int(cfg.action_cost.side), p.salary * 0.21 / 900.0,
				func(): return p.side_job("ot"))
		add.call("freelance", p.place_for("freelance"), int(cfg.action_cost.side), p.salary * 0.24 / 900.0,
			func(): return p.side_job("freelance"))

	# หาดีลใหม่
	if p.match_ref.deals.size() < 9:
		add.call("scout", "estate", int(cfg.action_cost.scout), 6.0, func(): return p.scout())

	# ไปห้างซื้อของอำนวยความสะดวก
	if wants_shop(p):
		add.call("shop", "mall", 2, 30.0, func(): shop(p); return {"ok": true})

	if cands.is_empty(): return null
	# เทียบเท่า sort จากมากไปน้อยแบบ stable แล้วหยิบตัวแรก — เสมอกันให้ตัวที่เพิ่มก่อนชนะ
	# (sort_custom ของ Godot ไม่ stable จึงห้ามใช้ตรงนี้ ไม่งั้นผลจะต่างจาก engine.js)
	var best: Dictionary = cands[0]
	for i in range(1, cands.size()):
		if cands[i].score > best.score: best = cands[i]
	return best
