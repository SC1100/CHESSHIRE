extends Node

@onready var board_manager = $"../BoardManager"
var is_player_turn = true

func _ready():
	# 턴 넘기기 버튼 UI 생성
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var btn = Button.new()
	btn.text = "턴 넘기기 (AI 행동) [Z]"
	btn.position = Vector2(20, 100)
	btn.size = Vector2(300, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_enemy_turn)
	canvas.add_child(btn)
	
	# 임시 테스트: 게임 시작 시 필드에 있는 킹들에게 'VIP_Target' 태그 부여
	# 나중에는 맵 에디터에서 마차나 크리스탈 같은 오브젝트에 직접 이 그룹을 할당하면 됩니다.
	for tile in board_manager.current_board_state:
		var p = board_manager.current_board_state[tile]
		if is_instance_valid(p) and "King" in p.name:
			p.add_to_group("VIP_Target")
			
	print("AITestRunner: 격리된 테스트 환경(타겟 시스템 포함)이 준비되었습니다.")

# 단축키 Z 입력 감지
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_on_enemy_turn()

func _on_enemy_turn():
	if not is_player_turn: return
	is_player_turn = false
	
	# 모든 흑색 기물 찾기
	var black_pieces = []
	for tile in board_manager.current_board_state:
		var piece = board_manager.current_board_state[tile]
		if is_instance_valid(piece) and piece.name.begins_with("B_"):
			black_pieces.append(piece)
			
	if black_pieces.is_empty():
		print("남은 적 기물이 없습니다.")
		is_player_turn = true
		return
		
	var best_piece = null
	var best_tile = ""
	var highest_score = -9999.0
	
	# 모든 흑색 기물의 유효한 이동을 순회하여 가장 높은 점수의 행동을 하나 고름
	for piece in black_pieces:
		var start_tile = board_manager.get_tile_of_piece(piece)
		
		var valid_tiles: Array[String] = []
		
		var cols = ["a", "b", "c", "d", "e", "f", "g", "h"]
		for col in cols:
			for row in range(1, 9):
				var target = col + str(row)
				if ChessRules.is_move_valid(piece.name, start_tile, target, board_manager.current_board_state):
					valid_tiles.append(target)
					
		# 해당 기물의 각 후보지에 대해 채점 (보드 시뮬레이터로 넘김)
		for target in valid_tiles:
			var score = _simulate_and_evaluate(piece, start_tile, target)
			
			# 약간의 난수를 더해 동점일 때 기계적 반복 회피
			score += randf_range(-1.0, 1.0)
			
			if score > highest_score:
				highest_score = score
				best_tile = target
				best_piece = piece
				
	if best_piece == null:
		print("AI: 아무 기물도 이동할 곳이 없습니다.")
		is_player_turn = true
		return
			
	# 이동 실행
	board_manager.current_valid_moves.clear()
	board_manager.current_valid_moves.append(best_tile) # Manager 내부 검증 통과용
	board_manager.attempt_move(best_piece, best_tile)
	print("AI 결정: ", best_piece.name, " ➔ ", best_tile, " (가치 점수: ", round(highest_score), ")")
	
	is_player_turn = true

func _simulate_and_evaluate(piece: Node, start_tile: String, target_tile: String) -> float:
	# 1. 시뮬레이션용 가상 보드 복사
	var sim_board = board_manager.current_board_state.duplicate()
	
	# 이동 실행 (기존 자리 비우기 -> 적 있으면 삭제 -> 새 자리 차지)
	sim_board.erase(start_tile)
	if sim_board.has(target_tile):
		sim_board.erase(target_tile)
	sim_board[target_tile] = piece
	
	# 2. 글로벌 보드 가치 평가 (나의 총합 - 적의 총합)
	return _evaluate_board_state(sim_board)

# 보드 전체의 기물 가치와 "통제력(Grid Control)"을 종합 산출
func _evaluate_board_state(board: Dictionary) -> float:
	var black_score = 0.0
	var white_score = 0.0
	
	# 목표물 추적을 위한 백색 진영 VIP 타일 위치 수집
	var white_vip_tiles = []
	for tile in board.keys():
		var p = board[tile]
		if is_instance_valid(p) and p.is_in_group("VIP_Target") and p.name.begins_with("W_"):
			white_vip_tiles.append(tile)
	
	for tile in board.keys():
		var p = board[tile]
		if not is_instance_valid(p): continue
		
		var is_black = p.name.begins_with("B_")
		var piece_val = _get_piece_value(p) * 10.0 # 폰 50, 타겟 100000
		
		if is_black: 
			black_score += piece_val
			# 흑색 기물일 경우, 백색 VIP와의 거리를 계산해 은은한 '사냥개' 보너스를 부여
			for vip_tile in white_vip_tiles:
				var dist = _get_manhattan_distance(tile, vip_tile)
				# 맵의 최대 거리(약 14)에서 가까워질수록 보너스. (거리가 1 줄어들 때마다 +1.5점)
				# 이 점수는 포획/통제 점수(수십~수백점)보다 훨씬 낮아, 무의미한 자살 돌격을 방지합니다.
				black_score += (14.0 - dist) * 1.5
		else: 
			white_score += piece_val
			
		# 통제하고 있는 그리드(이동/공격 가능 칸) 수집
		var controlled_tiles = _get_controlled_tiles(p.name, tile, board)
		for c_tile in controlled_tiles:
			var ctrl_pts = _get_static_tile_value(c_tile)
			
			# [동적 통제력] 사냥감(적) 주변을 통제하면 가산점
			if _is_near_enemy(c_tile, is_black, board):
				ctrl_pts += 20.0
				
			# [상호 방어 통제력] 내가 통제하는 칸에 기물이 있다면
			if board.has(c_tile):
				var target_p = board[c_tile]
				if is_instance_valid(target_p):
					var target_is_black = target_p.name.begins_with("B_")
					if is_black == target_is_black:
						# 아군을 지켜주고 있다면 그 아군 가치의 10% 획득 (수비 진형)
						ctrl_pts += _get_piece_value(target_p) * 1.0
					else:
						# 적군을 위협하고 있다면 그 적 가치의 50% 획득 (위협 점수)
						# 적 VIP를 노리면 여기서 10000 * 5.0 = +50000점이 터짐!
						ctrl_pts += _get_piece_value(target_p) * 5.0
						
			if is_black: black_score += ctrl_pts
			else: white_score += ctrl_pts
			
	# 나의 점수(Black) - 적의 점수(White)의 격차(Zero-Sum) 반환
	return black_score - white_score

# 특정 기물이 통제(이동/공격)할 수 있는 모든 칸 반환
func _get_controlled_tiles(piece_name: String, start_tile: String, board: Dictionary) -> Array[String]:
	var controlled: Array[String] = []
	var cols = ["a", "b", "c", "d", "e", "f", "g", "h"]
	for c in cols:
		for r in range(1, 9):
			var target = c + str(r)
			# 아군이 있는 칸도 '수비' 목적으로 통제력을 계산하기 위해
			# 임시로 해당 칸의 아군을 뺀 상태에서 이동 유효성을 검사합니다.
			var temp_p = null
			if board.has(target):
				temp_p = board[target]
				board.erase(target)
				
			if ChessRules.is_move_valid(piece_name, start_tile, target, board):
				controlled.append(target)
				
			if temp_p != null:
				board[target] = temp_p # 원상 복구
	return controlled

# 정적 그리드 점수 (지형 자체의 절대 가치)
func _get_static_tile_value(tile: String) -> float:
	var col = tile[0]
	var row = int(tile[1])
	if col in ["d", "e"] and row in [4, 5]: return 15.0 # 절대 중앙
	if col in ["c", "d", "e", "f"] and row in [3, 4, 5, 6]: return 8.0 # 확장 중앙
	if col in ["a", "h"] or row in [1, 8]: return 0.0 # 구석/벽면
	return 2.0 # 일반 필드

# 특정 타일 주변 반경 1칸 이내에 적 기물이 있는지 판별
func _is_near_enemy(tile: String, is_black: bool, board: Dictionary) -> bool:
	var col_idx = tile[0].unicode_at(0)
	var row_idx = int(tile[1])
	for c in range(col_idx - 1, col_idx + 2):
		for r in range(row_idx - 1, row_idx + 2):
			if c < 97 or c > 104 or r < 1 or r > 8: continue
			var check_tile = String.chr(c) + str(r)
			if board.has(check_tile):
				var p = board[check_tile]
				if is_instance_valid(p):
					if is_black and p.name.begins_with("W_"): return true
					if not is_black and p.name.begins_with("B_"): return true
	return false

# 기물별 가중치 반환 함수 (Node를 인자로 받아 그룹 검사)
func _get_piece_value(piece: Node) -> float:
	# 하드코딩 배제: 이름에 상관없이 "VIP_Target" 그룹(태그)이 있으면 무조건 게임 오버급 가치 부여
	if piece.is_in_group("VIP_Target"): 
		return 10000.0
		
	var piece_name = piece.name
	if "Pawn" in piece_name: return 5.0
	if "Knight" in piece_name or "Bishop" in piece_name: return 15.0
	if "Rook" in piece_name: return 25.0
	if "Queen" in piece_name: return 45.0
	return 0.0

# 두 타일 사이의 맨해튼 거리(격자 이동 거리) 계산
func _get_manhattan_distance(tile1: String, tile2: String) -> float:
	var c1 = tile1[0].unicode_at(0)
	var r1 = int(tile1[1])
	var c2 = tile2[0].unicode_at(0)
	var r2 = int(tile2[1])
	return abs(c1 - c2) + abs(r1 - r2)
