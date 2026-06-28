class_name CardData
extends RefCounted

enum CardType { SKILL, ATTACK, POWER }

# --- 개별 카드 데이터 구조 ---
var id: String
var card_name: String
var cost: int
var description: String
var type: CardType
var region: Rect2
var tags: Array[String]
var effect: Callable # 나중에 효과를 주입할 콜백

# 생성자
func _init(_id: String, _name: String, _cost: int, _type: CardType, _region: Rect2, _desc: String, _tags: Array[String] = []):
	id = _id
	card_name = _name
	cost = _cost
	type = _type
	region = _region
	description = _desc
	tags = _tags

# 동적으로 이미지를 잘라서 제공하는 함수
func get_texture() -> AtlasTexture:
	var atlas = AtlasTexture.new()
	# 메모리 관리를 위해 필요할 때만 원본을 로드합니다.
	atlas.atlas = load("res://Asset/test/test card asset.png")
	atlas.region = region
	return atlas

# --- 글로벌 카드 데이터베이스 (Static) ---
static var database: Dictionary = {}

# 클래스가 처음 참조될 때 자동으로 실행되어 10장의 카드를 DB에 등록합니다.
static func _static_init():
	_register("searing_blade", "Searing Blade", 0, CardType.ATTACK, Rect2(0, 0, 563, 768), "적에게 막대한 피해를 입힙니다.", ["Test"])
	_register("silent_dagger", "Silent Dagger", 1, CardType.ATTACK, Rect2(563, 0, 563, 768), "조용하고 치명적인 단검 공격입니다.", ["Test"])
	_register("arcane_bolt", "Arcane Bolt", 2, CardType.SKILL, Rect2(1126, 0, 563, 768), "마법 화살을 발사합니다.", ["Test"])
	_register("deflect", "Deflect", 3, CardType.SKILL, Rect2(1689, 0, 563, 768), "적의 공격을 쳐냅니다.", ["Test"])
	_register("evolve", "Evolve", 4, CardType.POWER, Rect2(2252, 0, 563, 768), "상태 이상 카드를 뽑을 때 카드를 뽑습니다.", ["Test"])
	_register("double_tap", "Double Tap", 5, CardType.SKILL, Rect2(0, 768, 563, 768), "이번 턴에 사용하는 다음 공격 카드를 두 번 실행합니다.", ["Test"])
	_register("blood_offering", "Blood Offering", 6, CardType.SKILL, Rect2(563, 768, 563, 768), "체력을 잃고 코스트를 얻습니다.", ["Test"])
	_register("ironclad_will", "Ironclad Will", 7, CardType.POWER, Rect2(1126, 768, 563, 768), "매 턴마다 방어도를 얻습니다.", ["Test"])
	_register("noxious_fumes", "Noxious Fumes", 8, CardType.POWER, Rect2(1689, 768, 563, 768), "매 턴 적에게 중독을 부여합니다.", ["Test"])
	_register("storm_of_steel", "Storm of Steel", 9, CardType.ATTACK, Rect2(2252, 768, 563, 768), "손패를 모두 버리고 그만큼 단검을 추가합니다.", ["Test"])

static func _register(_id: String, _name: String, _cost: int, _type: CardType, _region: Rect2, _desc: String, _tags: Array[String] = []):
	database[_id] = CardData.new(_id, _name, _cost, _type, _region, _desc, _tags)

static func get_card(card_id: String) -> CardData:
	if database.has(card_id):
		return database[card_id]
	push_error("CardData: 존재하지 않는 카드 ID 입니다 - " + card_id)
	return null

# 테스트용: 모든 카드를 배열로 반환
static func get_all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for key in database:
		result.append(database[key])
	return result
