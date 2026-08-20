extends Node
## WQAudio — autoload ตัวเดียวของโปรเจกต์ (ลงทะเบียนใน project.godot)
##
## ที่ต้องเป็น autoload: เสียงคลิกต้องเรียกได้จากทุก widget ถ้าเป็นโหนดใน Main.tscn
## ทุกวิดเจ็ตจะต้องไต่ get_node ขึ้นไปหาพ่อ ซึ่งเปราะและผิดสไตล์ที่วิดเจ็ตทุกตัวในเกมนี้
## เป็นอิสระจากกัน (bind ของใครของมัน)
##
## **สองเลน — ห้ามปนกัน:**
##   เหตุการณ์ของเกม → มาจากสัญญาณเท่านั้น ไม่มี API ให้ ui/ สั่งยิง (กฎเดียวกับ world/city/vfx.gd)
##   เสียง UI ล้วน   → widget เรียก WQAudio.ui("click") ได้ เฉพาะ id ใน WQBank.UI_IDS
## ถ้าปล่อยให้ ui/ ยิงเสียงเหตุการณ์เองได้ วันหนึ่งจะมีเสียง "ปิดดีลสำเร็จ" ดังตอนเงินไม่พอ
##
## เสียงดังเฉพาะของผู้เล่นที่ bind_player() ไว้ — บอทเรียกเมธอดชุดเดียวกันทั้งหมด
## และยิง `acted` เหมือนกันเป๊ะ (core ไม่เช็ก is_ai ให้) ถ้าฟังทุกคนจะได้ยินเสียงรัว
## ตลอดเวลาจนไม่มีความหมาย

const POOL := 8                  ## เสียงซ้อนกันได้ 8 ตัว พอสำหรับเกมที่ไม่มีอะไรยิงรัว
const COOLDOWN := 0.06           ## กันเสียงเดิมซ้อนตัวเองตอนกดปุ่มถี่ๆ (วินาที)
const SFX_DIR := "res://audio/sfx"
const SETTINGS := "user://settings.cfg"

var played: Array[String] = []   ## ประวัติการเล่น — audio_check ใช้ตรวจว่าสัญญาณไหนทำให้อะไรดัง
var muted := false

var _levels := {"Master": 1.0, "SFX": 1.0}
var _players: Array[AudioStreamPlayer] = []
var _cache := {}                 ## id -> AudioStream
var _last := {}                  ## id -> เวลาที่เล่นครั้งล่าสุด
var _next := 0
## "บันทึกว่าเล่นอะไร แต่ไม่ยิงเสียงจริง" — ไม่ใช่ "ไม่แตะเซิร์ฟเวอร์เสียง"
## ระดับเสียงยังลงบัสจริงเสมอ เพราะแผงปรับเสียงต้องทดสอบแบบ headless ได้
var _silent := false
var _match: WQMatch
var _player = null
var _was_critical := false       ## กันเสียงเตือนสุขภาพดังซ้ำทุกครั้งที่ changed


## headless ใช้ไดรเวอร์เสียง Dummy ที่ไม่คืน AudioStreamPlayback ให้เลย พอ play() จริง
## เอนจินจะฟ้อง "N ObjectDB instances were leaked at exit" ทุกครั้งที่จบสูท — เสียงฟ้องปลอม
## ที่กลบของจริงในผลรัน และไม่มีใครได้ยินเสียงนั้นอยู่แล้ว จึงบันทึกอย่างเดียวไม่ต้องยิง
## WQ_MUTE=1 ให้ผลเดียวกันตอนรันเกมแบบมีจอ — สำหรับคนที่อยากเปิดเกมทำงานอื่นไปเงียบๆ
func _ready() -> void:
	_silent = OS.get_environment("WQ_MUTE") != "" or DisplayServer.get_name() == "headless"
	_ensure_bus()
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_load_settings()


## headless เริ่มมาด้วยบัสเดียว (ตรวจแล้ว: bus_count = 1) จึงสร้างบัส SFX เองแทนการ
## พึ่ง default_bus_layout.tres — ได้ผลเหมือนกันทุกโหมดและเทสต์ headless ได้จริง
func _ensure_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0: return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")


# ========== ผูกกับเกม ==========

func bind(match_ref: WQMatch) -> void:
	if _match == match_ref: return
	if _match != null:
		if _match.month_ended.is_connected(_on_month_ended):
			_match.month_ended.disconnect(_on_month_ended)
		if _match.disaster_started.is_connected(_on_disaster):
			_match.disaster_started.disconnect(_on_disaster)
		if _match.player_finished.is_connected(_on_finished):
			_match.player_finished.disconnect(_on_finished)
		if _match.match_over.is_connected(_on_over):
			_match.match_over.disconnect(_on_over)
	_match = match_ref
	if _match != null:
		_match.month_ended.connect(_on_month_ended)
		_match.disaster_started.connect(_on_disaster)
		_match.player_finished.connect(_on_finished)
		_match.match_over.connect(_on_over)


func bind_player(player) -> void:
	if _player == player: return
	if _player != null:
		if _player.acted.is_connected(_on_acted): _player.acted.disconnect(_on_acted)
		if _player.deal_closed.is_connected(_on_deal): _player.deal_closed.disconnect(_on_deal)
		if _player.changed.is_connected(_on_changed): _player.changed.disconnect(_on_changed)
	_player = player
	_was_critical = false
	if _player != null:
		_player.acted.connect(_on_acted)
		_player.deal_closed.connect(_on_deal)
		_player.changed.connect(_on_changed)


func _on_acted(kind: String) -> void:
	var id: String = String(WQBank.FROM_ACTED.get(kind, ""))
	if id != "": _play(id)


func _on_deal(_deal: Dictionary) -> void:
	_play("deal_closed")


## เงินเดือนออกดังเฉพาะเดือนที่เหลือเก็บเป็นบวก — เกณฑ์เดียวกับที่ vfx.gd ใช้
## เดือนที่ติดลบแล้วมีเสียงเหรียญจะสอนผู้เล่นผิดว่าเดือนนี้ผ่านไปด้วยดี
func _on_month_ended(_month: int) -> void:
	_play("month_end")
	if _player == null: return
	if _player.get_total_income() - _player.get_total_expenses() > 0.0: _play("payday")


func _on_disaster(_def: Dictionary) -> void:
	_play("disaster")


func _on_finished(p) -> void:
	if p == _player: _play("win")


func _on_over() -> void:
	if _player != null and int(_player.phase) < 3: _play("lose")


## เตือนสุขภาพ **ครั้งเดียวตอนข้ามเข้าโซนวิกฤต** ไม่ใช่ทุกครั้งที่ changed ยิง
## `changed` ยิงหลายสิบครั้งต่อเดือน ถ้าเล่นทุกครั้งจะกลายเป็นเสียงหอนไม่หยุด
func _on_changed() -> void:
	if _player == null: return
	var crit: bool = float(_player.health) < 40.0
	if crit and not _was_critical: _play("health_low")
	_was_critical = crit


# ========== เลน UI ==========

## เสียงที่ widget เรียกเองได้ — เฉพาะ id ใน WQBank.UI_IDS เท่านั้น
## เหตุการณ์ของเกมต้องมาจากสัญญาณ ไม่ใช่จากที่นี่
func ui(id: String) -> void:
	if not WQBank.UI_IDS.has(id):
		push_warning("WQAudio.ui(\"%s\") — ไม่ใช่เสียงเลน UI ต้องมาจากสัญญาณ" % id)
		return
	_play(id)


## เครื่องมือฟังเสียงทีละตัวจาก terminal:  WQ_SFX=<id> godot --path .
## **ห้ามเรียกจากโค้ดเกม** — มันเล่นได้ทุก id รวมถึงเสียงเหตุการณ์ จึงล็อกไว้ให้ทำงาน
## เฉพาะตอนที่รันด้วย WQ_SFX ซึ่งเป็นโหมดฟังเสียงล้วนๆ ไม่มีเกมเดินอยู่ข้างหลัง
## (มีเมธอดนี้แทนที่จะให้ ui/main.gd เรียก _play() ตรงๆ เพราะ _play เป็นของภายใน
## ถ้าเปิดให้เรียกได้ กฎสองเลนข้างบนก็ไม่เหลืออะไรบังคับ)
func preview(id: String) -> void:
	if OS.get_environment("WQ_SFX") == "": return
	_play(id)


# ========== ระดับเสียง ==========

func set_level(bus: String, v: float) -> void:
	if not _levels.has(bus): return
	_levels[bus] = clampf(v, 0.0, 1.0)
	_apply_levels()
	_save_settings()


func get_level(bus: String) -> float:
	return float(_levels.get(bus, 1.0))


func set_muted(v: bool) -> void:
	muted = v
	_apply_levels()
	_save_settings()


func _apply_levels() -> void:
	for bus in _levels:
		var idx := AudioServer.get_bus_index(String(bus))
		if idx < 0: continue
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(_levels[bus]), 0.0001)))
		AudioServer.set_bus_mute(idx, muted)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		_levels["Master"] = float(cfg.get_value("audio", "master", 1.0))
		_levels["SFX"] = float(cfg.get_value("audio", "sfx", 1.0))
		muted = bool(cfg.get_value("audio", "muted", false))
	_apply_levels()


## เก็บแยกจากไฟล์เซฟโดยตั้งใจ — เซฟมี 6 ช่อง ถ้าเก็บระดับเสียงไว้ในเซฟ
## เสียงจะเปลี่ยนไปมาทุกครั้งที่ผู้เล่นโหลดคนละช่อง
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "master", _levels["Master"])
	cfg.set_value("audio", "sfx", _levels["SFX"])
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS)


# ========== เล่นจริง ==========

func _play(id: String) -> void:
	if muted: return
	if not WQBank.SPEC.has(id): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -99.0)) < COOLDOWN: return
	_last[id] = now
	played.append(id)
	if _silent or _players.is_empty(): return

	var st := _stream(id)
	if st == null: return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.play()


## โหลดไฟล์ที่อบไว้ · ถ้าไฟล์หาย ตกกลับไปสังเคราะห์สดให้เกมยังมีเสียง
## (เกิดได้ตอนที่คนเพิ่ง clone repo แล้วยังไม่ได้รัน --import)
func _stream(id: String) -> AudioStream:
	if _cache.has(id): return _cache[id]
	var path := "%s/%s.wav" % [SFX_DIR, id]
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else WQSynth.stream(WQBank.SPEC[id])
	_cache[id] = st
	return st
