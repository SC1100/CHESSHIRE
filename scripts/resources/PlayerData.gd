class_name PlayerData
extends Resource

# --- 플레이어 상태 ---
@export var max_mana: int = 3
@export var current_mana: int = 3

# --- 덱 정보 (세이브 대상) ---
# 카드 객체 자체가 아니라, 카드의 '고유 ID' 문자열들만 저장하여 용량을 줄이고 오류를 방지합니다.
@export var deck_card_ids: Array[String] = []

# --- 저장 경로 설정 ---
# 개발 단계에서는 직관적으로 볼 수 있도록 res://save/ 경로를 사용하지만,
# [user_global] 4번 규칙에 따라 최종 배포 시에는 user://save/ 로 변경해야 독립성과 프라이버시가 보장됩니다.
const SAVE_PATH = "res://save/player_data.tres"

# 세이브 기능
func save():
	# save 폴더가 없으면 생성합니다.
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("save"):
		dir.make_dir("save")
		
	var err = ResourceSaver.save(self, SAVE_PATH)
	if err == OK:
		print("플레이어 데이터가 성공적으로 저장되었습니다: ", SAVE_PATH)
	else:
		push_error("플레이어 데이터 저장 실패! 에러 코드: ", err)

# 로드 기능 (Static)
static func load_data() -> PlayerData:
	if ResourceLoader.exists(SAVE_PATH):
		print("세이브 파일을 발견하여 플레이어 데이터를 로드합니다.")
		return load(SAVE_PATH) as PlayerData
		
	print("세이브 파일이 없어 새로운 플레이어 데이터를 생성합니다.")
	var new_data = PlayerData.new()
	
	# 테스트용 초기 덱 지급 (10종의 카드 모두 1장씩 보유)
	# Godot 4의 엄격한 타입 검사(Array[String])를 통과하기 위해 assign()을 사용합니다.
	new_data.deck_card_ids.assign([
		"searing_blade",
		"silent_dagger",
		"arcane_bolt",
		"deflect",
		"evolve",
		"double_tap",
		"blood_offering",
		"ironclad_will",
		"noxious_fumes",
		"storm_of_steel"
	])
	return new_data
