class_name WQAi
extends RefCounted
## กลยุทธ์บอท — แยกไฟล์ไว้เผื่อทำหลายระดับความยาก
## ลำดับความสำคัญนี้ผ่านการจำลอง 4,000 เกมแล้ว อย่าเปลี่ยนโดยไม่รัน sim ใหม่

static func take_turn(p) -> void:
	var cfg = WQData.cfg
	# เลือกไลฟ์สไตล์
	if p.health < 55:
		p.set_sleep(3); p.set_food("cook")
	elif p.cash < p.get_total_expenses() * 2:
		p.set_food("cook")
	else:
		var need_idx := 2
		for i in cfg.sleep_options.size():
			if int(cfg.sleep_options[i].h) >= int(p.job.get("sleepNeed", 7)): need_idx = i; break
		p.set_sleep(maxi(need_idx, 2)); p.set_food("street")

	var guard := 0
	while p.hours > 0 and guard < 40:
		guard += 1
		if p.phase == 2 and p.can_claim_dream(): p.claim_dream(); return
		if p.health < 50 and p.can_spend(int(cfg.action_cost.exercise)): p.exercise(); continue

		# 1) รับข้อเสนอซื้อที่คุ้ม
		var best_offer = null
		var best_gain := 0.0
		for a in p.assets:
			if a.offer == null: continue
			var need := 1.22 if a.kind == "speculation" else 1.28
			if a.offer.price > a.value * need and (a.offer.price - a.value) > best_gain:
				best_gain = a.offer.price - a.value; best_offer = a
		if best_offer != null and p.can_spend(int(cfg.action_cost.sell)):
			p.sell_asset(best_offer.id); continue

		# 2) ซื้อดีลที่ ROI ต่อทุนสูงสุด
		var best_deal = null
		var best_roi := 0.018
		for d in p.match_ref.deals:
			var price: float = d.price * 0.9 if p.job.perkId == "discount" else float(d.price)
			var down := price * (float(d.down) / float(d.price))
			var debt := price - down
			var cf := d.income * (price / float(d.price)) - debt * float(cfg.mortgage)
			var roi := 0.022 if d.kind == "speculation" else cf / maxf(1.0, down)
			if p.cash - down > p.get_total_expenses() * 0.5 and debt <= p.get_credit_left() and roi > best_roi:
				best_roi = roi; best_deal = d
		if best_deal != null and p.can_spend(p.action_cost(int(cfg.action_cost.deal))):
			p.close_deal(best_deal.id); continue

		# 3) ลงทุนกับตัวเองช่วงต้นเกม
		if p.phase == 1 and p.study_level < 2 and p.match_ref.month < 20 \
				and p.cash > p.salary * 2.5 and p.can_spend(int(cfg.action_cost.study)):
			if p.study().ok: continue
		# 4) เงินตึง → งานเสริม
		if p.cash < p.get_total_expenses() * 2 and not p.retired and p.side_used < 3 \
				and p.can_spend(int(cfg.action_cost.side)):
			if p.side_job().ok: continue
		if p.match_ref.deals.size() < 10 and p.can_spend(int(cfg.action_cost.scout)):
			if p.scout().ok: continue
		if p.health < 78 and p.can_spend(int(cfg.action_cost.exercise)):
			if p.exercise().ok: continue
		if not p.retired and p.side_used < 3 and p.can_spend(int(cfg.action_cost.side)):
			if p.side_job().ok: continue
		if p.can_spend(int(cfg.action_cost.rest)):
			if p.rest().ok: continue
		break
	p.hours = 0
