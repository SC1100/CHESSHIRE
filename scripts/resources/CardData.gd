class_name CardData
extends RefCounted

enum CardType {SKILL, ATTACK, POWER, PIECE}

const COST_X = -1 # 남은 마나를 모두 소모하는 특수 코스트

# --- 개별 카드 데이터 구조 ---
var id: String
var card_name: String
var cost: int
var description: String
var type: CardType
var image_path: String
var tags: Array[String]
var effect: Callable # 나중에 효과를 주입할 콜백

# 생성자
func _init(_id: String, _name: String, _cost: int, _type: CardType, _image_path: String, _desc: String, _tags: Array[String] = []):
	id = _id
	card_name = _name
	cost = _cost
	type = _type
	image_path = _image_path
	description = _desc
	tags = _tags

# 개별 이미지를 불러오는 함수
func get_texture() -> Texture2D:
	return load(image_path)

# --- 글로벌 카드 데이터베이스 (Static) ---
static var database: Dictionary = {}

# 클래스가 처음 참조될 때 자동으로 실행되어 카드를 DB에 등록합니다.
static func _static_init():
	# 1. 기물 카드 (W_)
	_register("w_pawn", "White Pawn", 1, CardType.PIECE, "res://Asset/Cards/W_Pawn.png", "전방으로 1칸 이동합니다. 첫 이동 시 2칸 이동 가능.", ["Piece", "Pawn"])
	_register("w_knight", "White Knight", 1, CardType.PIECE, "res://Asset/Cards/W_Knight.png", "L자 형태로 이동하며 다른 기물을 뛰어넘을 수 있습니다.", ["Piece", "Knight"])
	_register("w_bishop", "White Bishop", 2, CardType.PIECE, "res://Asset/Cards/W_Bishop.png", "대각선으로 원하는 만큼 이동합니다.", ["Piece", "Bishop"])
	_register("w_rook", "White Rook", 2, CardType.PIECE, "res://Asset/Cards/W_Rook.png", "가로 및 세로로 원하는 만큼 이동합니다.", ["Piece", "Rook"])
	_register("w_queen", "White Queen", 2, CardType.PIECE, "res://Asset/Cards/W_Queen.png", "상하좌우 및 대각선으로 원하는 만큼 이동합니다.", ["Piece", "Queen"])
	_register("w_king", "White King", 1, CardType.PIECE, "res://Asset/Cards/W_King.png", "모든 방향으로 1칸 이동합니다. 체스의 메인 타겟입니다.", ["Piece", "King", "Objective"])

	# 2. 전술 카드 8종 (T_)
	_register("t_crusade", "십자군", 4, CardType.POWER, "res://Asset/Cards/T_Crusade.png", "이번 전투 동안 모든 비숍은 직선 방향으로도 이동할 수 있습니다", ["Tactic", "Power", "Bishop"])
	_register("t_disband", "소집 해제", 0, CardType.SKILL, "res://Asset/Cards/T_Disband.png", "이번 턴 동안 아군의 기물을 1회 잡을 수 있습니다", ["Tactic", "Skill"])
	_register("t_lance_charge", "랜스 차징", 1, CardType.SKILL, "res://Asset/Cards/T_Lance Charge.png", "이번 턴 동안 다음 움직이는 나이트를 2회 움직일 수 있습니다, 기물을 뛰어넘을 수 없습니다", ["Tactic", "Skill", "Knight"])
	_register("t_last_stand", "결사항전", 1, CardType.SKILL, "res://Asset/Cards/T_Last Stand.png", "1회에 한해 다음 상대 턴 동안 아군 기물이 공격당할 경우 공격한 기물도 파괴됩니다", ["Tactic", "Skill", "Trap"])
	_register("t_quick_decision", "빠른 판단", 1, CardType.SKILL, "res://Asset/Cards/T_Quick Decision.png", "이미 킹을 움직였더라도 킹을 1회 추가로 움직일 수 있습니다", ["Tactic", "Skill", "King"])
	_register("t_sabotage", "방해 공작", 2, CardType.SKILL, "res://Asset/Cards/T_Sabotage.png", "상대방은 다음 상대방의 턴 동안 1회만 움직일 수 있습니다", ["Tactic", "Skill", "Debuff"])
	_register("t_spoils", "전리품", 1, CardType.SKILL, "res://Asset/Cards/T_Spoils.png", "이번 턴 내에 잡은 상대 기물이 있다면 코스트를 2 얻고 카드 1장을 드로우 합니다", ["Tactic", "Skill", "Resource"])
	_register("t_two_cats", "고양이 두 마리", 1, CardType.SKILL, "res://Asset/Cards/T_Two Cats.png", "내 덱에서 카드를 2장 드로우 합니다", ["Tactic", "Skill", "Draw"])

static func _register(_id: String, _name: String, _cost: int, _type: CardType, _image_path: String, _desc: String, _tags: Array[String] = []):
	database[_id] = CardData.new(_id, _name, _cost, _type, _image_path, _desc, _tags)

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
