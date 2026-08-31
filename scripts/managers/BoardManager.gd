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
static var current_stage_id: String = "test_stage"
var stages: Dictionary = {}

var board_grid: Node3D
var current_board_state: Dictionary = {} # 타일 이름("a1") -> 기물 노드 매핑

var highlight_nodes: Array[Node] = []
var current_valid_moves: Array[String] = []
var highlight_material: StandardMaterial3D

# --- Player Team Control ---
@export var player_team: PieceData.Team = PieceData.Team.WHITE

# 기물이 플레이어 진영(아군)인지 판별하는 헬퍼 함수
func is_player_piece(piece: Node) -> bool:
	if not is_instance_valid(piece): return false
	if piece.has_method("get_team"):
		return piece.get_team() == player_team
	if piece.get("data") and piece.get("data").get("team") != null:
		return piece.get("data").team == player_team
	if player_team == PieceData.Team.WHITE:
		return piece.name.begins_with("W_")
	else:
		return piece.name.begins_with("B_")

# 아군 기물 전멸 태그 등록 목록 및 검사 함수
var eliminated_player_piece_tags: Array[String] = []

func _check_and_register_eliminated_piece_type(captured_piece: Node) -> void:
	if not is_instance_valid(captured_piece): return
	var p_type = ""
	for tag in ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]:
		if tag.to_lower() in captured_piece.name.to_lower():
			p_type = tag
			break
			
	if p_type == "": return
	
	# 체스판 위 다른 아군 기물 중 동일 기물 종류가 남아있는지 검사 (captured_piece 제외)
	var is_still_alive = false
	for tile_name in current_board_state:
		var board_p = current_board_state[tile_name]
		if is_instance_valid(board_p) and board_p != captured_piece and is_player_piece(board_p):
			if p_type.to_lower() in board_p.name.to_lower():
				is_still_alive = true
				break
				
	if not is_still_alive:
		if not eliminated_player_piece_tags.has(p_type):
			eliminated_player_piece_tags.append(p_type)
			print("BoardManager: 플레이어의 '%s' 기물이 전멸했습니다! 소멸 플래그 목록에 등록됨." % p_type)

# --- Action Tokens ---
var active_tokens: Dictionary = {
	"Pawn": 0, "Knight": 0, "Bishop": 0, "Rook": 0, "Queen": 0, "King": 0
}

func add_action_token(piece_tag: String, amount: int = 1) -> void:
	if active_tokens.has(piece_tag):
		active_tokens[piece_tag] += amount
		print("[BoardManager] %s 행동권 추가됨! 현재 남은 행동권: %d" % [piece_tag, active_tokens[piece_tag]])
	else:
		push_warning("알 수 없는 기물 토큰 추가 시도: " + piece_tag)

func consume_action_token(piece_tag: String) -> bool:
	if active_tokens.has(piece_tag) and active_tokens[piece_tag] > 0:
		active_tokens[piece_tag] -= 1
		print("[BoardManager] %s 행동권 소모됨. 남은 행동권: %d" % [piece_tag, active_tokens[piece_tag]])
		return true
	return false

func has_action_token(piece_tag: String) -> bool:
	return active_tokens.has(piece_tag) and active_tokens[piece_tag] > 0

func reset_all_action_tokens() -> void:
	for key in active_tokens.keys():
		active_tokens[key] = 0
	
	# 모든 기물의 개인 이동 횟수 초기화
	for piece in current_board_state.values():
		if is_instance_valid(piece) and piece is Piece:
			piece.reset_moves()

func get_piece_name_on_tile(tile_name: String) -> String:
	if current_board_state.has(tile_name) and is_instance_valid(current_board_state[tile_name]):
		return current_board_state[tile_name].name
	return ""

func _ready():
	add_to_group("BoardManager")
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
		
	# 설정된 current_stage_id 스테이지 자동 배치
	# 콜리전 계산 등을 안전하게 처리하기 위해 프레임 끝에 호출(call_deferred)
	call_deferred("load_stage", current_stage_id)

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
	
	# 스테이지 메타데이터(grid_info)는 Grid 스크립트(rules/Grid.gd)로 넘겨서 관리합니다.
	var grid_info = stage_data.get("grid_info", {})
	Grid.setup(grid_info)
	
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
		
		# Piece.gd 스크립트가 없다면 강제로 부착
		var piece_script = preload("res://scripts/Piece.gd")
		if piece_instance.get_script() != piece_script:
			piece_instance.set_script(piece_script)
			piece_instance.set("move_count", 0)
			piece_instance.set("max_moves", 1)
		
		# 씬 트리에 추가 및 고유 이름 설정 (예: B_Pawn_1)
		piece_instance.name = piece_key + "_" + str(piece_counts[piece_key])
		add_child(piece_instance)
		
		# Piece 그룹 및 킹/승리 목표 기물에 Objective 그룹 자동 부여
		piece_instance.add_to_group("Piece")
		if "King" in piece_key or "Objective" in piece_key:
			piece_instance.add_to_group("Objective")
			print("BoardManager: '%s' 기물에 'Objective' 승리목표 그룹을 설정했습니다." % piece_instance.name)
		
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
	var is_victory_captured: bool = false
	var is_defeat_captured: bool = false
	if current_board_state.has(target_tile_name):
		var target_piece = current_board_state[target_tile_name]
		if is_instance_valid(target_piece) and target_piece != piece:
			var is_obj = target_piece.is_in_group("Objective") or "King" in target_piece.name
			if is_obj:
				if not is_player_piece(target_piece):
					is_victory_captured = true
				else:
					is_defeat_captured = true
			
			# 아군 기물이 잡힌 경우 전멸 상태 검사 및 등록
			if is_player_piece(target_piece):
				_check_and_register_eliminated_piece_type(target_piece)

			target_piece.queue_free()
			
	# 2. 데이터 업데이트
	current_board_state.erase(start_tile)
	current_board_state[target_tile_name] = piece
	
	# 이동 시 하이라이트 지우기
	clear_valid_moves()
	
	# 캐슬링 판별 (킹이 2칸 이동 시)
	var is_castling: bool = false
	var rook_to_move: Node = null
	var rook_target_tile_name: String = ""
	
	if "King" in piece.name:
		var start_grid = ChessRules.get_grid_pos(start_tile)
		var target_grid = ChessRules.get_grid_pos(target_tile_name)
		var dx = target_grid.x - start_grid.x
		if abs(dx) == 2:
			is_castling = true
			var is_kingside = (dx == 2)
			var row_str = start_tile.substr(1)
			var rook_start_tile = ("h" if is_kingside else "a") + row_str
			rook_target_tile_name = ("f" if is_kingside else "d") + row_str
			rook_to_move = current_board_state.get(rook_start_tile)
			if is_instance_valid(rook_to_move):
				current_board_state.erase(rook_start_tile)
				current_board_state[rook_target_tile_name] = rook_to_move
				if rook_to_move.has_method("record_move"):
					rook_to_move.record_move()

	# 기물 이동 횟수 기록
	if piece.has_method("record_move"):
		piece.record_move()

	# 폰 프로모션 판별
	var is_promotion: bool = false
	if "Pawn" in piece.name:
		var target_row = int(target_tile_name.substr(1))
		var max_row = Grid.current_grid_info.get("max_row", 8)
		var is_white = piece.name.begins_with("W_")
		if (is_white and target_row == max_row) or (not is_white and target_row == 1):
			is_promotion = true
	
	# 3. Tween 부드러운 애니메이션 (병렬 실행)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 타일의 중앙을 향해 0.3초 동안 부드럽게 슬라이드
	var target_pos = target_tile_node.global_position
	tween.tween_property(piece, "global_position", target_pos, 0.3)
	
	if is_castling and is_instance_valid(rook_to_move):
		var rook_target_tile_node = board_grid.get_node_or_null(rook_target_tile_name)
		if rook_target_tile_node:
			tween.tween_property(rook_to_move, "global_position", rook_target_tile_node.global_position, 0.3)
	
	if is_victory_captured:
		tween.finished.connect(trigger_victory)
	elif is_defeat_captured:
		tween.finished.connect(trigger_defeat)
	elif is_promotion:
		tween.finished.connect(func(): _handle_pawn_promotion(piece, target_tile_name))
	
	return true

func _handle_pawn_promotion(pawn_piece: Node, target_tile_name: String) -> void:
	if not is_instance_valid(pawn_piece): return
	
	var is_white = pawn_piece.name.begins_with("W_")
	
	if is_white:
		# 플레이어 백 폰 승급: PromotionUI 팝업
		var promo_ui = PromotionUI.new()
		add_child(promo_ui)
		promo_ui.promotion_selected.connect(func(chosen_piece_type: String):
			_execute_promotion(pawn_piece, target_tile_name, is_white, chosen_piece_type)
		)
	else:
		# AI 흑 폰 승급: 자동 퀸(Queen) 승급
		_execute_promotion(pawn_piece, target_tile_name, is_white, "Queen")

func _execute_promotion(pawn_piece: Node, target_tile_name: String, is_white: bool, piece_type: String) -> void:
	if not is_instance_valid(pawn_piece): return
	
	var tile_node = board_grid.get_node_or_null(target_tile_name)
	if not tile_node: return
	
	var prefix = "W_" if is_white else "B_"
	var piece_key = prefix + piece_type # 예: "W_Queen"
	
	if not piece_scenes.has(piece_key):
		push_error("BoardManager: 승급할 기물 씬 키가 없습니다 - %s" % piece_key)
		return
		
	var parent_node = pawn_piece.get_parent() if is_instance_valid(pawn_piece.get_parent()) else self
	var pawn_scale = pawn_piece.scale
	
	# 1. 새 3D 기물 노드 생성 및 설정
	var new_piece = piece_scenes[piece_key].instantiate()
	
	# Piece.gd 스크립트가 없다면 강제로 부착
	var piece_script = preload("res://scripts/Piece.gd")
	if new_piece.get_script() != piece_script:
		new_piece.set_script(piece_script)
		new_piece.set("move_count", 1)
		new_piece.set("max_moves", 1)
		
	new_piece.name = piece_key + "_" + str(randi() % 10000)
	parent_node.add_child(new_piece)
	
	new_piece.add_to_group("Piece")
	if "King" in piece_key or "Objective" in piece_key:
		new_piece.add_to_group("Objective")
		
	new_piece.scale = pawn_scale
	new_piece.global_position = tile_node.global_position
	
	# 2. 보드 상태 갱신 및 기존 폰 파괴
	current_board_state[target_tile_name] = new_piece
	pawn_piece.queue_free()
	
	print("★ [PROMOTION] %s 폰이 %s(으)로 승급되었습니다! ★" % [prefix, piece_type])
	
	# 3. 플레이어 기물 승급 시 사멸 플래그 해제 및 전투 덱에 카드 1장 추가
	if is_white:
		# (1) 사멸/전멸 플래그 목록에서 해당 승급 기물 태그 제거
		if eliminated_player_piece_tags.has(piece_type):
			eliminated_player_piece_tags.erase(piece_type)
			print("BoardManager: 승급으로 인해 '%s' 전멸 플래그가 해제되었습니다!" % piece_type)
			
		# (2) 승급한 기물 카드 1장을 플레이어의 손패로 즉시 추가 (드로우 연출가동)
		var card_id = "w_" + piece_type.to_lower() # 예: "w_queen"
		var card_managers = get_tree().get_nodes_in_group("CardManager")
		if card_managers.size() > 0:
			var card_manager = card_managers[0]
			if card_manager.has_method("add_card_directly_to_hand"):
				card_manager.add_card_directly_to_hand(card_id)
				print("BoardManager: 승급한 기물 카드('%s') 1장이 플레이어 손패로 즉시 추가되었습니다!" % card_id)

var is_game_over: bool = false

func trigger_victory() -> void:
	if is_game_over: return
	is_game_over = true
	print("★ [VICTORY] 승리하였습니다! ★")
	
	var canvas = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var label = Label.new()
	label.text = "VICTORY!"
	label.add_theme_font_size_override("font_size", 110)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2(0.2, 0.2)
	label.modulate.a = 0.0
	label.pivot_offset = Vector2(240, 70) # 110px 서체 대략적 텍스트 중앙 피벗
	center.add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.35)
	
	await get_tree().create_timer(1.8).timeout
	
	var tween_out = create_tween()
	tween_out.tween_property(label, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	canvas.queue_free()
	
	var reward_script = load("res://scripts/ui/RewardUI.gd")
	if reward_script:
		var reward_ui = reward_script.new()
		add_child(reward_ui)

func trigger_defeat() -> void:
	if is_game_over: return
	is_game_over = true
	print("☠ [DEFEATED] 패배하였습니다... ☠")
	
	var canvas = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var label = Label.new()
	label.text = "DEFEATED"
	label.add_theme_font_size_override("font_size", 110)
	label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2(0.2, 0.2)
	label.modulate.a = 0.0
	label.pivot_offset = Vector2(260, 70)
	center.add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.35)
	
	await get_tree().create_timer(2.0).timeout
	
	var tween_out = create_tween()
	tween_out.tween_property(label, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	canvas.queue_free()
	
	_show_defeat_ui()

func _show_defeat_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.02, 0.02, 0.9)
	canvas.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(600, 300)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)
	
	var t_label = Label.new()
	t_label.text = "DEFEATED..."
	t_label.add_theme_font_size_override("font_size", 48)
	t_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	t_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t_label)
	
	var sub_label = Label.new()
	sub_label.text = "플레이어의 왕(Objective)이 파괴되었습니다."
	sub_label.add_theme_font_size_override("font_size", 20)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	var retry_btn = Button.new()
	retry_btn.text = "스테이지 선택으로 돌아가기"
	retry_btn.custom_minimum_size = Vector2(250, 50)
	retry_btn.add_theme_font_size_override("font_size", 18)
	retry_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Scene/Stage.tscn"))
	vbox.add_child(retry_btn)
