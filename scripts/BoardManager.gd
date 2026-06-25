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

var highlight_nodes: Array[Node] = []
var current_valid_moves: Array[String] = []
var highlight_material: StandardMaterial3D

func get_piece_name_on_tile(tile_name: String) -> String:
	if current_board_state.has(tile_name) and is_instance_valid(current_board_state[tile_name]):
		return current_board_state[tile_name].name
	return ""

func _ready():
	board_grid = get_node(board_grid_path)
	if not board_grid:
		push_error("BoardManager: 보드 그리드를 찾을 수 없습니다!")
		return
		
	# 반투명 검은색 매테리얼 생성 (이동 가능 타일 하이라이트용)
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(0.0, 0.0, 0.0, 0.6) # 짙은 검은색과 높은 불투명도
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # 그림자 영향 받지 않음
	highlight_material.no_depth_test = true # 타일에 파묻혀도 무조건 최상단에 렌더링되도록 강제
		
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

func get_tile_of_piece(piece: Node) -> String:
	for tile in current_board_state.keys():
		if current_board_state[tile] == piece:
			return tile
	return ""

func show_valid_moves(piece: Node) -> void:
	clear_valid_moves() # 기존 하이라이트 지우기
	
	var piece_tile = get_tile_of_piece(piece)
	if piece_tile == "": return
	
	var cols = ["a", "b", "c", "d", "e", "f", "g", "h"]
	for col in cols:
		for row in range(1, 9):
			var target_tile = col + str(row)
			if ChessRules.is_move_valid(piece.name, piece_tile, target_tile, current_board_state):
				current_valid_moves.append(target_tile)
				_create_highlight_on_tile(target_tile)

func _create_highlight_on_tile(tile_name: String) -> void:
	var tile_node = board_grid.get_node_or_null(tile_name)
	if not tile_node: return
	
	var shape_pos = Vector3.ZERO
	for child in tile_node.get_children():
		if child is CollisionShape3D:
			shape_pos = child.position # 타일 기준 로컬 포지션 저장
			break
			
	var mesh_instance = MeshInstance3D.new()
	var dot_mesh = CylinderMesh.new()
	
	# 작고 납작한 원반(도트) 형태로 설정 (체스닷컴 스타일)
	dot_mesh.top_radius = 0.04
	dot_mesh.bottom_radius = 0.04
	dot_mesh.height = 0.005
	
	mesh_instance.mesh = dot_mesh
	mesh_instance.material_override = highlight_material
	
	board_grid.add_child(mesh_instance)
	# 위치를 콜리전 중앙에 맞추되 아주 살짝 위로 띄움
	mesh_instance.global_position = tile_node.to_global(shape_pos) + Vector3(0, 0.005, 0)
	
	highlight_nodes.append(mesh_instance)

func clear_valid_moves() -> void:
	for node in highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	highlight_nodes.clear()
	current_valid_moves.clear()

func attempt_move(piece: Node, target_tile_name: String) -> bool:
	if not target_tile_name in current_valid_moves:
		return false
		
	var start_tile = get_tile_of_piece(piece)
	if start_tile == "": return false
	
	var target_tile_node = board_grid.get_node_or_null(target_tile_name)
	if not target_tile_node: return false
	
	# 1. 적 기물 포획 처리
	if current_board_state.has(target_tile_name):
		var target_piece = current_board_state[target_tile_name]
		if is_instance_valid(target_piece) and target_piece != piece:
			target_piece.queue_free()
			
	# 2. 데이터 업데이트
	current_board_state.erase(start_tile)
	current_board_state[target_tile_name] = piece
	
	# 이동 시 하이라이트 지우기
	clear_valid_moves()
	
	# 3. Tween 부드러운 애니메이션
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 타일의 중앙을 향해 0.3초 동안 부드럽게 슬라이드
	var target_pos = target_tile_node.global_position
	tween.tween_property(piece, "global_position", target_pos, 0.3)
	
	return true
