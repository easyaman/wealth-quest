class_name WQAudio
extends Node
## WQAudio — ระบบเสียงตัวเดียวของโปรเจกต์ (autoload `WQAudioBoot` ใน project.godot)
##
## ที่ต้องเป็น autoload: เสียงคลิกต้องเรียกได้จากทุก widget ถ้าเป็นโหนดใน Main.tscn
## ทุกวิดเจ็ตจะต้องไต่ get_node ขึ้นไปหาพ่อ ซึ่งเปราะและผิดสไตล์ที่วิดเจ็ตทุกตัวในเกมนี้
## เป็นอิสระจากกัน (bind ของใครของมัน)
##
## **ทำไม API ถึงเป็น static ทั้งชุด แล้ว autoload ถึงชื่อ `WQAudioBoot` ไม่ใช่ `WQAudio`:**
## โหมด `--script` ที่สูททุกตัวใน sim/ ใช้ **ไม่ลงทะเบียนชื่อ autoload เป็นตัวระบุส่วนกลาง**
## (ตรวจแล้ว: โหนดอยู่ใน tree จริง แต่โค้ดที่เขียน `WQAudio.ui()` คอมไพล์ไม่ผ่านทั้งชุด
## แปลว่าถ้าใช้ชื่อ autoload ตรงๆ ui/ ทุกไฟล์จะพัง headless พร้อมกันหมด) ส่วนชื่อที่มาจาก
## `class_name` ลงทะเบียนให้ทุกโหมด — autoload จึงเหลือหน้าที่เดียวคือพาโหนดตัวจริงเข้า tree
## แล้วฝากไว้ที่ `inst` ให้ฟังก์ชัน static เรียกใช้ (ตัวเล่นเสียงต้องมีพ่อแม่ถึงจะ play() ได้)
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
const HISTORY := 256          ## เก็บประวัติการเล่นย้อนหลังแค่นี้พอ
const COOLDOWN := 0.06           ## กันเสียงเดิมซ้อนตัวเองตอนกดปุ่มถี่ๆ (วินาที)
const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"
const FADE := 0.8                ## วินาทีที่ใช้เฟดไขว้ตอนสลับเพลง

## ที่ไฟล์ตั้งค่าเป็น static var ไม่ใช่ const: สูทต้องเปลี่ยนทางไปไฟล์ทดสอบได้ ไม่งั้นรัน
## audio_check ทีเดียวระดับเสียงที่นักพัฒนาตั้งไว้บนเครื่องตัวเองก็หายทุกครั้ง
## (กติกาเดียวกับ `WQSave.dir` ที่ flow_check เปลี่ยนทางอยู่แล้ว)
static var settings_path := "user://settings.cfg"

static var inst: WQAudio         ## โหนดจริงใน tree — autoload ตั้งให้ตอน _ready()

static var played: Array[String] = []  ## ประวัติการเล่น — audio_check ใช้ตรวจว่าสัญญาณไหนทำให้อะไรดัง
static var muted := false

static var _levels := {"Master": 1.0, "SFX": 1.0, "Music": 1.0}
static var _players: Array[AudioStreamPlayer] = []
static var _cache := {}          ## id -> AudioStream
static var _last := {}           ## id -> เวลาที่เล่นครั้งล่าสุด
static var _next := 0
## "บันทึกว่าเล่นอะไร แต่ไม่ยิงเสียงจริง" — ไม่ใช่ "ไม่แตะเซิร์ฟเวอร์เสียง"
## ระดับเสียงยังลงบัสจริงเสมอ เพราะแผงปรับเสียงต้องทดสอบแบบ headless ได้
static var _silent := false
static var _match: WQMatch
static var _player = null
static var _was_critical := false       ## กันเสียงเตือนสุขภาพดังซ้ำทุกครั้งที่ changed

static var music_now := ""       ## id ของเพลงที่ควรกำลังดัง — "" = ไม่มี (เทสต์อ่านตัวนี้)
static var music_switches := 0   ## นับจำนวนครั้งที่ "เปลี่ยนเพลงจริง" — เทสต์ใช้จับการสั่งซ้ำ
static var _music: Array[AudioStreamPlayer] = []
static var _music_at := 0        ## ตัวเล่นที่เป็นตัวหลักตอนนี้
static var _music_cache := {}
static var _music_tween: Tween


## headless ใช้ไดรเวอร์เสียง Dummy ที่ไม่คืน AudioStreamPlayback ให้เลย พอ play() จริง
## เอนจินจะฟ้อง "N ObjectDB instances were leaked at exit" ทุกครั้งที่จบสูท — เสียงฟ้องปลอม
## ที่กลบของจริงในผลรัน และไม่มีใครได้ยินเสียงนั้นอยู่แล้ว จึงบันทึกอย่างเดียวไม่ต้องยิง
## WQ_MUTE=1 ให้ผลเดียวกันตอนรันเกมแบบมีจอ — สำหรับคนที่อยากเปิดเกมทำงานอื่นไปเงียบๆ
func _ready() -> void:
	inst = self
	_silent = OS.get_environment("WQ_MUTE") != "" or DisplayServer.get_name() == "headless"
	## ต้องสร้างบัสทั้งสองก่อนลูปสร้างตัวเล่นด้านล่าง ไม่งั้นตัวเล่นจะไปเกาะบัส
	## ที่ยังไม่มี (bus ที่ไม่มีอยู่ตอนตั้ง .bus จะเงียบๆ ตกกลับไปที่ "Master")
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for _i in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		add_child(mp)
		_music.append(mp)
	_load_settings()


## headless เริ่มมาด้วยบัสเดียว (ตรวจแล้ว: bus_count = 1) จึงสร้างบัสเองแทนการ
## พึ่ง default_bus_layout.tres — ได้ผลเหมือนกันทุกโหมดและเทสต์ headless ได้จริง
static func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0: return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, "Master")


# ========== ผูกกับเกม ==========

static func bind(match_ref: WQMatch) -> void:
	if _match == match_ref: return
	if _match != null:
		if _match.month_ended.is_connected(inst._on_month_ended):
			_match.month_ended.disconnect(inst._on_month_ended)
		if _match.disaster_started.is_connected(inst._on_disaster):
			_match.disaster_started.disconnect(inst._on_disaster)
		if _match.player_finished.is_connected(inst._on_finished):
			_match.player_finished.disconnect(inst._on_finished)
		if _match.match_over.is_connected(inst._on_over):
			_match.match_over.disconnect(inst._on_over)
	_match = match_ref
	if _match != null:
		_match.month_ended.connect(inst._on_month_ended)
		_match.disaster_started.connect(inst._on_disaster)
		_match.player_finished.connect(inst._on_finished)
		_match.match_over.connect(inst._on_over)


static func bind_player(player) -> void:
	if _player == player: return
	if _player != null:
		if _player.acted.is_connected(inst._on_acted): _player.acted.disconnect(inst._on_acted)
		if _player.deal_closed.is_connected(inst._on_deal): _player.deal_closed.disconnect(inst._on_deal)
		if _player.changed.is_connected(inst._on_changed): _player.changed.disconnect(inst._on_changed)
	_player = player
	_was_critical = false
	if _player != null:
		_player.acted.connect(inst._on_acted)
		_player.deal_closed.connect(inst._on_deal)
		_player.changed.connect(inst._on_changed)


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
static func ui(id: String) -> void:
	if not WQBank.UI_IDS.has(id):
		push_warning("WQAudio.ui(\"%s\") — ไม่ใช่เสียงเลน UI ต้องมาจากสัญญาณ" % id)
		return
	_play(id)


## เครื่องมือฟังเสียงทีละตัวจาก terminal:  WQ_SFX=<id> godot --path .
## **ห้ามเรียกจากโค้ดเกม** — มันเล่นได้ทุก id รวมถึงเสียงเหตุการณ์ จึงล็อกไว้ให้ทำงาน
## เฉพาะตอนที่รันด้วย WQ_SFX ซึ่งเป็นโหมดฟังเสียงล้วนๆ ไม่มีเกมเดินอยู่ข้างหลัง
## (มีเมธอดนี้แทนที่จะให้ ui/main.gd เรียก _play() ตรงๆ เพราะ _play เป็นของภายใน
## ถ้าเปิดให้เรียกได้ กฎสองเลนข้างบนก็ไม่เหลืออะไรบังคับ)
static func preview(id: String) -> void:
	if OS.get_environment("WQ_SFX") == "": return
	_play(id)


# ========== เลนเพลง ==========

## เปลี่ยนเพลงพื้นหลังด้วยการเฟดไขว้ · **สั่งเพลงที่ดังอยู่แล้วต้องไม่ทำอะไรเลย**
## `_refresh_music()` ถูกเรียกทุกครั้งที่สถานะเปลี่ยน ซึ่งหลายสิบครั้งต่อเดือน
## ถ้าไม่กันตรงนี้ เพลงจะเริ่มใหม่ตลอดเวลาจนฟังไม่ได้เลย
static func play_music(id: String) -> void:
	if id == music_now: return
	if not WQMusic.TRACKS.has(id): return
	music_now = id
	music_switches += 1
	if _silent or _music.size() < 2: return

	var from := _music[_music_at]
	_music_at = (_music_at + 1) % _music.size()
	var to := _music[_music_at]
	to.stream = _music_stream(id)
	to.volume_db = linear_to_db(0.0001)
	to.play()

	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	_music_tween = inst.create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(to, "volume_db", 0.0, FADE)
	_music_tween.tween_property(from, "volume_db", linear_to_db(0.0001), FADE)
	_music_tween.chain().tween_callback(from.stop)


static func stop_music() -> void:
	music_now = ""
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	for p in _music:
		p.stop()


## ไฟล์เพลงที่ import มาได้ `loop_mode = 0` เสมอ (ตรวจแล้วกับ Godot 4.7.1) จุดลูปจึงต้อง
## ตั้งจากโค้ด และต้อง `duplicate()` ก่อน ไม่งั้นไปแก้ตัวที่ทั้งโปรเจกต์แคชร่วมกันอยู่
## ถ้าไฟล์หาย ตกกลับไปเรียบเรียงสดให้เกมยังมีเพลง (เพิ่ง clone แล้วยังไม่ได้ --import)
static func _music_stream(id: String) -> AudioStream:
	if _music_cache.has(id): return _music_cache[id]
	var path := "%s/%s.wav" % [MUSIC_DIR, id]
	var st: AudioStream
	if ResourceLoader.exists(path):
		var w: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * float(w.mix_rate)))
		st = w
	else:
		st = WQMusic.stream(id)
	_music_cache[id] = st
	return st


# ========== ระดับเสียง ==========

static func set_level(bus: String, v: float) -> void:
	if not _levels.has(bus): return
	_levels[bus] = clampf(v, 0.0, 1.0)
	_apply_levels()
	_save_settings()


static func get_level(bus: String) -> float:
	return float(_levels.get(bus, 1.0))


static func set_muted(v: bool) -> void:
	muted = v
	_apply_levels()
	_save_settings()


static func _apply_levels() -> void:
	for bus in _levels:
		var idx := AudioServer.get_bus_index(String(bus))
		if idx < 0: continue
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(_levels[bus]), 0.0001)))
		AudioServer.set_bus_mute(idx, muted)


static func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		_levels["Master"] = float(cfg.get_value("audio", "master", 1.0))
		_levels["SFX"] = float(cfg.get_value("audio", "sfx", 1.0))
		_levels["Music"] = float(cfg.get_value("audio", "music", 1.0))
		muted = bool(cfg.get_value("audio", "muted", false))
	_apply_levels()


## เก็บแยกจากไฟล์เซฟโดยตั้งใจ — เซฟมี 6 ช่อง ถ้าเก็บระดับเสียงไว้ในเซฟ
## เสียงจะเปลี่ยนไปมาทุกครั้งที่ผู้เล่นโหลดคนละช่อง
static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("audio", "master", _levels["Master"])
	cfg.set_value("audio", "sfx", _levels["SFX"])
	cfg.set_value("audio", "music", _levels["Music"])
	cfg.set_value("audio", "muted", muted)
	cfg.save(settings_path)


# ========== เล่นจริง ==========

static func _play(id: String) -> void:
	if muted: return
	if not WQBank.SPEC.has(id): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -99.0)) < COOLDOWN: return
	_last[id] = now
	played.append(id)
	## เกมหนึ่งตายาวหลายพันเสียง ถ้าเก็บไว้หมดรายการนี้จะโตไปเรื่อยๆ ตลอดเซสชัน
	## เก็บแค่ท้ายๆ พอ — มีไว้ให้เทสต์อ่านว่าสัญญาณไหนทำให้อะไรดัง ไม่ใช่ประวัติทั้งเกม
	if played.size() > HISTORY: played = played.slice(played.size() - HISTORY)
	if _silent or _players.is_empty(): return

	var st := _stream(id)
	if st == null: return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.play()


## โหลดไฟล์ที่อบไว้ · ถ้าไฟล์หาย ตกกลับไปสังเคราะห์สดให้เกมยังมีเสียง
## (เกิดได้ตอนที่คนเพิ่ง clone repo แล้วยังไม่ได้รัน --import)
static func _stream(id: String) -> AudioStream:
	if _cache.has(id): return _cache[id]
	var path := "%s/%s.wav" % [SFX_DIR, id]
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else WQSynth.stream(WQBank.SPEC[id])
	_cache[id] = st
	return st
