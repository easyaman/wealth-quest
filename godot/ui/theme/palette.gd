class_name WQPalette
extends RefCounted
## พาเลตสีกลางของทั้งเกม — ที่เดียวที่นิยามสีได้ (ART-DIRECTION ข้อ 2.4)
##
## กฎ: สีของตัวละคร/อาคาร/พาหนะ **ห้ามใช้ MONEY / TIME / HEALTH เป็นสีหลัก**
## เพราะสามสีนี้ถูกจองไว้บอกสถานะ ถ้าเอาไปทาของในฉากผู้เล่นจะอ่านผิด
##
## สีชุดนี้ถูก bake เป็น world/materials/palette.png ด้วย world/tools/palette_bake.gd
## เมชทุกชิ้นในเกมใช้แผ่นเดียวกันนี้ → เปลี่ยนสีทั้งเกมได้จากไฟล์นี้ไฟล์เดียว

const BG_DEEP := Color("0a1420")        ## พื้นหลัง UI (ตรงกับ main.gd เดิม)
const BG_SCENE_TOP := Color("1b2d5b")   ## gradient ฉากโชว์ — บน
const BG_SCENE_BOT := Color("3d5ba9")   ## gradient ฉากโชว์ — ล่าง

const MONEY := Color("f2b233")          ## เงินสด ดีล Payday
const MONEY_DARK := Color("b87a12")     ## หนี้ ดอกเบี้ย
const TIME := Color("4fc3f7")           ## แถบเวลา ชั่วโมงบนปุ่ม
const HEALTH := Color("f06292")         ## แถบสุขภาพ
const DANGER := Color("e53935")         ## ภัยพิบัติ ล้มละลาย
const WIN := Color("66bb6a")            ## ชนะ ผลตอบแทนบวก

const NEUTRAL_1 := Color("f5f1e8")
const NEUTRAL_2 := Color("c9c2b4")
const NEUTRAL_3 := Color("8b8578")
const NEUTRAL_4 := Color("4a463f")
const NEUTRAL_5 := Color("23211d")

const ACCENT_WOOD := Color("7a3b2e")    ## ของ "แพง/พรีเมียม"
const ACCENT_STEEL := Color("3b4a5c")   ## ของ "ใช้งาน/เครื่องจักร"

## เพิ่มตอน Sprint C — ฉากเมืองต้องมีต้นไม้และน้ำท่วม แต่เขียว/ฟ้าที่มีอยู่ถูกจองความหมายไว้แล้ว
## (WIN = ผลตอบแทนบวก · TIME = แถบเวลา) ถ้าเอาสองสีนั้นไปทาต้นไม้กับน้ำ ผู้เล่นจะอ่านฉากผิด
## จึงเป็นสีหม่นกว่าคู่ของมันชัดเจน — ต้องยังดูเป็นใบไม้/น้ำได้ แต่ไม่แย่งความหมาย
const FOLIAGE := Color("4e7a52")        ## ใบไม้ พุ่มไม้ (หม่นกว่า WIN)
const WATER := Color("2f6d8f")          ## น้ำท่วม สระว่ายน้ำ (หม่นกว่า TIME)

## ลำดับในแผ่น palette.png — ห้ามสลับลำดับหลังจากมี .glb ที่ map UV ไว้แล้ว
## เพราะ UV ของเมชชี้ไปที่ "ช่องที่เท่าไหร่" ไม่ใช่ชี้ที่ "สีอะไร"
const SLOTS: Array[StringName] = [
	&"bg_deep", &"bg_scene_top", &"bg_scene_bot",
	&"money", &"money_dark", &"time", &"health", &"danger", &"win",
	&"neutral_1", &"neutral_2", &"neutral_3", &"neutral_4", &"neutral_5",
	&"accent_wood", &"accent_steel",
	&"foliage", &"water",
]

const SLOT_COUNT := 32                  ## เผื่อช่องว่างไว้เติมสีใหม่โดยไม่ขยับ UV เดิม
const TEX_WIDTH := 256
const TEX_HEIGHT := 16


static func by_name(slot: StringName) -> Color:
	match slot:
		&"bg_deep": return BG_DEEP
		&"bg_scene_top": return BG_SCENE_TOP
		&"bg_scene_bot": return BG_SCENE_BOT
		&"money": return MONEY
		&"money_dark": return MONEY_DARK
		&"time": return TIME
		&"health": return HEALTH
		&"danger": return DANGER
		&"win": return WIN
		&"neutral_1": return NEUTRAL_1
		&"neutral_2": return NEUTRAL_2
		&"neutral_3": return NEUTRAL_3
		&"neutral_4": return NEUTRAL_4
		&"neutral_5": return NEUTRAL_5
		&"accent_wood": return ACCENT_WOOD
		&"accent_steel": return ACCENT_STEEL
		&"foliage": return FOLIAGE
		&"water": return WATER
	push_error("WQPalette: ไม่รู้จักช่องสี '%s'" % slot)
	return Color.MAGENTA


## จุด U บนแผ่น palette สำหรับช่องสีนี้ — ใช้ตอนปั้นเมชให้ UV ชี้มาที่กลางช่องพอดี
## (กลางช่อง ไม่ใช่ขอบ เพราะขอบจะเพี้ยนเมื่อมี mipmap หรือ filter)
static func slot_u(slot: StringName) -> float:
	var i := SLOTS.find(slot)
	if i < 0:
		push_error("WQPalette: ไม่รู้จักช่องสี '%s'" % slot)
		return 0.0
	return (float(i) + 0.5) / float(SLOT_COUNT)
