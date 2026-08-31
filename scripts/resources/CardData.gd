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

# 클래스가 처음 참조될 때 자동으로 실행되어 기물 카드를 DB에 등록합니다.
static func _static_init():
	_register("w_pawn", "White Pawn", 1, CardType.PIECE, "res://Asset/Cards/W_Pawn.png", "전방으로 1칸 이동합니다. 첫 이동 시 2칸 이동 가능.", ["Piece", "Pawn"])
	_register("w_knight", "White Knight", 1, CardType.PIECE, "res://Asset/Cards/W_Knight.png", "L자 형태로 이동하며 다른 기물을 뛰어넘을 수 있습니다.", ["Piece", "Knight"])
	_register("w_bishop", "White Bishop", 2, CardType.PIECE, "res://Asset/Cards/W_Bishop.png", "대각선으로 원하는 만큼 이동합니다.", ["Piece", "Bishop"])
	_register("w_rook", "White Rook", 2, CardType.PIECE, "res://Asset/Cards/W_Rook.png", "가로 및 세로로 원하는 만큼 이동합니다.", ["Piece", "Rook"])
	_register("w_queen", "White Queen", 2, CardType.PIECE, "res://Asset/Cards/W_Queen.png", "상하좌우 및 대각선으로 원하는 만큼 이동합니다.", ["Piece", "Queen"])
	_register("w_king", "White King", 1, CardType.PIECE, "res://Asset/Cards/W_King.png", "모든 방향으로 1칸 이동합니다. 체스의 메인 타겟입니다.", ["Piece", "King", "Objective"])

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
