/* =========================================================
   WEALTH QUEST — Core Engine v4
   - อาชีพอิงชีวิตจริง (ไทย) + สกุลเงินบาท
   - ทอยเต๋าตอนเริ่ม = โอกาสในชีวิต
   - ระบบเวลาจริง 720 ชม./เดือน (นอน/งาน/เดินทาง/กิน/ธุระ → เหลือเป็นเวลาว่าง)
   - ระบบสุขภาพ ที่แปลงเป็น "ประสิทธิภาพเวลา" โดยตรง
   - เรียนเพิ่มเติมเพื่อขึ้นเงินเดือนแบบไม่พองไลฟ์สไตล์
   - ภัยพิบัติระดับโต๊ะ กระทบทุกคนพร้อมกันเป็นระยะ
   - Phase 2: ทอยเต๋าสุ่มเป้าหมายชีวิตใหม่หลังออกจากสนามแข่งหนู
   - SOLO (สู้บอท) / MULTI (หลายคน) ตลาดกลางเดียวกัน
   ========================================================= */

function makeRng(seed) {
  const f = function () {
    let a = f.s;
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    f.s = a;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  f.s = seed >>> 0;
  return f;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

/* =========================================================
   ระบบเวลา — หนึ่งเดือน = 30 วัน = 720 ชั่วโมง
   ========================================================= */
const HOURS_PER_MONTH = 720;
const CHORES_HOURS = 40;

const SLEEP_OPTIONS = [
  { h: 5, hours: 150, health: -4.5, penalty: 0.22, label: 'นอน 5 ชม./คืน', note: 'ได้เวลาว่างเยอะสุด แต่สุขภาพพังเร็วและประสิทธิภาพตกหนัก' },
  { h: 6, hours: 180, health: -2.0, penalty: 0.10, label: 'นอน 6 ชม./คืน', note: 'พอไหวช่วงสั้นๆ แต่ประสิทธิภาพเริ่มตก' },
  { h: 7, hours: 210, health: 0.0, penalty: 0.00, label: 'นอน 7 ชม./คืน', note: 'ค่ามาตรฐาน — สมดุลระหว่างเวลากับสุขภาพ' },
  { h: 8, hours: 240, health: 1.5, penalty: 0.00, label: 'นอน 8 ชม./คืน', note: 'เสียเวลาว่าง 30 ชม./เดือน แลกกับสุขภาพที่ดีขึ้นเรื่อยๆ' }
];

const FOOD_OPTIONS = [
  { id: 'fast', icon: '🍔', hours: 21, costMul: 1.30, health: -2.5, label: 'เดลิเวอรี / ฟาสต์ฟู้ด',
    note: 'เร็วที่สุด (0.7 ชม./วัน) แต่ค่าอาหารแพงขึ้น 30% และสุขภาพลดเร็ว' },
  { id: 'street', icon: '🍜', hours: 30, costMul: 1.00, health: -0.5, label: 'ข้าวแกง / สตรีทฟู้ด',
    note: 'ทางสายกลางแบบคนไทย (1 ชม./วัน) — ค่ามาตรฐาน' },
  { id: 'cook', icon: '🥗', hours: 75, costMul: 0.75, health: 2.5, label: 'ทำกินเอง / อาหารคลีน',
    note: 'ถูกที่สุด (−25%) และสุขภาพดีที่สุด แต่กิน 2.5 ชม./วัน = 75 ชม./เดือน' }
];

const COST = {
  deal: 18, sell: 12, loan: 8, scout: 14, side: 30, study: 40, exercise: 13, rest: 10
};
const ACTION_INFO = {
  deal: 'ดูทรัพย์ + เจรจา + ธนาคาร + ทำสัญญา',
  sell: 'หาผู้ซื้อ + โอนกรรมสิทธิ์',
  loan: 'เตรียมเอกสาร + ยื่นกู้',
  scout: 'เดินตลาด ดูทำเล หาข้อมูล',
  side: 'งานเสริม/OT — ได้เงินก้อนเดียวจบ',
  study: 'เรียน/อัปสกิล — ขึ้นเงินเดือนถาวรโดยรายจ่ายไม่โต',
  exercise: 'ออกกำลังกาย — สุขภาพ +5',
  rest: 'พักผ่อน/อยู่กับครอบครัว — สุขภาพ +2.5 ลดโอกาสเรื่องร้าย'
};

/* =========================================================
   แผนที่เมือง — ทุกการกระทำผูกกับสถานที่ และการเดินทางกินเวลาจริง
   x = ตำแหน่งบนถนนสายหลัก (0–100) ใช้คำนวณระยะทาง
   ========================================================= */
const TRAVEL_RATE = 0.11;          // ชั่วโมงต่อ 1 หน่วยระยะ เมื่อใช้ขนส่งสาธารณะ

const PLACES = [
  { id: 'home',   x: 50, icon: '🏠', name: 'บ้าน', color: '#5ac97a',
    desc: 'ตั้งค่าการนอน ทำกินเอง พักผ่อน — และเป็นจุดเริ่มต้นของทุกเดือน',
    acts: ['sleep', 'food', 'rest', 'homework', 'homestudy', 'mobile'] },
  { id: 'office', x: 30, icon: '🏢', name: 'ออฟฟิศ / ที่ทำงาน', color: '#c95a5a',
    desc: 'งานประจำหักเวลาอัตโนมัติอยู่แล้ว มาที่นี่เพื่อรับ OT เพิ่ม',
    acts: ['ot'] },
  { id: 'bank',   x: 62, icon: '🏦', name: 'ธนาคาร', color: '#5a8fc9',
    desc: 'กู้เงิน ชำระหนี้ ซื้อ-ขายกองทุนและตราสารหนี้',
    acts: ['loan', 'repay', 'fund'] },
  { id: 'estate', x: 14, icon: '🏬', name: 'ศูนย์อสังหาฯ & ตลาดธุรกิจ', color: '#c9962e',
    desc: 'ดีลอสังหาฯ ธุรกิจ และธุรกิจจิ๋วทั้งหมดอยู่ที่นี่ ต้องมาดูของจริง',
    acts: ['estate', 'scout'] },
  { id: 'gold',   x: 74, icon: '💍', name: 'ร้านทอง & ของสะสม', color: '#e0b84a',
    desc: 'ทองคำ พระเครื่อง นาฬิกา คริปโต — ของเก็งกำไรทั้งหมด',
    acts: ['gold'] },
  { id: 'cowork', x: 42, icon: '💻', name: 'Co-working Space', color: '#7fd8ff',
    desc: 'รับงาน freelance ได้เงินดีกว่า OT 25% และเรียนได้ด้วย',
    acts: ['freelance', 'study'] },
  { id: 'school', x: 22, icon: '🎓', name: 'สถาบันสอน', color: '#c8a6ff',
    desc: 'เรียนแบบมีอาจารย์ — คืบหน้าเร็วกว่าเรียนออนไลน์',
    acts: ['study'] },
  { id: 'gym',    x: 56, icon: '🏋️', name: 'ฟิตเนส', color: '#7ee08a',
    desc: 'ออกกำลังกาย มีแพ็กเกจให้เลือกตามงบและเวลา',
    acts: ['gym'] },
  { id: 'mall',   x: 84, icon: '🛒', name: 'ห้างสรรพสินค้า', color: '#ffb27a',
    desc: 'ซื้อพาหนะและอุปกรณ์ที่ช่วยประหยัดเวลา — ของที่ "ซื้อเวลา" ได้',
    acts: ['shop'] },
  { id: 'resort', x: 96, icon: '🏨', name: 'โรงแรม & รีสอร์ต', color: '#ff9ad1',
    desc: 'พักผ่อนจริงจัง ฟื้นสุขภาพเยอะ และลดโอกาสเกิดเรื่องร้าย',
    acts: ['resort'] }
];
const PLACE = id => PLACES.find(p => p.id === id);

/* ---------------- พาหนะ ---------------- */
const VEHICLES = [
  { id: 'public', icon: '🚌', name: 'ขนส่งสาธารณะ', price: 0, downPct: 0, upkeep: 0,
    factor: 1.00, hp: 0, note: 'ค่าเริ่มต้น — ฟรี แต่ช้าที่สุด และเบียดเสียดทุกวัน' },
  { id: 'moto', icon: '🛵', name: 'มอเตอร์ไซค์', price: 55000, downPct: 0.20, upkeep: 900,
    factor: 0.55, hp: -0.6, note: 'ถูกและเร็วขึ้นเท่าตัว แต่ตากแดดตากฝน สุขภาพลดนิดหน่อย' },
  { id: 'usedcar', icon: '🚗', name: 'รถยนต์มือสอง', price: 350000, downPct: 0.20, upkeep: 3800,
    factor: 0.42, hp: 0, note: 'จุดคุ้มค่าที่สุดสำหรับคนที่เดินทางเยอะ' },
  { id: 'newcar', icon: '🚙', name: 'รถยนต์ใหม่', price: 900000, downPct: 0.20, upkeep: 7500,
    factor: 0.34, hp: 0.5, note: 'สบายขึ้น เร็วขึ้นอีกนิด — แต่ค่าผ่อนเริ่มกินสัดส่วนใหญ่' },
  { id: 'luxury', icon: '🏎️', name: 'รถหรู', price: 2500000, downPct: 0.25, upkeep: 19000,
    factor: 0.30, hp: 1.0, note: '⚠️ เร็วกว่ารถใหม่แค่ 12% แต่แพงกว่า 3 เท่า — ลองคิดดูว่าคุ้มไหม' }
];

/* ---------------- อุปกรณ์ (ซื้อครั้งเดียว ใช้ตลอด) ---------------- */
const DEVICES = [
  { id: 'smartphone', icon: '📱', name: 'สมาร์ตโฟน + แอปธนาคาร', price: 25000, upkeep: 500,
    note: 'ทำธุรกรรมธนาคารได้จากที่บ้าน — กู้ ชำระหนี้ ซื้อกองทุน ไม่ต้องเดินทางอีกเลย' },
  { id: 'laptop', icon: '💻', name: 'โน้ตบุ๊ก + เน็ตบ้าน', price: 45000, upkeep: 900,
    note: 'เรียนออนไลน์และรับ freelance ที่บ้านได้ (freelance ได้เงิน 80% ของที่ co-working)' }
];

/* ---------------- แพ็กเกจฟิตเนส / พักผ่อน ---------------- */
const GYM_PACKS = [
  { id: 'daily', icon: '🎫', name: 'จ่ายรายครั้ง', cost: 350, hours: 13, hp: 5,
    note: 'ไม่ผูกมัด แต่แพงกว่าถ้าไปบ่อย' },
  { id: 'monthly', icon: '💪', name: 'แพ็กเกจรายเดือน', cost: 1600, hours: 11, hp: 5, monthly: true,
    note: 'จ่ายครั้งเดียวใช้ได้ทั้งเดือน + มีอุปกรณ์พร้อม เลยเสียเวลาน้อยลง' },
  { id: 'trainer', icon: '🏅', name: 'เทรนเนอร์ส่วนตัว', cost: 6500, hours: 10, hp: 8.5, monthly: true,
    note: 'ได้ผลที่สุดต่อชั่วโมง — คุ้มถ้าเวลาคุณมีค่ามากกว่าเงิน' }
];
const RESORT_PACKS = [
  { id: 'day', icon: '🌤️', name: 'เที่ยวใกล้บ้าน 1 วัน', cost: 2500, hours: 14, hp: 7, shield: 0 },
  { id: 'weekend', icon: '🏖️', name: 'รีสอร์ตสุดสัปดาห์', cost: 14000, hours: 34, hp: 19, shield: 0.15 },
  { id: 'abroad', icon: '✈️', name: 'ทริปต่างประเทศ', cost: 65000, hours: 100, hp: 38, shield: 0.35 }
];

/* =========================================================
   อาชีพ — work/commute = ชั่วโมงต่อเดือน, food = ค่าอาหารฐาน
   ========================================================= */
const JOBS = [
  { id: 'cleaner', tier: 1, name: 'พนักงานทำความสะอาด', icon: '🧹',
    salary: 11000, fixed: 6000, food: 2600, cash: 22000, work: 208, commute: 39, health: 70, sleepNeed: 8,
    debts: [], perkId: 'frugal', perk: 'ชินกับการประหยัด: เหตุการณ์ร้ายและค่ารักษาเสียเงินน้อยลงมาก',
    note: 'ตัวเลขเล็กแต่สัดส่วนดี และมีเวลาว่างเยอะกว่าอาชีพเงินเดือนสูง' },
  { id: 'convstore', tier: 1, name: 'พนักงานร้านสะดวกซื้อ', icon: '🏪',
    salary: 13500, fixed: 7360, food: 3200, cash: 25000, work: 234, commute: 30, health: 68, sleepNeed: 8,
    debts: [{ name: 'ผ่อนมือถือ', balance: 12000, rate: 0.02 }],
    perkId: 'hustle', perk: 'ชินกับกะดึก: งานเสริมได้เงินมากกว่า 50% และทนงานหนักได้ดีกว่า',
    note: 'เข้ากะดึกทำให้สุขภาพเริ่มต้นต่ำ ต้องดูแลตัวเองเป็นพิเศษ' },
  { id: 'rider', tier: 1, name: 'ไรเดอร์ส่งอาหาร', icon: '🛵',
    salary: 16500, fixed: 8675, food: 3800, cash: 20000, work: 260, commute: 0, health: 65, sleepNeed: 8,
    debts: [{ name: 'ผ่อนมอเตอร์ไซค์', balance: 35000, rate: 0.015 }],
    perkId: 'quick', perk: 'รู้จักทุกซอย: ปิดดีลใช้เวลาน้อยลง 20% และคนอื่นแย่งดีลจากคุณยากขึ้น',
    note: 'ไม่มีเวลาเดินทางเพราะงานคือการเดินทาง — แต่ตากแดดตากฝนทุกวัน สุขภาพต่ำสุด' },

  { id: 'teacher', tier: 2, name: 'ครูโรงเรียนรัฐ', icon: '👩‍🏫',
    salary: 23000, fixed: 12680, food: 5000, cash: 40000, work: 198, commute: 33, health: 75, sleepNeed: 7,
    debts: [{ name: 'หนี้ กยศ.', balance: 180000, rate: 0.004 }],
    perkId: 'stable', perk: 'ข้าราชการ: ไม่ถูกเลิกจ้าง กู้สวัสดิการดอกถูก และมีประกันสุขภาพ (ค่ารักษาถูกลงครึ่ง)',
    note: 'มั่นคงที่สุด แต่เงินเดือนโตช้า — การเรียนเพิ่มเติมช่วยได้มาก' },
  { id: 'nurse', tier: 2, name: 'พยาบาลวิชาชีพ', icon: '👩‍⚕️',
    salary: 29000, fixed: 16000, food: 6400, cash: 45000, work: 220, commute: 33, health: 72, sleepNeed: 8,
    debts: [{ name: 'หนี้ กยศ.', balance: 150000, rate: 0.004 }],
    perkId: 'hustle', perk: 'ขึ้นเวร OT ได้: งานเสริมได้เงินมากกว่า 50% และรู้วิธีดูแลตัวเอง',
    note: 'แลกเวลาเป็นเงินเก่งที่สุด — แต่เวลาคือสิ่งที่ต้องใช้หาทรัพย์สิน' },
  { id: 'technician', tier: 2, name: 'ช่างเทคนิค', icon: '🔧',
    salary: 25000, fixed: 12840, food: 5200, cash: 35000, work: 192, commute: 36, health: 76, sleepNeed: 7,
    debts: [{ name: 'ผ่อนรถกระบะ', balance: 220000, rate: 0.008 }],
    perkId: 'discount', perk: 'ซ่อมเองได้ทุกอย่าง: ซื้อทรัพย์สินถูกลง 10%',
    note: 'สุขภาพดี เวลาพอใช้ ต้นทุนต่ำกว่าคนอื่นทุกดีล' },
  { id: 'accountant', tier: 2, name: 'พนักงานบัญชี', icon: '💼',
    salary: 27000, fixed: 14590, food: 6000, cash: 50000, work: 198, commute: 44, health: 72, sleepNeed: 7,
    debts: [{ name: 'หนี้บัตรเครดิต', balance: 45000, rate: 0.018 }],
    perkId: 'insight', perk: 'อ่านงบเป็น: เห็นแนวโน้มตลาดล่วงหน้า และเก็งกำไรแม่นกว่า',
    note: 'หนี้บัตรเครดิตดอก 21%/ปี คือศัตรูอันดับหนึ่ง ปิดก่อนเลย' },
  { id: 'police', tier: 2, name: 'ตำรวจ', icon: '👮',
    salary: 26000, fixed: 13900, food: 5600, cash: 30000, work: 216, commute: 36, health: 74, sleepNeed: 8,
    debts: [{ name: 'เงินกู้สหกรณ์', balance: 250000, rate: 0.006 }],
    perkId: 'stable', perk: 'ข้าราชการ: ไม่ถูกเลิกจ้าง กู้สวัสดิการดอกถูก และมีประกันสุขภาพ (ค่ารักษาถูกลงครึ่ง)',
    note: 'หนี้สหกรณ์ดอกถูก — หนี้ไม่ได้แย่เสมอถ้าเอาไปสร้างรายได้' },

  { id: 'engineer', tier: 3, name: 'วิศวกรโรงงาน', icon: '👷',
    salary: 46000, fixed: 23650, food: 9000, cash: 90000, work: 198, commute: 44, health: 75, sleepNeed: 7,
    debts: [{ name: 'ผ่อนรถยนต์', balance: 550000, rate: 0.007 }],
    perkId: 'credit', perk: 'เครดิตดี: วงเงินกู้สูงกว่าปกติ 50% และดอกเบี้ยถูกกว่า',
    note: 'ใช้เลเวอเรจได้ดีที่สุด — แต่ดอกเบี้ยคือรายจ่าย เส้นชัยจะขยับหนี' },
  { id: 'programmer', tier: 3, name: 'โปรแกรมเมอร์', icon: '💻',
    salary: 58000, fixed: 31000, food: 12000, cash: 120000, work: 176, commute: 22, health: 68, sleepNeed: 7,
    debts: [], perkId: 'hustle', perk: 'รับ freelance ได้: งานเสริมได้เงินมากกว่า 50% และเรียนออนไลน์ได้เร็วกว่า',
    note: 'WFH ทำให้เดินทางน้อยและมีเวลาเยอะ แต่นั่งทั้งวัน สุขภาพเริ่มต้นไม่ดี' },
  { id: 'cafeowner', tier: 3, name: 'เจ้าของร้านกาแฟ', icon: '☕',
    salary: 42000, fixed: 21600, food: 8400, cash: 70000, work: 260, commute: 26, health: 70, sleepNeed: 8,
    debts: [{ name: 'เงินกู้เปิดร้าน', balance: 400000, rate: 0.010 }],
    perkId: 'discount', perk: 'สายต่อรอง: ซื้อทรัพย์สินถูกลง 10%',
    note: '"รายได้จากร้านที่คุณต้องยืนขายเอง" ยังไม่ใช่ Passive Income — และกินเวลา 260 ชม./เดือน' },
  { id: 'salesmgr', tier: 3, name: 'ผู้จัดการฝ่ายขาย', icon: '📊',
    salary: 52000, fixed: 27100, food: 10500, cash: 80000, work: 220, commute: 48, health: 68, sleepNeed: 7,
    debts: [{ name: 'ผ่อนบ้าน + รถ', balance: 900000, rate: 0.006 }],
    perkId: 'credit', perk: 'เครดิตดี: วงเงินกู้สูงกว่าปกติ 50% และดอกเบี้ยถูกกว่า',
    note: 'รถติด + สังสรรค์กับลูกค้า = สุขภาพและเวลาหายไปพร้อมกัน' },

  { id: 'doctor', tier: 4, name: 'แพทย์', icon: '🩺',
    salary: 125000, fixed: 58800, food: 22000, cash: 200000, work: 264, commute: 36, health: 72, sleepNeed: 8,
    debts: [{ name: 'หนี้เรียน + ผ่อนบ้าน', balance: 3200000, rate: 0.006 }],
    perkId: 'credit', perk: 'เครดิตดี: วงเงินกู้สูงกว่าปกติ 50% + รักษาตัวเองได้ (ค่ารักษาถูกลงครึ่ง)',
    note: 'ทำงาน 264 ชม./เดือน — เวลาว่างน้อยที่สุดในเกม เงินเยอะแต่ไม่มีเวลาไปหาดีล' },
  { id: 'lawyer', tier: 4, name: 'ทนายความ', icon: '⚖️',
    salary: 95000, fixed: 46600, food: 17000, cash: 150000, work: 248, commute: 44, health: 70, sleepNeed: 7,
    debts: [{ name: 'ผ่อนบ้าน + รถ', balance: 2400000, rate: 0.006 }],
    perkId: 'insight', perk: 'อ่านสัญญาขาด: เห็นแนวโน้มตลาดล่วงหน้า และเก็งกำไรแม่นกว่า',
    note: 'รายได้สูง แต่ภาระผ่อนสูงตาม เส้นชัยอยู่ไกลกว่าครูเสียอีก' },
  { id: 'pilot', tier: 4, name: 'นักบินพาณิชย์', icon: '✈️',
    salary: 155000, fixed: 78250, food: 28000, cash: 250000, work: 240, commute: 40, health: 74, sleepNeed: 8,
    debts: [{ name: 'ผ่อนบ้านหรู', balance: 4500000, rate: 0.0055 }],
    perkId: 'none', perk: 'ไม่มีความสามารถพิเศษ — มีแค่เงินเดือนก้อนโตและไลฟ์สไตล์ที่โตตาม',
    note: '⚠️ ยากที่สุดในเกม ทั้งที่เงินเดือนสูงสุด — บ้าน 4.5 ล้านดันเส้นชัยหนีไปไกลมาก' },
  { id: 'executive', tier: 4, name: 'ผู้บริหารบริษัท', icon: '🏢',
    salary: 115000, fixed: 56000, food: 22000, cash: 180000, work: 242, commute: 44, health: 66, sleepNeed: 7,
    debts: [{ name: 'ผ่อนบ้าน + รถหรู', balance: 3000000, rate: 0.006 }],
    perkId: 'stable', perk: 'ตำแหน่งมั่นคง: ไม่ถูกเลิกจ้าง และกู้ดอกเบี้ยถูกกว่า',
    note: 'ความเครียดสูงสุด สุขภาพเริ่มต้นแย่สุด — ตำแหน่งยิ่งสูง ไลฟ์สไตล์ยิ่งบังคับให้จ่าย' }
];

/* ---------------- ทอยเต๋าเริ่มเกม ---------------- */
const ROLL_TABLE = {
  1: { count: 2, tiers: [1], bonusHours: 45, label: 'เกิดมาแทบไม่มีทางเลือก' },
  2: { count: 3, tiers: [1, 2], bonusHours: 30, label: 'ทางเลือกจำกัด' },
  3: { count: 4, tiers: [1, 2], bonusHours: 20, label: 'พอมีทางให้เลือกบ้าง' },
  4: { count: 5, tiers: [1, 2, 3], bonusHours: 10, label: 'โอกาสระดับกลาง' },
  5: { count: 6, tiers: [1, 2, 3, 4], bonusHours: 0, label: 'โอกาสดี' },
  6: { count: 7, tiers: [1, 2, 3, 4], bonusHours: 0, label: 'เกิดมาพร้อมทางเลือกเต็มมือ' }
};

function rollStart(seed, forcedRoll) {
  const rng = makeRng((seed || 1) * 2654435761 >>> 0);
  const roll = forcedRoll || (1 + Math.floor(rng() * 6));
  const t = ROLL_TABLE[roll];
  const pool = JOBS.filter(j => t.tiers.includes(j.tier));
  const picked = [];
  if (roll >= 4) {
    const top = Math.max(...t.tiers);
    const tops = pool.filter(j => j.tier === top);
    picked.push(tops[Math.floor(rng() * tops.length)]);
  }
  const rest = pool.filter(j => !picked.includes(j)).sort(() => rng() - 0.5);
  while (picked.length < t.count && rest.length) picked.push(rest.pop());
  picked.sort((a, b) => a.tier - b.tier || a.salary - b.salary);
  return { roll, jobs: picked, bonusHours: t.bonusHours, label: t.label };
}

const BOT_NAMES = ['พี่เอ๋ (บอท)', 'เจ๊หมวย (บอท)', 'น้องบีม (บอท)', 'ลุงวิรัช (บอท)'];

/* ---------------- เป้าหมายชีวิต Phase 2 ---------------- */
const DREAMS = [
  { roll: 1, icon: '🏝️', name: 'บ้านพักตากอากาศริมทะเล', costMul: 48, passiveMul: 1.20,
    desc: 'ซื้อบ้านริมทะเลไว้ให้ครอบครัวมารวมตัวกันทุกปี',
    why: 'ใช้เงินก้อนใหญ่ แต่ไม่ได้เพิ่มภาระรายเดือนมาก' },
  { roll: 2, icon: '🌍', name: 'พาครอบครัวเที่ยวรอบโลก + กองทุนการศึกษาลูก', costMul: 30, passiveMul: 1.70,
    desc: 'ออกเดินทางหนึ่งปีเต็มโดยไม่ต้องห่วงเรื่องเงิน',
    why: 'เงินก้อนน้อยกว่า แต่ต้องมีรายได้ต่อเดือนมั่นคงกว่ามาก เพราะจะไม่อยู่ดูแลอะไรเลยทั้งปี' },
  { roll: 3, icon: '🎓', name: 'ตั้งมูลนิธิให้ทุนการศึกษาเด็กบ้านเกิด', costMul: 38, passiveMul: 2.10,
    desc: 'สร้างมูลนิธิที่จ่ายทุนต่อเนื่องทุกปี ไม่ใช่บริจาคครั้งเดียวจบ',
    why: 'ต้องการกระแสเงินสดมากที่สุด — เพราะมูลนิธิต้องเลี้ยงตัวเองได้ตลอดไป' },
  { roll: 4, icon: '🏥', name: 'สร้างศูนย์สุขภาพชุมชนในบ้านเกิด', costMul: 70, passiveMul: 1.30,
    desc: 'ลงทุนก้อนใหญ่ที่สุด เพื่อสิ่งที่อยู่ได้นานกว่าตัวเรา',
    why: 'ความฝันที่แพงที่สุดในตาราง — ต้องสะสมความมั่งคั่งจริงจัง' },
  { roll: 5, icon: '🏎️', name: 'คอลเลกชันรถในฝัน + บ้านหลังใหญ่', costMul: 59, passiveMul: 1.10,
    desc: 'ของที่อยากได้มาตั้งแต่เด็ก ตอนนี้ซื้อได้แล้ว',
    why: 'ราคาแพง แต่ขอรายได้ต่อเดือนน้อยที่สุด — ความฝันแบบบริโภคล้วนๆ' },
  { roll: 6, icon: '🚀', name: 'เปิดบริษัทของตัวเอง ส่งต่อให้ลูกหลาน', costMul: 43, passiveMul: 1.90,
    desc: 'จากคนที่ทำงานให้เงิน กลายเป็นคนที่สร้างงานให้คนอื่น',
    why: 'สมดุลระหว่างเงินก้อนกับกระแสเงินสด และเป็นความฝันที่ต่อยอดได้อีก' }
];

/* ---------------- ดีล ---------------- */
const MORTGAGE = 0.005;
const DEAL_POOL = [
  { kind: 'micro', icon: '💡', names: ['ตู้กดน้ำหยอดเหรียญ 3 ตู้', 'รถเข็นขายกาแฟ', 'ร้านขายของออนไลน์', 'ปล่อยเช่ามอเตอร์ไซค์ 2 คัน', 'ตู้เติมเงินมือถือ 5 ตู้'],
    min: 20000, max: 140000, downPct: [1, 1], yield: [0.024, 0.045], vol: 0.15, w: 3.0 },
  { kind: 'business', icon: '🏪', names: ['แฟรนไชส์กาแฟหน้าปั๊ม', 'ร้านซักอบรีด', 'ตู้ซักผ้าหยอดเหรียญ 6 ตู้', 'ร้านชำในหมู่บ้าน', 'คาร์แคร์เล็ก'],
    min: 150000, max: 900000, downPct: [1, 1], yield: [0.020, 0.038], vol: 0.17, w: 2.4 },
  { kind: 'business', icon: '⚙️', names: ['ร้านอาหารตามสั่ง 20 โต๊ะ', 'คาเฟ่ย่านออฟฟิศ', 'โกดังให้เช่า', 'คลินิกความงาม', 'โรงงานผลิตเล็ก'],
    min: 1000000, max: 3500000, downPct: [1, 1], yield: [0.018, 0.033], vol: 0.19, w: 1.2 },
  { kind: 'realestate', icon: '🏢', names: ['คอนโดปล่อยเช่าใกล้ BTS', 'ห้องแถวย่านตลาด', 'ทาวน์เฮาส์ชานเมือง', 'หอพักนักศึกษา 6 ห้อง'],
    min: 600000, max: 2400000, downPct: [0.15, 0.25], yield: [0.0070, 0.0125], vol: 0.09, w: 2.2 },
  { kind: 'realestate', icon: '🏘️', names: ['อพาร์ตเมนต์ 12 ห้อง', 'ตึกแถว 3 ชั้นย่านค้าขาย', 'บ้านเดี่ยวปล่อยเช่า', 'ที่ดินเปล่าติดถนนใหญ่'],
    min: 3000000, max: 9000000, downPct: [0.18, 0.28], yield: [0.0068, 0.0120], vol: 0.11, w: 0.8 },
  { kind: 'speculation', icon: '💰', names: ['ทองคำแท่ง 10 บาท', 'คริปโตเหรียญใหม่', 'นาฬิกาสะสมมือสอง', 'พระเครื่ององค์ดัง', 'หุ้น IPO ตัวร้อน'],
    min: 30000, max: 600000, downPct: [1, 1], yield: [0, 0], vol: 0.34, w: 1.4 },
  { kind: 'fund', icon: '📈', names: ['กองทุนรวมหุ้นปันผล', 'พันธบัตรรัฐบาล', 'กอง REIT อสังหาฯ', 'หุ้นกู้บริษัทใหญ่'],
    min: 100000, max: 900000, downPct: [1, 1], yield: [0.005, 0.0078], vol: 0.05, w: 1.2 }
];
/* เงินดาวน์ที่ถูกที่สุดที่ตลาดสร้างได้ — ใช้เป็นพื้นของการันตี
   "ต้องมีของให้คนจนที่สุดซื้อได้" (GDD ข้อ 5.2) ต่ำกว่านี้ก็สร้างอะไรให้ไม่ได้อยู่ดี */
const CHEAPEST_DOWN = Math.min(...DEAL_POOL.map(t => Math.round(t.min * t.downPct[0])));

const BIG_DEALS = [
  { kind: 'realestate', icon: '🏨', names: ['อพาร์ตเมนต์ 40 ห้อง', 'โรงแรมบูทีค 20 ห้อง', 'โกดังโซนอุตสาหกรรม', 'คอมมูนิตี้มอลล์เล็ก'],
    min: 12000000, max: 40000000, downPct: [0.20, 0.30], yield: [0.0085, 0.0135], vol: 0.13, w: 1 },
  { kind: 'business', icon: '🏭', names: ['แฟรนไชส์ 5 สาขา', 'ปั๊มน้ำมันชุมชน', 'โรงงานแปรรูปอาหาร', 'บริษัทขนส่ง 20 คัน'],
    min: 8000000, max: 25000000, downPct: [1, 1], yield: [0.018, 0.031], vol: 0.21, w: 1 }
];
const MEGA_DEALS = [
  { kind: 'realestate', icon: '🏙️', names: ['คอนโดมิเนียมทั้งตึก', 'คอมมูนิตี้มอลล์', 'โรงแรมรีสอร์ตริมทะเล', 'อาคารสำนักงานให้เช่า', 'สนามกอล์ฟ'],
    downPct: [0.25, 0.35], yield: [0.0085, 0.0140], vol: 0.13 },
  { kind: 'business', icon: '🏢', names: ['เชนร้านอาหาร 20 สาขา', 'บริษัทโลจิสติกส์ระดับภูมิภาค', 'โรงงานส่งออก', 'บริษัทพลังงานแสงอาทิตย์', 'กองทุนส่วนบุคคล'],
    downPct: [1, 1], yield: [0.017, 0.029], vol: 0.20 }
];
const KIND_LABEL = { micro: 'ธุรกิจจิ๋ว', business: 'ธุรกิจ', realestate: 'อสังหาฯ', speculation: 'เก็งกำไร', fund: 'กองทุน/ตราสาร' };

/* ---------------- เหตุการณ์ส่วนตัว ---------------- */
const EVENTS = [
  { id: 'appliance', w: 8, text: 'แอร์/ตู้เย็นพัง ต้องซื้อใหม่', costMul: [0.15, 0.45] },
  { id: 'car', w: 7, text: 'รถเสีย ต้องเข้าอู่ด่วน', costMul: [0.20, 0.55] },
  { id: 'social', w: 6, text: 'งานแต่ง งานบวช งานศพ มารัวๆ เดือนเดียว', costMul: [0.08, 0.22] },
  { id: 'bonus', w: 7, text: 'ได้โบนัสประจำปี', gainMul: [0.6, 1.6] },
  { id: 'raise', w: 4, text: 'ได้เลื่อนขั้น ปรับเงินเดือนถาวร', raise: [0.06, 0.13] },
  { id: 'boom', w: 6, text: 'ตลาดอสังหาฯ/หุ้นคึกคัก ราคาสินทรัพย์พุ่ง', market: [0.05, 0.12] },
  { id: 'bust', w: 6, text: 'เศรษฐกิจชะลอตัว ราคาสินทรัพย์ร่วง', market: [-0.12, -0.05] },
  { id: 'child', w: 4, text: 'มีลูก! รายจ่ายเพิ่มถาวรและเวลาว่างหายไป', childMul: [0.10, 0.18], childHours: 35 },
  { id: 'layoff', w: 3, text: 'ถูกเลิกจ้าง/ปรับโครงสร้าง ขาดรายได้ 2 เดือน', downsize: 2 },
  { id: 'inherit', w: 3, text: 'ได้รับเงินก้อนจากที่บ้าน/มรดก', gainMul: [1.5, 4] },
  { id: 'sick_s', w: 6, health: true, text: 'ไข้หวัดใหญ่ นอนซม 3 วัน', costMul: [0.10, 0.30], hpCost: 4, timeCost: 24 },
  { id: 'sick_m', w: 4, health: true, text: 'ออฟฟิศซินโดรม/ปวดหลังเรื้อรัง ต้องทำกายภาพ', costMul: [0.25, 0.60], hpCost: 6, timeCost: 30 },
  { id: 'sick_l', w: 3, health: true, text: 'เจ็บป่วยหนักต้องนอนโรงพยาบาล', costMul: [0.6, 1.6], hpCost: 12, timeCost: 60 },
  { id: 'burnout', w: 3, health: true, text: 'หมดไฟ (Burnout) ทำอะไรก็ไม่เดิน', hpCost: 10, timeCost: 45 }
];
const EVENTS2 = [
  { w: 7, text: 'ภาษีที่ดินและสิ่งปลูกสร้างประเมินใหม่', costMul: [0.4, 1.2] },
  { w: 6, text: 'ญาติมาขอยืมเงินก้อนใหญ่ (ปฏิเสธไม่ลง)', costMul: [0.6, 1.8] },
  { w: 5, text: 'ถูกฟ้องร้องคดีธุรกิจ ต้องจ้างทนาย', costMul: [0.8, 2.2] },
  { w: 5, text: 'ผู้จัดการทรัพย์สินยักยอกเงิน', costMul: [0.5, 1.5] },
  { w: 7, text: 'ผังเมืองใหม่ประกาศ ทรัพย์สินขึ้นราคา', market: [0.06, 0.15] },
  { w: 6, text: 'ตลาดผันผวนหนัก ราคาสินทรัพย์ร่วง', market: [-0.15, -0.06] },
  { w: 6, text: 'ได้รับเงินปันผลพิเศษจากธุรกิจ', gainMul: [1.5, 4] },
  { w: 4, text: 'ลูกขอทุนเปิดธุรกิจ — รายจ่ายประจำเพิ่มถาวร', childMul: [0.06, 0.14] },
  { w: 5, text: 'ได้รางวัลนักธุรกิจแห่งปี — มีคนเสนอดีลดีๆ เข้ามา', bonusDeals: 2 },
  { w: 4, health: true, text: 'สุขภาพเริ่มฟ้อง — ต้องตรวจร่างกายละเอียด', costMul: [0.3, 0.8], hpCost: 6 }
];

/* ---------------- ภัยพิบัติ (กระทบทุกคน) ---------------- */
const DISASTERS = [
  { id: 'flood', icon: '🌊', name: 'น้ำท่วมใหญ่', dur: 3,
    desc: 'ธุรกิจหน้าร้านปิดยาว ทรัพย์สินเสียหาย',
    mods: { business: 0.5 }, cashCostMul: [0.8, 1.8], market: -0.07, hp: -4 },
  { id: 'plague', icon: '🦠', name: 'โรคระบาดระลอกใหม่', dur: 4,
    desc: 'ล็อกดาวน์ ธุรกิจบริการแทบไม่มีรายได้ และทุกคนสุขภาพแย่ลง',
    mods: { business: 0.35 }, cashCostMul: [0.3, 0.9], market: -0.10, hp: -12 },
  { id: 'crisis', icon: '📉', name: 'วิกฤตเศรษฐกิจ', dur: 4,
    desc: 'ราคาสินทรัพย์ดิ่ง ธนาคารหั่นวงเงินสินเชื่อครึ่งหนึ่ง',
    mods: { credit: 0.5 }, market: -0.22, hp: -3 },
  { id: 'rate', icon: '🏦', name: 'ดอกเบี้ยพุ่งแรง', dur: 6,
    desc: 'ค่าผ่อนทุกก้อนแพงขึ้น 45% — คนที่กู้เยอะเจ็บที่สุด',
    mods: { rate: 1.45 }, market: -0.05 },
  { id: 'quake', icon: '🏚️', name: 'แผ่นดินไหว', dur: 2,
    desc: 'อาคารเสียหาย ค่าซ่อมมหาศาล ผู้เช่าย้ายออก',
    mods: { realestate: 0.6 }, cashCostMul: [1.0, 2.2], market: -0.06, hp: -3 },
  { id: 'inflation', icon: '💸', name: 'ค่าครองชีพพุ่งกระฉูด', dur: 1,
    desc: 'ของแพงขึ้นทั้งกระดาน — รายจ่ายประจำเพิ่มถาวร',
    inflate: 0.08, hp: -2 },
  { id: 'fire', icon: '🔥', name: 'ไฟไหม้ย่านการค้า', dur: 4,
    desc: 'ธุรกิจของบางคนถูกไฟไหม้ ต้องปิดซ่อมยาว',
    burnAsset: true, cashCostMul: [0.4, 1.0], hp: -3 }
];

const fmt = n => Math.round(n).toLocaleString('en-US');
const fmtM = n => Math.abs(n) >= 1000000 ? (n / 1000000).toFixed(Math.abs(n) >= 10000000 ? 1 : 2) + ' ล้าน' : Math.round(n).toLocaleString('en-US');

/* =========================================================
   PLAYER
   ========================================================= */
class Player {
  constructor(match, opts) {
    const job = JOBS.find(j => j.id === opts.jobId) || JOBS[0];
    this.match = match;
    this.name = opts.name;
    this.isAI = !!opts.isAI;
    this.job = job;
    this.roll = opts.roll || 0;
    this.bonusHours = opts.bonusHours || 0;
    this.cash = job.cash;
    this.salary = job.salary;
    this.fixedExpenses = job.fixed;
    this.foodBase = job.food;
    this.childCost = 0;
    this.childHours = 0;
    this.assets = [];
    this.liabilities = job.debts.map(d => ({ ...d }));
    this.sleepIdx = 2;
    this.foodId = 'street';
    this.place = 'home';            // อยู่ที่ไหนตอนนี้
    this.travelUsed = 0;            // ชั่วโมงที่เสียไปกับการเดินทางเดือนนี้
    this.vehicle = 'public';
    this.devices = [];
    this.gymPack = null;            // แพ็กเกจฟิตเนสที่ซื้อไว้เดือนนี้
    this.shield = 0;                // โล่กันเหตุการณ์ร้ายจากการไปพักผ่อน
    this.health = job.health;
    this.timePenalty = 0;
    this.exerciseThisMonth = 0;
    this.restedThisMonth = false;
    this.sideUsed = 0;
    this.studyLevel = 0;
    this.studyProgress = 0;
    this.downsizeLeft = 0;
    this.bankrupt = false;
    this.finished = 0;
    this.phase = 1;
    this.dream = null;
    this.dreamDone = 0;
    this.retired = false;
    this.pendingDream = false;
    this.history = [];
    this.hours = this.hoursMax;
  }

  get rng() { return this.match.rng; }
  get sleep() { return SLEEP_OPTIONS[this.sleepIdx]; }
  get food() { return FOOD_OPTIONS.find(f => f.id === this.foodId); }

  get workHours() { return (this.retired || this.downsizeLeft > 0) ? 0 : this.job.work; }
  get commuteHours() {
    if (this.retired || this.downsizeLeft > 0) return 0;
    return Math.round(this.job.commute * this.travelFactor);
  }
  get committedHours() { return this.sleep.hours + this.workHours + this.commuteHours + this.food.hours + CHORES_HOURS + this.childHours; }
  get rawFreeHours() { return Math.max(0, HOURS_PER_MONTH - this.committedHours + this.bonusHours - this.timePenalty); }
  get veh() { return VEHICLES.find(v => v.id === this.vehicle) || VEHICLES[0]; }
  has(dev) { return this.devices.includes(dev); }
  get travelFactor() { return this.veh.factor; }
  /* ชั่วโมงเดินทางระหว่างสองสถานที่ */
  travelCost(toId, fromId) {
    const a = PLACE(fromId || this.place), b = PLACE(toId);
    if (!a || !b || a.id === b.id) return 0;
    return Math.max(1, Math.round(Math.abs(a.x - b.x) * TRAVEL_RATE * this.travelFactor));
  }
  /* ทำ action นี้ได้จากที่ไหนบ้าง (รวมทางลัดจากอุปกรณ์) */
  placeFor(act) {
    if (act === 'loan' || act === 'repay' || act === 'fund') {
      if (this.has('smartphone')) return this.place;      // ออนไลน์ได้ทุกที่
      return 'bank';
    }
    if (act === 'study') return this.has('laptop') ? this.place : 'school';
    if (act === 'freelance') return this.has('laptop') ? this.place : 'cowork';
    const p = PLACES.find(pl => pl.acts.includes(act));
    return p ? p.id : this.place;
  }
  canDoHere(act) {
    const need = this.placeFor(act);
    return need === this.place;
  }
  get sleepNeed() { return this.retired ? 7 : (this.job.sleepNeed || 7); }
  get sleepDebt() { return Math.max(0, this.sleepNeed - this.sleep.h); }   // นอนขาดกี่ชั่วโมง/คืน
  get efficiency() {
    const short = this.sleepDebt * 0.05;
    return clamp((0.40 + 0.60 * this.health / 100) * (1 - this.sleep.penalty - short), 0.28, 1.05);
  }
  get hoursMax() { return Math.max(0, Math.round(this.rawFreeHours * this.efficiency)); }
  cost(base) { return Math.round(base * (this.job.perkId === 'quick' && base === COST.deal ? 0.8 : 1)); }
  canSpend(h) { return this.hours >= h; }

  get foodCost() { return Math.round(this.foodBase * this.food.costMul); }
  get passiveIncome() {
    const m = this.match.mods;
    return this.assets.reduce((s, a) => {
      if (a.burned) return s;
      const k = (a.kind === 'business' || a.kind === 'micro') ? m.business : (a.kind === 'realestate' ? m.realestate : 1);
      return s + a.income * k;
    }, 0);
  }
  assetNet(a) {
    const m = this.match.mods;
    const k = (a.kind === 'business' || a.kind === 'micro') ? m.business : (a.kind === 'realestate' ? m.realestate : 1);
    return (a.burned ? 0 : a.income * k) - a.debt * MORTGAGE * m.rate;
  }
  get debtPayments() { return this.liabilities.reduce((s, d) => s + d.balance * d.rate, 0) * this.match.mods.rate; }
  get upkeepCost() {
    let u = this.veh.upkeep;
    for (const d of this.devices) { const dd = DEVICES.find(x => x.id === d); if (dd) u += dd.upkeep; }
    return u;
  }
  get totalExpenses() { return this.fixedExpenses + this.foodCost + this.childCost + this.upkeepCost + this.debtPayments; }
  get currentSalary() { return (this.retired || this.downsizeLeft > 0) ? 0 : this.salary; }
  get totalIncome() { return this.currentSalary + this.passiveIncome; }
  get monthlyCashflow() { return this.totalIncome - this.totalExpenses; }
  get totalDebt() { return this.liabilities.reduce((s, d) => s + d.balance, 0); }
  get assetValue() { return this.assets.reduce((s, a) => s + a.value * this.match.marketIndex * a.drift, 0); }
  get netWorth() { return this.cash + this.assetValue - this.totalDebt; }
  get freedomPct() { return Math.min(100, this.passiveIncome / Math.max(1, this.totalExpenses) * 100); }
  get creditLimit() {
    const base = (this.salary + this.passiveIncome) * 30 * this.match.mods.credit;
    return Math.round(base * (this.job.perkId === 'credit' ? 1.5 : 1));
  }
  get creditLeft() { return Math.max(0, this.creditLimit - this.totalDebt); }
  assetPrice(a) { return a.value * this.match.marketIndex * a.drift; }
  get healthLabel() {
    const h = this.health;
    if (h >= 85) return 'แข็งแรงมาก'; if (h >= 70) return 'ปกติดี';
    if (h >= 55) return 'เริ่มโทรม'; if (h >= 40) return 'ไม่ค่อยดี';
    if (h >= 25) return 'ย่ำแย่'; return 'วิกฤต';
  }
  get medFactor() {
    const p = this.job.perkId;
    return (p === 'stable' || this.job.id === 'doctor') ? 0.5 : (p === 'frugal' ? 0.6 : 1);
  }
  get studyNeed() { return 3 + this.studyLevel; }
  get dreamPct() { return this.dream ? Math.min(100, this.netWorth / this.dream.cost * 100) : 0; }
  get dreamPassivePct() { return this.dream ? Math.min(100, this.passiveIncome / this.dream.passiveReq * 100) : 0; }
  canClaimDream() { return this.phase === 2 && this.netWorth >= this.dream.cost && this.passiveIncome >= this.dream.passiveReq; }
  log(text, type) { this.match.log(text, type, this); }

  /* เดินทางไปสถานที่อื่น — กินเวลาจริง */
  travelTo(toId) {
    if (toId === this.place) return { ok: false, msg: 'อยู่ที่นี่อยู่แล้ว' };
    const h = this.travelCost(toId);
    if (!this.canSpend(h)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${h} ชม. ในการเดินทาง (เหลือ ${this.hours} ชม.)` };
    this.hours -= h; this.travelUsed += h;
    const from = PLACE(this.place), to = PLACE(toId);
    this.place = toId;
    if (!this.isAI) this.log(`${this.veh.icon} เดินทางจาก${from.name} → ${to.icon} ${to.name} (${h} ชม.)`, 'move');
    return { ok: true };
  }

  /* ซื้อพาหนะ — ดาวน์ + กู้ส่วนที่เหลือ */
  buyVehicle(id) {
    const v = VEHICLES.find(x => x.id === id);
    if (!v) return { ok: false, msg: 'ไม่พบพาหนะ' };
    if (this.place !== 'mall') return { ok: false, msg: 'ต้องไปดูรถที่ 🛒 ห้างสรรพสินค้า ก่อน' };
    if (v.id === this.vehicle) return { ok: false, msg: 'ใช้คันนี้อยู่แล้ว' };
    const cur = this.veh;
    if (VEHICLES.indexOf(v) < VEHICLES.indexOf(cur)) {
      // ขายคันเดิมทิ้ง (ได้คืน 55% ของราคาป้าย) แล้วลดระดับ
      this.cash += Math.round(cur.price * 0.55);
      this.vehicle = v.id;
      this.log(`ขาย ${cur.icon} ${cur.name} แล้วเปลี่ยนเป็น ${v.icon} ${v.name}`, 'sell');
      return { ok: true };
    }
    const down = Math.round(v.price * v.downPct) || v.price;
    const debt = v.price - down;
    if (this.cash < down) return { ok: false, msg: `เงินดาวน์ไม่พอ ต้องใช้ ${fmt(down)}฿` };
    if (debt > this.creditLeft) return { ok: false, msg: 'วงเงินกู้ไม่พอ' };
    if (cur.price > 0) this.cash += Math.round(cur.price * 0.5);   // เทิร์นคันเก่า
    this.cash -= down;
    if (debt > 0) this.liabilities.push({ name: 'ผ่อน' + v.name, balance: debt, rate: 0.007 });
    this.vehicle = v.id;
    this.log(`🛒 ซื้อ ${v.icon} ${v.name} — ดาวน์ ${fmt(down)}฿` + (debt ? ` ผ่อน ${fmtM(debt)}฿` : '') +
      ` • เวลาเดินทางเหลือ ${Math.round(v.factor * 100)}% และค่าใช้จ่ายเพิ่ม ${fmt(v.upkeep)}฿/เดือน`, 'buy');
    return { ok: true };
  }

  buyDevice(id) {
    const d = DEVICES.find(x => x.id === id);
    if (!d) return { ok: false, msg: 'ไม่พบอุปกรณ์' };
    if (this.place !== 'mall' && !this.has('smartphone'))
      return { ok: false, msg: 'ต้องไปที่ 🛒 ห้างสรรพสินค้า ก่อน' };
    if (this.has(id)) return { ok: false, msg: 'มีอยู่แล้ว' };
    if (this.cash < d.price) return { ok: false, msg: `เงินสดไม่พอ ต้องใช้ ${fmt(d.price)}฿` };
    this.cash -= d.price;
    this.devices.push(id);
    this.log(`🛒 ซื้อ ${d.icon} ${d.name} — ${d.note}`, 'buy');
    return { ok: true };
  }

  setSleep(i) {
    if (!this.canDoHere('sleep')) return { ok: false, msg: 'ตั้งค่าการนอนได้ที่บ้านเท่านั้น' };
    this.sleepIdx = clamp(i, 0, SLEEP_OPTIONS.length - 1); this.hours = Math.min(this.hours, this.hoursMax); return { ok: true };
  }
  setFood(id) {
    if (!this.canDoHere('food')) return { ok: false, msg: 'วางแผนอาหารได้ที่บ้านเท่านั้น' };
    if (FOOD_OPTIONS.some(f => f.id === id)) { this.foodId = id; this.hours = Math.min(this.hours, this.hoursMax); }
    return { ok: true };
  }

  actForKind(kind) { return kind === 'speculation' ? 'gold' : (kind === 'fund' ? 'fund' : 'estate'); }
  placeName(act) { const id = this.placeFor(act); const p = PLACE(id); return p ? p.icon + ' ' + p.name : ''; }
  needTravel(act) {
    const need = this.placeFor(act);
    return need === this.place ? null : { place: need, hours: this.travelCost(need) };
  }

  /* ---------- actions ---------- */
  closeDeal(dealId) {
    const h = this.cost(COST.deal);
    if (!this.canSpend(h)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${h} ชม. (เหลือ ${this.hours} ชม.)` };
    const M = this.match;
    const i = M.deals.findIndex(d => d.id === dealId);
    if (i < 0) return { ok: false, msg: 'ดีลนี้ถูกคนอื่นคว้าไปแล้ว' };
    const d = M.deals[i];
    const act = this.actForKind(d.kind);
    if (!this.canDoHere(act)) return { ok: false, msg: `ต้องไปที่ ${this.placeName(act)} ก่อน` };
    const price = this.job.perkId === 'discount' ? Math.round(d.price * 0.9) : d.price;
    const down = Math.round(price * (d.down / d.price));
    const debt = price - down;
    if (this.cash < down) return { ok: false, msg: 'เงินสดไม่พอจ่ายเงินดาวน์' };
    if (debt > this.creditLeft) return { ok: false, msg: 'วงเงินกู้ไม่พอ ต้องลดหนี้ก่อน' };
    this.hours -= h; this.cash -= down;
    const income = Math.round(d.income * (price / d.price));
    if (debt > 0) this.liabilities.push({ name: 'สินเชื่อ: ' + d.name, balance: debt, rate: MORTGAGE, linked: d.id });
    this.assets.push({ id: d.id, kind: d.kind, icon: d.icon, name: d.name, value: price, cost: down, debt, income, vol: d.vol, drift: 1, offer: null, sick: 0, burned: 0 });
    M.deals.splice(i, 1);
    const net = income - debt * MORTGAGE;
    this.log(`ซื้อ ${d.icon} ${d.name} (${h} ชม.) — ลงเงิน ${fmtM(down)}฿` + (debt ? ` กู้เพิ่ม ${fmtM(debt)}฿` : '') + ` → ${net >= 0 ? '+' : ''}${fmt(net)}฿/เดือน`, 'buy');
    return { ok: true };
  }

  sellAsset(assetId) {
    if (!this.canSpend(COST.sell)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.sell} ชม.` };
    const i = this.assets.findIndex(a => a.id === assetId);
    if (i < 0) return { ok: false, msg: 'ไม่พบทรัพย์สิน' };
    const a = this.assets[i];
    const sAct = this.actForKind(a.kind);
    if (!this.canDoHere(sAct)) return { ok: false, msg: `ต้องไปที่ ${this.placeName(sAct)} ก่อนถึงจะขายได้` };
    this.hours -= COST.sell;
    const price = a.offer ? a.offer.price : this.assetPrice(a) * 0.94;
    const proceeds = price - a.debt;
    this.cash += proceeds;
    const li = this.liabilities.findIndex(l => l.linked === a.id);
    if (li >= 0) this.liabilities.splice(li, 1);
    this.assets.splice(i, 1);
    const gain = price - a.value;
    this.log(`ขาย ${a.icon} ${a.name} ได้ ${fmtM(price)}฿ (${gain >= 0 ? 'กำไร' : 'ขาดทุน'} ${fmtM(Math.abs(gain))}฿)`, gain >= 0 ? 'sell' : 'bad');
    return { ok: true };
  }

  takeLoan(amount) {
    if (!this.canDoHere('loan')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('loan')} ก่อน (หรือซื้อ 📱 สมาร์ตโฟนเพื่อทำออนไลน์)` };
    if (!this.canSpend(COST.loan)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.loan} ชม.` };
    amount = Math.round(amount / 10000) * 10000;
    if (amount <= 0) return { ok: false, msg: 'จำนวนไม่ถูกต้อง' };
    if (amount > this.creditLeft) return { ok: false, msg: 'เกินวงเงินกู้' };
    this.hours -= COST.loan;
    const soft = (this.job.perkId === 'credit' || this.job.perkId === 'stable');
    const rate = soft ? 0.011 : 0.015;
    this.liabilities.push({ name: 'สินเชื่อส่วนบุคคล', balance: amount, rate });
    this.cash += amount;
    this.log(`กู้เงิน ${fmtM(amount)}฿ (ดอกเบี้ย ${(rate * 1200).toFixed(0)}%/ปี)`, 'debt');
    return { ok: true };
  }

  /* ชำระหนี้ได้ทั้งก้อนหรือบางส่วน — ไม่เสียเวลา (เป็นแค่การโอนเงิน) */
  repayDebt(index, amount) {
    if (!this.canDoHere('repay')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('repay')} ก่อน (หรือซื้อ 📱 สมาร์ตโฟน)` };
    const d = this.liabilities[index];
    if (!d) return { ok: false, msg: 'ไม่พบหนี้' };
    if (this.cash <= 0) return { ok: false, msg: 'ไม่มีเงินสดเหลือ' };
    amount = Math.floor(Math.min(amount, d.balance, this.cash));
    if (amount <= 0) return { ok: false, msg: 'จำนวนไม่ถูกต้อง' };
    const saved = amount * d.rate * this.match.mods.rate;
    this.cash -= amount; d.balance -= amount;
    const closed = d.balance < 1;
    this.log(`ชำระหนี้ "${d.name}" ${fmtM(amount)}฿` +
      (closed ? ' — <b>ปิดหนี้ก้อนนี้เรียบร้อย!</b>' : ` — เหลือ ${fmtM(d.balance)}฿`) +
      ` • ประหยัดดอกเบี้ยได้ ${fmt(saved)}฿/เดือน ตลอดไป`, 'debt');
    if (closed) this.liabilities.splice(index, 1);
    return { ok: true };
  }

  /* งานเสริมมีสองแบบ: OT ที่ออฟฟิศ กับ freelance ที่ co-working (หรือที่บ้านถ้ามีโน้ตบุ๊ก) */
  sideJob(kind) {
    kind = kind || 'ot';
    if (kind === 'ot') {
      if (this.retired) return { ok: false, msg: 'ลาออกจากงานประจำแล้ว รับ OT ไม่ได้' };
      if (this.downsizeLeft > 0) return { ok: false, msg: 'ตอนนี้ไม่มีงานประจำอยู่' };
    }
    if (!this.canDoHere(kind === 'ot' ? 'ot' : 'freelance'))
      return { ok: false, msg: `ต้องไปที่ ${this.placeName(kind === 'ot' ? 'ot' : 'freelance')} ก่อน` };
    if (!this.canSpend(COST.side)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.side} ชม.` };
    if (this.sideUsed >= 3) return { ok: false, msg: 'รับงานเสริมได้สูงสุด 3 ครั้ง/เดือน' };
    this.hours -= COST.side; this.sideUsed++;
    const mul = this.job.perkId === 'hustle' ? 1.5 : 1;
    /* freelance ที่ co-working ได้ดีกว่า OT 25% · ทำที่บ้านได้ 80% ของ co-working */
    let rateMul = 1;
    if (kind === 'freelance') rateMul = this.place === 'cowork' ? 1.25 : 1.0;
    const gain = Math.round(this.salary * (0.16 + this.rng() * 0.10) * mul * rateMul);
    this.cash += gain;
    if (!this.isAI) this.log(`${kind === 'ot' ? '⏱️ รับ OT' : '💻 รับงาน freelance'} ${COST.side} ชม. ได้ ${fmt(gain)}฿`, 'work');
    return { ok: true };
  }

  scout() {
    if (!this.canDoHere('scout')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('scout')} ก่อน` };
    if (!this.canSpend(COST.scout)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.scout} ชม.` };
    this.hours -= COST.scout;
    for (let i = 0; i < 2; i++) {
      if (this.match.deals.length >= 11) this.match.deals.shift();
      this.match.deals.push(this.match.makeDeal());
    }
    if (!this.isAI) this.log('ออกดูทำเล/หาข้อมูล พบดีลใหม่ 2 รายการเข้าตลาด', 'info');
    return { ok: true };
  }

  study() {
    if (!this.canDoHere('study')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('study')} ก่อน (หรือซื้อ 💻 โน้ตบุ๊กเพื่อเรียนออนไลน์)` };
    if (!this.canSpend(COST.study)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.study} ชม.` };
    const online = this.place !== 'school';
    const fee = Math.round(this.salary * (online ? 0.35 : 0.55));
    if (this.cash < fee) return { ok: false, msg: `ค่าเรียน ${fmt(fee)}฿ — เงินสดไม่พอ` };
    this.hours -= COST.study; this.cash -= fee;
    this.studyProgress += (this.job.perkId === 'hustle' ? 1.5 : 1) * (online ? 0.7 : 1);
    if (this.studyProgress >= this.studyNeed) {
      this.studyProgress = 0; this.studyLevel++;
      this.salary = Math.round(this.salary * 1.13);
      this.log(`🎓 เรียนจบคอร์ส! เงินเดือนขึ้น 13% เป็น ${fmt(this.salary)}฿ — และรายจ่ายไม่ได้ขึ้นตาม ต่างจากการเลื่อนขั้นแบบปกติ`, 'good');
    } else if (!this.isAI) {
      this.log(`📚 เรียนเพิ่มเติม (${COST.study} ชม. + ${fmt(fee)}฿) — ความคืบหน้า ${Math.floor(this.studyProgress)}/${this.studyNeed}`, 'info');
    }
    return { ok: true };
  }

  /* ออกกำลังกายที่ฟิตเนส — เลือกแพ็กเกจได้ */
  exercise(packId) {
    if (!this.canDoHere('gym')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('gym')} ก่อน` };
    const pk = GYM_PACKS.find(g => g.id === (packId || this.gymPack || 'daily')) || GYM_PACKS[0];
    const owned = pk.monthly && this.gymPack === pk.id;
    const fee = owned ? 0 : pk.cost;
    if (!this.canSpend(pk.hours)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${pk.hours} ชม.` };
    if (this.cash < fee) return { ok: false, msg: `เงินสดไม่พอ ต้องจ่าย ${fmt(fee)}฿` };
    this.hours -= pk.hours; this.cash -= fee; this.exerciseThisMonth++;
    if (pk.monthly && !owned) this.gymPack = pk.id;
    const gain = pk.hp + (this.job.id === 'nurse' ? 1 : 0);
    this.health = clamp(this.health + gain, 0, 100);
    if (!this.isAI) this.log(`🏋️ ${pk.icon} ${pk.name} — ${pk.hours} ชม.` + (fee ? ` จ่าย ${fmt(fee)}฿` : ' (ใช้แพ็กเกจที่ซื้อไว้)') +
      ` → สุขภาพ +${gain} (ตอนนี้ ${Math.round(this.health)})`, 'good');
    return { ok: true };
  }

  /* ไปพักผ่อนที่โรงแรม/รีสอร์ต */
  vacation(packId) {
    if (!this.canDoHere('resort')) return { ok: false, msg: `ต้องไปที่ ${this.placeName('resort')} ก่อน` };
    const pk = RESORT_PACKS.find(r => r.id === packId) || RESORT_PACKS[0];
    if (!this.canSpend(pk.hours)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${pk.hours} ชม.` };
    if (this.cash < pk.cost) return { ok: false, msg: `เงินสดไม่พอ ต้องจ่าย ${fmt(pk.cost)}฿` };
    this.hours -= pk.hours; this.cash -= pk.cost;
    this.health = clamp(this.health + pk.hp, 0, 100);
    this.shield = Math.max(this.shield, pk.shield);
    this.restedThisMonth = true;
    if (!this.isAI) this.log(`${pk.icon} ${pk.name} — ${pk.hours} ชม. จ่าย ${fmt(pk.cost)}฿ → สุขภาพ +${pk.hp}` +
      (pk.shield ? ` และลดโอกาสเกิดเรื่องร้าย ${Math.round(pk.shield * 100)}%` : ''), 'good');
    return { ok: true };
  }

  rest() {
    if (!this.canDoHere('rest')) return { ok: false, msg: `ต้องกลับ ${this.placeName('rest')} ก่อน` };
    if (!this.canSpend(COST.rest)) return { ok: false, msg: `เวลาไม่พอ ต้องใช้ ${COST.rest} ชม.` };
    this.hours -= COST.rest;
    this.health = clamp(this.health + 2.5, 0, 100);
    this.restedThisMonth = true;
    if (!this.isAI) this.log(`🛋️ พักผ่อน/อยู่กับครอบครัว ${COST.rest} ชม. — สุขภาพ +2.5 และลดโอกาสเกิดเรื่องร้าย`, 'good');
    return { ok: true };
  }

  /* ---------- Phase 2 ---------- */
  /* ทอยเต๋าสุ่มความฝัน — ต้องใช้ตัวสุ่มของแมตช์เท่านั้น ห้ามใช้ Math.random ใน UI
     เพราะ state ของตัวสุ่มอยู่ในไฟล์เซฟ (ข้อ 14.2) ถ้าไม่ผูกกัน ผู้เล่นจะเซฟแล้ว
     โหลดทอยใหม่จนกว่าจะได้ความฝันที่ถูกที่สุด — ต่างกันได้ถึง 2.3 เท่า (×30 กับ ×70) */
  rollDream() { return 1 + Math.floor(this.rng() * DREAMS.length); }

  enterPhase2(dream, retire) {
    this.phase = 2; this.pendingDream = false;
    const exp = this.totalExpenses;
    this.dream = { ...dream, cost: Math.round(exp * dream.costMul / 10000) * 10000, passiveReq: Math.round(exp * dream.passiveMul / 100) * 100 };
    this.retired = !!retire;
    this.hours = this.hoursMax;
    this.match.log(`${this.name} ตั้งเป้าหมายใหม่: ${dream.icon} ${dream.name} — ต้องมีความมั่งคั่งสุทธิ ${fmtM(this.dream.cost)}฿ + รายได้จากทรัพย์สิน ${fmt(this.dream.passiveReq)}฿/เดือน` +
      (retire ? ` • ลาออกจากงานประจำ (ได้เวลาคืน ${this.job.work + this.job.commute} ชม./เดือน แต่ไม่มีเงินเดือน)` : ' • ยังทำงานประจำต่อ'), 'win', null);
  }

  claimDream() {
    if (!this.canClaimDream()) return { ok: false, msg: 'ยังไม่ครบทั้งความมั่งคั่งและรายได้ต่อเดือน' };
    this.phase = 3; this.dreamDone = this.match.month;
    const rank = this.match.champions.length + 1;
    this.match.champions.push({ name: this.name, icon: this.job.icon, job: this.job.name,
      dream: this.dream.name, dreamIcon: this.dream.icon, month: this.dreamDone, isAI: this.isAI, rank });
    this.match.log(`👑 อันดับ ${rank} — ${this.name} ทำความฝัน "${this.dream.name}" สำเร็จในเดือนที่ ${this.dreamDone}!` +
      (this.isAI ? ' (เกมยังเดินต่อจนกว่าคุณจะถึงฝันของตัวเอง)' : ''), 'win', null);
    return { ok: true };
  }

  /* ---------- settle ---------- */
  settle() {
    const r = this.rng, M = this.match;

    for (const a of this.assets) {
      a.drift *= 1 + (r() - (a.kind === 'speculation' && this.job.perkId === 'insight' ? 0.508 : 0.5)) * a.vol * 0.55;
      a.drift = clamp(a.drift, 0.35, 3.2);
      if (a.offer) { a.offer.ttl--; if (a.offer.ttl <= 0) a.offer = null; }
      if (a.sick > 0) { a.sick--; if (a.sick === 0) { a.income = a.baseIncome; delete a.baseIncome; this.log(`${a.icon} ${a.name} กลับมาทำกำไรตามปกติ`, 'good'); } }
      if (a.burned > 0) { a.burned--; if (a.burned === 0) this.log(`${a.icon} ${a.name} ซ่อมเสร็จ กลับมาสร้างรายได้แล้ว`, 'good'); }
      if (!a.offer && r() < 0.11) {
        const base = a.kind === 'speculation' ? 1.12 + r() * 0.55 : 1.08 + r() * 0.30;
        a.offer = { price: Math.round(this.assetPrice(a) * base), ttl: 2 };
        if (!this.isAI) this.log(`💰 มีผู้เสนอซื้อ ${a.icon} ${a.name} ที่ ${fmtM(a.offer.price)}฿ (สูงกว่าราคาตลาด) — หมดอายุใน 2 เดือน`, 'offer');
      }
    }

    if (M.month % 12 === 0) {
      this.fixedExpenses = Math.round(this.fixedExpenses * 1.05);
      this.foodBase = Math.round(this.foodBase * 1.05);
      if (!this.isAI) this.log(`📈 ครบ ${M.month / 12} ปี — เงินเฟ้อดันค่าครองชีพขึ้น 5%`, 'bad');
    }

    const income = this.totalIncome, expense = this.totalExpenses, net = income - expense;
    this.cash += net;
    if (!this.isAI) this.log(`📅 สิ้นเดือนที่ ${M.month} — รับ ${fmt(income)}฿ / จ่าย ${fmt(expense)}฿ → ${net >= 0 ? '+' : ''}${fmt(net)}฿`, net >= 0 ? 'payday' : 'bad');
    if (this.downsizeLeft > 0) this.downsizeLeft--;

    /* สุขภาพประจำเดือน */
    let dh = this.sleep.health + this.food.health - 0.35 - this.sleepDebt * 1.3 + this.veh.hp;
    const load = this.workHours + this.sideUsed * COST.side;
    if (load > 300) dh -= 3; else if (load > 255) dh -= 1.5;
    if (this.job.perkId === 'hustle') dh += 0.8;
    this.health = clamp(this.health + dh, 0, 100);

    if (this.sleepDebt > 0 && !this.isAI && M.month % 3 === 0) {
      this.log(`😴 อาชีพ${this.job.name}ต้องการนอน ${this.sleepNeed} ชม./คืน แต่คุณนอน ${this.sleep.h} — สุขภาพลดเพิ่ม ${(this.sleepDebt * 1.3).toFixed(1)}/เดือน และประสิทธิภาพหายอีก ${this.sleepDebt * 5}%`, 'bad');
    }
    if (this.health < 25 && r() < 0.30) {
      const bill = Math.round(this.totalExpenses * (1.2 + r() * 1.6) * this.medFactor);
      this.cash -= bill;
      this.downsizeLeft = Math.max(this.downsizeLeft, 1);
      this.timePenalty += 90;
      this.health = clamp(this.health + 18, 0, 100);
      this.log(`🏥 สุขภาพวิกฤต! ล้มป่วยหนักต้องหยุดงาน 1 เดือน + ค่ารักษา ${fmt(bill)}฿ — สุขภาพคือทรัพย์สินที่แพงที่สุด`, 'bad');
    }

    let evChance = 0.42 * (1 - this.shield);
    if (this.restedThisMonth) evChance -= 0.07;
    if (r() < evChance) this.rollEvent();
    this.restedThisMonth = false;

    for (const a of this.assets) {
      if ((a.kind === 'business' || a.kind === 'micro') && !a.sick && !a.burned && r() < 0.05) {
        a.baseIncome = a.income; a.income = Math.round(a.income * 0.35);
        a.sick = 2 + Math.floor(r() * 3);
        this.log(`⚠️ ${a.icon} ${a.name} ยอดขายตก รายได้ลดชั่วคราว ${a.sick} เดือน`, 'bad');
      }
    }

    if (this.cash < 0) {
      const need = Math.ceil(-this.cash / 10000) * 10000;
      this.liabilities.push({ name: 'บัตรกดเงินสด (ดอกโหด)', balance: need, rate: 0.023 });
      this.cash += need;
      this.log(`🚨 เงินสดไม่พอ! ต้องกดบัตรเงินสด ${fmt(need)}฿ ดอกเบี้ย 28%/ปี`, 'bad');
    }

    this.history.push({ m: M.month, passive: Math.round(this.passiveIncome), exp: Math.round(this.totalExpenses),
      nw: Math.round(this.netWorth), cash: Math.round(this.cash), hp: +this.health.toFixed(1),
      hours: this.hoursMax, assets: this.assets.length, debt: Math.round(this.totalDebt),
      salary: this.salary, sleep: this.sleep.h, food: this.foodId, phase: this.phase,
      travel: this.travelUsed, vehicle: this.vehicle, devices: this.devices.join('|'),
      dis: M.activeDisasters.map(d => d.def.id).join('|') });

    if (!this.bankrupt && this.debtPayments > (this.currentSalary + this.passiveIncome) * 1.25 && this.netWorth < 0) {
      this.bankrupt = true;
      this.log('💀 ล้มละลาย — ภาระหนี้ท่วมรายได้ และทรัพย์สินไม่พอชำระ', 'bad');
    }
    if (!this.finished && this.passiveIncome >= this.totalExpenses) {
      this.finished = M.month;
      M.log(`🎉 ${this.name} ออกจากสนามแข่งหนูได้แล้ว! (เดือนที่ ${this.finished}) — ต่อไปคือการตามล่าความฝัน`, 'win', null);
      if (this.isAI) this.enterPhase2(DREAMS[Math.floor(r() * DREAMS.length)], this.passiveIncome > this.totalExpenses * 1.12);
      else this.pendingDream = true;
    }
    if (this.isAI && this.phase === 2 && this.canClaimDream()) this.claimDream();

    this.timePenalty = Math.max(0, this.timePenalty - 90);
    this.sideUsed = 0; this.exerciseThisMonth = 0;
    this.place = 'home';            // สิ้นเดือนกลับบ้านเสมอ
    this.travelUsed = 0;
    this.gymPack = null;            // แพ็กเกจฟิตเนสหมดอายุรายเดือน
    this.shield = 0;
    this.hours = this.hoursMax;
  }

  rollEvent() {
    const r = this.rng;
    const list = this.phase >= 2 ? EVENTS2 : EVENTS;
    const base = this.phase >= 2 ? this.totalExpenses : Math.max(this.salary, this.totalExpenses * 0.6);
    const hpBoost = this.health < 40 ? 3.2 : (this.health < 55 ? 2.0 : (this.health < 70 ? 1.2 : 0.6));
    const weights = list.map(e => e.health ? e.w * hpBoost : e.w);
    const total = weights.reduce((s, w) => s + w, 0);
    let roll = r() * total, ev = list[0];
    for (let i = 0; i < list.length; i++) { roll -= weights[i]; if (roll <= 0) { ev = list[i]; break; } }

    if (ev.bonusDeals) {
      for (let i = 0; i < ev.bonusDeals; i++) this.match.deals.push(this.match.makeDeal());
      this.log(`✨ ${ev.text}`, 'good'); return;
    }
    const frugal = this.job.perkId === 'frugal' ? 0.5 : 1;
    const med = ev.health ? this.medFactor : 1;
    let msg = '';
    if (ev.costMul) {
      const c = Math.round(base * (ev.costMul[0] + r() * (ev.costMul[1] - ev.costMul[0])) * frugal * med);
      this.cash -= c; msg = `−${fmt(c)}฿`;
    } else if (ev.gainMul) {
      const g = Math.round(base * (ev.gainMul[0] + r() * (ev.gainMul[1] - ev.gainMul[0])));
      this.cash += g; this.log(`✨ ${ev.text} +${fmt(g)}฿`, 'good'); return;
    } else if (ev.raise) {
      const p = ev.raise[0] + r() * (ev.raise[1] - ev.raise[0]);
      this.salary = Math.round(this.salary * (1 + p));
      this.fixedExpenses = Math.round(this.fixedExpenses * (1 + p * 0.55));
      this.log(`✨ ${ev.text} (+${(p * 100).toFixed(0)}%) — แต่รายจ่ายโตตามทันที (ต่างจากการเรียนเพิ่มเติม)`, 'good'); return;
    } else if (ev.market) {
      const m = ev.market[0] + r() * (ev.market[1] - ev.market[0]);
      this.match.marketIndex = clamp(this.match.marketIndex * (1 + m), 0.55, 1.9);
      this.log(`${m > 0 ? '📈' : '📉'} ${ev.text} (${(m * 100).toFixed(0)}%)`, m > 0 ? 'good' : 'bad'); return;
    } else if (ev.childMul) {
      const c = Math.round(base * (ev.childMul[0] + r() * (ev.childMul[1] - ev.childMul[0])));
      this.childCost += c;
      if (ev.childHours) this.childHours += ev.childHours;
      this.log(`👶 ${ev.text} (+${fmt(c)}฿/เดือน${ev.childHours ? ` และเวลาว่างหายไป ${ev.childHours} ชม./เดือน` : ''})`, 'bad'); return;
    } else if (ev.downsize) {
      if (this.job.perkId === 'stable') { this.log('🛡️ มีการปรับโครงสร้าง แต่ตำแหน่งคุณมั่นคง — รอดมาได้', 'good'); return; }
      this.downsizeLeft = ev.downsize;
      this.log(`💥 ${ev.text} — รายจ่ายยังเดินต่อ`, 'bad'); return;
    }
    if (ev.hpCost) { this.health = clamp(this.health - ev.hpCost, 0, 100); msg += ` • สุขภาพ −${ev.hpCost}`; }
    if (ev.timeCost) { this.timePenalty += ev.timeCost; msg += ` • เดือนหน้าเสียเวลา ${ev.timeCost} ชม.`; }
    this.log(`❗ ${ev.text} ${msg}`, 'bad');
  }

  /* ---------- AI ----------
     บอทต้องวางแผนเส้นทางเองแล้ว: คะแนน = ผลตอบแทน ÷ (เวลาทำ + เวลาเดินทาง)
  */
  aiTurn() {
    /* ไลฟ์สไตล์ (ทำได้ที่บ้านตอนต้นเดือน) */
    if (this.place === 'home') {
      const needIdx = SLEEP_OPTIONS.findIndex(o => o.h >= (this.job.sleepNeed || 7));
      if (this.health < 55) { this.sleepIdx = 3; this.setFood('cook'); }
      else if (this.cash < this.totalExpenses * 2) { this.sleepIdx = Math.max(needIdx, 2); this.setFood('cook'); }
      else { this.sleepIdx = Math.max(needIdx, 2); this.setFood('street'); }
      if (this.has('smartphone')) this.aiShop();
    }
    if (this.place === 'mall') this.aiShop();

    let guard = 0;
    while (this.hours > 0 && guard++ < 40) {
      if (this.phase === 2 && this.canClaimDream()) { this.claimDream(); return; }
      const best = this.aiBestMove();
      if (!best) break;
      if (best.travel > 0) { if (!this.travelTo(best.place).ok) break; }
      const r = best.run();
      if (!r || !r.ok) break;
    }
    this.hours = 0;
  }

  aiWantsShop() {
    if (this.place === 'mall') return false;
    if (!this.has('smartphone') && this.cash > 90000) return true;
    if (!this.has('laptop') && this.cash > 160000) return true;
    const val = Math.max(300, (this.salary + this.passiveIncome) / Math.max(40, this.hoursMax));
    for (let i = VEHICLES.length - 1; i >= 1; i--) {
      const v = VEHICLES[i];
      if (VEHICLES.indexOf(this.veh) >= i) break;
      const saveH = (this.job.commute + 40) * (this.veh.factor - v.factor);
      const cost = v.upkeep + (v.price - v.price * v.downPct) * 0.007;
      const down = Math.round(v.price * v.downPct);
      if (saveH * val > cost * 1.25 && this.cash > down + this.totalExpenses * 3) return true;
    }
    return false;
  }

  /* ตัดสินใจซื้อของอำนวยความสะดวก */
  aiShop() {
    const val = Math.max(300, (this.salary + this.passiveIncome) / Math.max(40, this.hoursMax)); // มูลค่าต่อชั่วโมง
    if (!this.has('smartphone') && this.cash > 90000) this.buyDevice('smartphone');
    if (!this.has('laptop') && this.cash > 160000) this.buyDevice('laptop');
    for (let i = VEHICLES.length - 1; i >= 1; i--) {
      const v = VEHICLES[i];
      if (VEHICLES.indexOf(this.veh) >= i) break;
      const saveH = (this.job.commute + 40) * (this.veh.factor - v.factor);   // ชม.ที่ประหยัดได้/เดือน
      const cost = v.upkeep + (v.price - v.price * v.downPct) * 0.007;
      const down = Math.round(v.price * v.downPct);
      if (saveH * val > cost * 1.25 && this.cash > down + this.totalExpenses * 3
          && (v.price - down) <= this.creditLeft) { this.buyVehicle(v.id); break; }
    }
  }

  /* คืนตัวเลือกที่คุ้มที่สุด (รวมเวลาเดินทางในการคิดแล้ว) */
  aiBestMove() {
    const cands = [];
    const add = (place, hours, score, run) => {
      const travel = place === this.place ? 0 : this.travelCost(place);
      const total = hours + travel;
      if (total > this.hours || total <= 0) return;
      cands.push({ place, travel, score: score / total, run });
    };

    /* ขายทรัพย์สินที่มีข้อเสนอดี */
    for (const a of this.assets) {
      if (!a.offer) continue;
      const need = a.kind === 'speculation' ? 1.22 : 1.28;
      if (a.offer.price <= a.value * need) continue;
      add(this.placeFor(this.actForKind(a.kind)), COST.sell, (a.offer.price - a.value) / 1000,
        () => this.sellAsset(a.id));
    }
    /* ซื้อดีล */
    for (const d of this.match.deals) {
      const price = this.job.perkId === 'discount' ? d.price * 0.9 : d.price;
      const down = price * (d.down / d.price), debt = price - down;
      const cf = d.income * (price / d.price) - debt * MORTGAGE;
      const roi = d.kind === 'speculation' ? 0.022 : cf / Math.max(1, down);
      if (this.cash - down < this.totalExpenses * 0.5 || debt > this.creditLeft || roi < 0.018) continue;
      add(this.placeFor(this.actForKind(d.kind)), this.cost(COST.deal), cf / 40 + roi * 400,
        () => this.closeDeal(d.id));
    }
    /* สุขภาพ */
    if (this.health < 80) {
      const urgency = this.health < 50 ? 60 : (this.health < 65 ? 25 : 8);
      const pk = this.gymPack ? GYM_PACKS.find(g => g.id === this.gymPack)
        : (this.cash > 40000 ? GYM_PACKS[1] : GYM_PACKS[0]);
      add('gym', pk.hours, urgency, () => this.exercise(pk.id));
      if (this.health < 45 && this.cash > 60000)
        add('resort', RESORT_PACKS[1].hours, urgency * 1.1, () => this.vacation('weekend'));
      add('home', COST.rest, urgency * 0.35, () => this.rest());
    }
    /* เรียน */
    if (this.phase === 1 && this.studyLevel < 2 && this.match.month < 24 && this.cash > this.salary * 2.5)
      add(this.placeFor('study'), COST.study, 14, () => this.study());
    /* งานเสริม */
    if (this.cash < this.totalExpenses * 2.5 && this.sideUsed < 3) {
      if (!this.retired && this.downsizeLeft === 0)
        add('office', COST.side, this.salary * 0.21 / 900, () => this.sideJob('ot'));
      add(this.placeFor('freelance'), COST.side, this.salary * 0.24 / 900, () => this.sideJob('freelance'));
    }
    /* หาดีลใหม่ */
    if (this.match.deals.length < 9)
      add('estate', COST.scout, 6, () => this.scout());
    /* ไปห้างซื้อของอำนวยความสะดวก */
    if (this.aiWantsShop()) add('mall', 2, 30, () => { this.aiShop(); return { ok: true }; });

    if (!cands.length) return null;
    cands.sort((a, b) => b.score - a.score);
    return cands[0];
  }
}

/* =========================================================
   MATCH
   ========================================================= */
class Match {
  constructor(opts) {
    this.mode = opts.mode || 'solo';
    this.rng = makeRng(opts.seed || 12345);
    this.month = 1;
    this.marketIndex = 1;
    this.marketTrend = 0;
    this.dealIdSeq = 1;
    this.deals = [];
    this.logs = [];
    this.state = 'playing';
    this.activeDisasters = [];
    this.disasterCooldown = 9 + Math.floor(this.rng() * 8);
    this.disasterHistory = [];
    this.champions = [];          // ใครทำความฝันสำเร็จแล้วบ้าง (เกมยังเดินต่อ)
    this.players = opts.players.map(p => new Player(this, p));
    this.startIndex = 0;
    this.turn = 0;
    this.refillMarket();
    this.log(`เริ่มแมตช์ — โหมด ${this.mode === 'solo' ? 'SOLO (สู้กับบอท)' : 'MULTIPLAYER'} • ผู้เล่น ${this.players.length} คน`, 'sys', null);
    this.beginMonth();
  }

  get mods() {
    const m = { business: 1, realestate: 1, rate: 1, credit: 1 };
    for (const d of this.activeDisasters) {
      const x = d.def.mods || {};
      if (x.business) m.business *= x.business;
      if (x.realestate) m.realestate *= x.realestate;
      if (x.rate) m.rate *= x.rate;
      if (x.credit) m.credit *= x.credit;
    }
    return m;
  }

  get order() {
    const n = this.players.length, o = [];
    for (let i = 0; i < n; i++) o.push(this.players[(this.startIndex + i) % n]);
    return o;
  }
  get current() { return this.order[this.turn]; }
  get human() { return this.players.find(p => !p.isAI); }

  log(text, type, player) {
    this.logs.unshift({ month: this.month, text, type: type || 'info', who: player ? player.name : null });
    if (this.logs.length > 140) this.logs.pop();
  }

  pickTemplate(pool, maxDown) {
    const r = this.rng;
    let cand = pool;
    // ใช้ downPct ตัวบน เพราะเงินดาวน์จริงสุ่มได้ถึงค่านั้น — ถ้ากรองด้วยตัวล่างจะได้ดีลที่ยังซื้อไม่ไหว
    if (maxDown) cand = pool.filter(t => t.min * t.downPct[1] <= maxDown);
    if (!cand.length) cand = pool;
    const total = cand.reduce((s, t) => s + (t.w || 1), 0);
    let x = r() * total;
    for (const t of cand) { x -= (t.w || 1); if (x <= 0) return t; }
    return cand[cand.length - 1];
  }

  makeDeal(forceBig, maxDown) {
    const r = this.rng;
    const richest = Math.max(0, ...this.players.map(p => p.netWorth || 0));
    const anyPhase2 = this.players.some(p => p.phase >= 2);

    if (!maxDown && anyPhase2 && r() < 0.38) {
      const t = MEGA_DEALS[Math.floor(r() * MEGA_DEALS.length)];
      const price = Math.max(1000000, Math.round(richest * (0.15 + r() * 0.5) / 100000) * 100000);
      const downPct = t.downPct[0] + r() * (t.downPct[1] - t.downPct[0]);
      const down = Math.round(price * downPct), debt = price - down;
      const income = Math.round(price * (t.yield[0] + r() * (t.yield[1] - t.yield[0])));
      return { id: this.dealIdSeq++, kind: t.kind, icon: t.icon, name: t.names[Math.floor(r() * t.names.length)],
        price, down, debt, income, cashflow: Math.round(income - debt * MORTGAGE), vol: t.vol,
        mortgageRate: MORTGAGE, ttl: 2 + Math.floor(r() * 3), big: true, mega: true };
    }

    const big = forceBig || (!maxDown && richest > 4000000 && r() < 0.30);
    const pool = big ? BIG_DEALS : DEAL_POOL;
    const t = this.pickTemplate(pool, maxDown);
    const step = t.min >= 1000000 ? 100000 : (t.min >= 100000 ? 10000 : 1000);
    let hi = t.max;
    if (maxDown) hi = Math.min(t.max, Math.max(t.min, maxDown / t.downPct[1]));
    const price = Math.round((t.min + r() * (hi - t.min)) / step) * step;
    const downPct = t.downPct[0] + r() * (t.downPct[1] - t.downPct[0]);
    const down = Math.round(price * downPct), debt = price - down;
    const income = Math.round(price * (t.yield[0] + r() * (t.yield[1] - t.yield[0])));
    return { id: this.dealIdSeq++, kind: t.kind, icon: t.icon, name: t.names[Math.floor(r() * t.names.length)],
      price, down, debt, income, cashflow: Math.round(income - debt * MORTGAGE), vol: t.vol,
      mortgageRate: MORTGAGE, ttl: 2 + Math.floor(r() * 3), big: !!big };
  }

  refillMarket() {
    const target = 4 + this.players.length;
    while (this.deals.length < target) this.deals.push(this.makeDeal());
    const alive = this.players.filter(p => !p.bankrupt && p.phase < 3);
    if (!alive.length) return;
    const poorest = Math.max(CHEAPEST_DOWN, Math.min(...alive.map(p => p.cash)));
    let cheap = this.deals.filter(d => d.down <= poorest).length, guard = 0;
    while (cheap < 2 && guard++ < 6) {
      if (this.deals.length >= target + 2) this.deals.shift();
      this.deals.push(this.makeDeal(false, poorest));
      cheap = this.deals.filter(d => d.down <= poorest).length;
    }
  }

  beginMonth() { this.turn = 0; this.runAITurns(); }

  runAITurns() {
    while (this.state === 'playing' && this.turn < this.players.length) {
      const p = this.current;
      if (p.isAI) { if (!p.bankrupt && p.phase < 3) p.aiTurn(); this.turn++; }
      else if (p.bankrupt || p.phase === 3) { this.turn++; }
      else break;
    }
    if (this.turn >= this.players.length) this.endMonth();
  }

  endTurn() {
    if (this.state !== 'playing') return;
    this.current.hours = 0;
    this.turn++;
    this.runAITurns();
  }

  tickDisasters() {
    for (let i = this.activeDisasters.length - 1; i >= 0; i--) {
      if (--this.activeDisasters[i].left <= 0) {
        const d = this.activeDisasters.splice(i, 1)[0];
        this.log(`${d.def.icon} สถานการณ์ "${d.def.name}" คลี่คลายแล้ว`, 'good', null);
      }
    }
    if (--this.disasterCooldown > 0) return;
    this.disasterCooldown = 10 + Math.floor(this.rng() * 9);

    const r = this.rng;
    const def = DISASTERS[Math.floor(r() * DISASTERS.length)];
    this.activeDisasters.push({ def, left: def.dur });
    this.disasterHistory.push({ month: this.month, id: def.id, name: def.name, icon: def.icon });
    this.log(`⛔ ภัยพิบัติ: ${def.icon} ${def.name} — ${def.desc} (มีผล ${def.dur} เดือน)`, 'disaster', null);

    if (def.market) this.marketIndex = clamp(this.marketIndex * (1 + def.market), 0.5, 1.9);
    for (const p of this.players) {
      if (p.bankrupt || p.phase === 3) continue;
      if (def.hp) p.health = clamp(p.health + def.hp, 0, 100);
      if (def.inflate) { p.fixedExpenses = Math.round(p.fixedExpenses * (1 + def.inflate)); p.foodBase = Math.round(p.foodBase * (1 + def.inflate)); }
      if (def.cashCostMul) {
        const frugal = p.job.perkId === 'frugal' ? 0.6 : 1;
        const c = Math.round(p.totalExpenses * (def.cashCostMul[0] + r() * (def.cashCostMul[1] - def.cashCostMul[0])) * frugal);
        p.cash -= c;
        p.log(`${def.icon} ผลกระทบจาก${def.name} −${fmt(c)}฿`, 'bad');
      }
      if (def.burnAsset) {
        const targets = p.assets.filter(a => (a.kind === 'business' || a.kind === 'micro') && !a.burned);
        if (targets.length && r() < 0.5) {
          const a = targets[Math.floor(r() * targets.length)];
          a.burned = 4;
          p.log(`🔥 ${a.icon} ${a.name} ถูกไฟไหม้! ไม่มีรายได้ 4 เดือน แต่ค่าผ่อนยังเดินต่อ`, 'bad');
        }
      }
    }
  }

  endMonth() {
    if (this.month >= 600) { this.state = 'over'; return; }
    const r = this.rng;
    this.marketTrend = this.marketTrend * 0.6 + (r() - 0.5) * 0.04;
    this.marketIndex = clamp(this.marketIndex * (1 + this.marketTrend), 0.55, 1.9);

    this.tickDisasters();
    for (const p of this.players) if (!p.bankrupt && p.phase < 3) p.settle();

    for (let i = this.deals.length - 1; i >= 0; i--) { this.deals[i].ttl--; if (this.deals[i].ttl <= 0) this.deals.splice(i, 1); }
    this.refillMarket();

    const humans = this.players.filter(p => !p.isAI);
    const watch = humans.length ? humans : this.players;
    const stillPlaying = watch.filter(p => !p.bankrupt && p.phase < 3);
    if (stillPlaying.length === 0) { this.state = 'over'; return; }

    this.month++;
    this.startIndex = (this.startIndex + 1) % this.players.length;
    this.beginMonth();
  }

  /* ---------- บันทึก / โหลด ---------- */
  serialize() {
    return {
      v: 4, savedAt: null, mode: this.mode, month: this.month,
      rng: this.rng.s, marketIndex: this.marketIndex, marketTrend: this.marketTrend,
      dealIdSeq: this.dealIdSeq, deals: this.deals, logs: this.logs, state: this.state,
      startIndex: this.startIndex, turn: this.turn,
      disasterCooldown: this.disasterCooldown,
      activeDisasters: this.activeDisasters.map(d => ({ id: d.def.id, left: d.left })),
      disasterHistory: this.disasterHistory,
      champions: this.champions,
      players: this.players.map(p => ({
        name: p.name, isAI: p.isAI, jobId: p.job.id, roll: p.roll, bonusHours: p.bonusHours,
        cash: p.cash, salary: p.salary, fixedExpenses: p.fixedExpenses, foodBase: p.foodBase,
        childCost: p.childCost, childHours: p.childHours,
        assets: p.assets, liabilities: p.liabilities,
        place: p.place, travelUsed: p.travelUsed, vehicle: p.vehicle,
        devices: p.devices, gymPack: p.gymPack, shield: p.shield,
        sleepIdx: p.sleepIdx, foodId: p.foodId, health: p.health, timePenalty: p.timePenalty,
        sideUsed: p.sideUsed, exerciseThisMonth: p.exerciseThisMonth, restedThisMonth: !!p.restedThisMonth,
        studyLevel: p.studyLevel, studyProgress: p.studyProgress,
        downsizeLeft: p.downsizeLeft, bankrupt: p.bankrupt, finished: p.finished,
        phase: p.phase, dream: p.dream, dreamDone: p.dreamDone, retired: p.retired,
        pendingDream: p.pendingDream, hours: p.hours, history: p.history
      }))
    };
  }

  static load(data) {
    if (!data || data.v !== 4) throw new Error('ไฟล์เซฟไม่ถูกต้อง หรือมาจากเกมคนละเวอร์ชัน');
    const m = Object.create(Match.prototype);
    m.mode = data.mode; m.month = data.month;
    m.rng = makeRng(0); m.rng.s = data.rng >>> 0;
    m.marketIndex = data.marketIndex; m.marketTrend = data.marketTrend;
    m.dealIdSeq = data.dealIdSeq; m.deals = data.deals; m.logs = data.logs || [];
    m.state = data.state; m.startIndex = data.startIndex; m.turn = data.turn;
    m.disasterCooldown = data.disasterCooldown;
    m.disasterHistory = data.disasterHistory || [];
    m.champions = data.champions || [];
    m.activeDisasters = (data.activeDisasters || [])
      .map(d => ({ def: DISASTERS.find(x => x.id === d.id), left: d.left }))
      .filter(d => d.def);
    m.players = data.players.map(pd => {
      const p = Object.create(Player.prototype);
      p.match = m;
      p.job = JOBS.find(j => j.id === pd.jobId) || JOBS[0];
      Object.assign(p, pd);
      delete p.jobId;
      p.assets = pd.assets || []; p.liabilities = pd.liabilities || []; p.history = pd.history || [];
      /* ค่าเริ่มต้นของระบบแผนที่ — ไฟล์เซฟเก่าที่บันทึกก่อนมีระบบนี้จะไม่มีช่องเหล่านี้
         ต้องเติมให้ ไม่งั้น getter อย่าง upkeepCost จะพังทันทีที่โหลด */
      if (p.place === undefined) p.place = 'home';
      if (p.travelUsed === undefined) p.travelUsed = 0;
      if (p.vehicle === undefined) p.vehicle = 'public';
      if (!Array.isArray(p.devices)) p.devices = [];
      if (p.gymPack === undefined) p.gymPack = null;
      if (p.shield === undefined) p.shield = 0;
      return p;
    });
    return m;
  }

  standings() {
    return this.players.slice().sort((a, b) => {
      if (a.dreamDone && b.dreamDone) return a.dreamDone - b.dreamDone;
      if (a.dreamDone) return -1; if (b.dreamDone) return 1;
      if (a.phase !== b.phase) return b.phase - a.phase;
      if (a.phase === 2) return (b.dreamPct + b.dreamPassivePct) - (a.dreamPct + a.dreamPassivePct);
      return b.freedomPct - a.freedomPct || b.netWorth - a.netWorth;
    });
  }
}

if (typeof module !== 'undefined') module.exports = {
  Match, Player, JOBS, EVENTS, EVENTS2, DISASTERS, DREAMS, SLEEP_OPTIONS, FOOD_OPTIONS, COST, ACTION_INFO,
  PLACES, PLACE, VEHICLES, DEVICES, GYM_PACKS, RESORT_PACKS, TRAVEL_RATE,
  fmt, fmtM, makeRng, rollStart, ROLL_TABLE, KIND_LABEL, MORTGAGE, HOURS_PER_MONTH, CHORES_HOURS, BOT_NAMES
};
