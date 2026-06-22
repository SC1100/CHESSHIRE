extends Node
class_name BoardManager

@export var board_grid_path: NodePath = ^"../ChessBoard/Grid"

# 1. 흑/백 기물 씬 미리 로드
var piece_scenes = {
	"B_Pawn": preload("res://Asset/ChessSet/Piece/B_Pawn.tscn"),
	"B_Rook": preload("res://Asset/ChessSet/Piece/B_Rook.tscn"),
	"B_Knight": preload("res://Asset/ChessSet/Piece/B_Knight.tscn"),
	"B_Bishop": preload("res://Asset/ChessSet/Piece/B_Bishop.tscn"),
	"B_Queen": preload("res://Asset/ChessSet/Piece/B_Queen.tscn"),
	"B_King": preload("res://Asset/ChessSet/Piece/B_King.tscn"),
	
	"W_Pawn": preload("res://Asset/ChessSet/Piece/W_Pawn.tscn"),
	"W_Rook": preload("res://Asset/ChessSet/Piece/W_Rook.tscn"),
	"W_Knight": preload("res://Asset/ChessSet/Piece/W_Knight.tscn"),
	"W_Bishop": preload("res://Asset/ChessSet/Piece/W_Bishop.tscn"),
	"W_Queen": preload("res://Asset/ChessSet/Piece/W_Queen.tscn"),
	"W_King": preload("res://Asset/ChessSet/Piece/W_King.tscn")
}

# 2. 스테이지 데이터 (이제 JSON에서 불러옵니다)
var stages: Dictionary = {}

var board_grid: Node3D
var current_board_state: Dictionary = {} # 타일 이름("a1") -> 기물 노드 매핑

func get_piece_name_on_tile(tile_name: String) -> String:
	if current_board_state.has(tile_name) and is_instance_valid(current_board_state[tile_name]):
		return current_board_state[tile_name].name
	return ""

func _ready():
	board_grid = get_node(board_grid_path)
	if not board_grid:
		push_error("BoardManager: 보드 그리드를 찾을 수 없습니다!")
		return
		
	_load_stages_from_json()
		
	# 게임 시작 시 바로 test_stage 자동 배치 (테스트용)
	# 콜리전 계산 등을 안전하게 처리하기 위해 프레임 끝에 호출(call_deferred)
	call_deferred("load_stage", "test_stage")

func _load_stages_from_json():
	var file_path = "res://resources/data/stages.json"
	if not FileAccess.file_exists(file_path):
		push_error("BoardManager: 스테이지 데이터 파일이 없습니다! - %s" % file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		stages = json.data
	else:
		push_error("BoardManager: JSON 파싱 오류 (라인 %d): %s" % [json.get_error_line(), json.get_error_message()])

func load_stage(stage_id: String):
	if not stages.has(stage_id):
		push_error("BoardManager: '%s' 스테이지 데이터를 찾을 수 없습니다." % stage_id)
		return
		
	var stage_data = stages[stage_id]
	
	# 향후 스테이지 메타데이터(grid_info)를 사용할 수 있도록 확보해둡니다.
	var grid_info = stage_data.get("grid_info", {})
	var layout = stage_data.get("layout", {})
	
	var piece_counts = {} # 종류별 소환 횟수를 추적하는 딕셔너리
	
	# a에 가까운 열부터 순서대로 소환하도록 타일 이름을 정렬합니다.
	var sorted_tiles = layout.keys()
	sorted_tiles.sort()
	
	for tile_name in sorted_tiles:
		var piece_key = layout[tile_name]
		if not piece_scenes.has(piece_key):
			push_error("BoardManager: 알 수 없는 기물 키입니다 - %s" % piece_key)
			continue
			
		var tile_node = board_grid.get_node_or_null(tile_name)
		if not tile_node:
			push_error("BoardManager: 타일을 찾을 수 없습니다 - %s" % tile_name)
			continue
			
		# 소환 횟수 업데이트
		if not piece_counts.has(piece_key):
			piece_counts[piece_key] = 1
		else:
			piece_counts[piece_key] += 1
			
		# 기물 복제(인스턴스화)
		var piece_instance = piece_scenes[piece_key].instantiate()
		
		# 씬 트리에 추가 및 고유 이름 설정 (예: B_Pawn_1)
		piece_instance.name = piece_key + "_" + str(piece_counts[piece_key])
		add_child(piece_instance)
		
		# 기물 스케일 축소 (원본 모델 크기가 거대하므로 체스 보드 비율에 맞춤)
		piece_instance.scale = Vector3(0.0585, 0.0585, 0.0585)
		
		# 글로벌 포지션 일치 (타일 중앙에 딱 맞게 스냅)
		piece_instance.global_position = tile_node.global_position
		
		# 보드 상태 딕셔너리에 기록
		current_board_state[tile_name] = piece_instance
