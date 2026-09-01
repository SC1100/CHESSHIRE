class_name ChessRules
extends RefCounted

# 타일 이름(예: "a1", "h8")을 2D 좌표로 변환 (x: 0~7, y: 0~7)
static func get_grid_pos(tile_name: String) -> Vector2:
	# 알파벳 a~z를 0~25로 변환
	var col = tile_name.unicode_at(0) - "a".unicode_at(0)
	var row = int(tile_name.substr(1)) - 1
	return Vector2(col, row)

# 이동이 가능한지 판별하는 핵심 룰 함수
# piece_name: "W_Pawn_1", "B_Rook_2" 등
# start_tile, target_tile: "a2", "a4" 등
# board_state: 현재 배치된 기물 상태 (키: 타일 이름)
# custom_rules: 카드로 인해 추가된 특수 룰 키워드 배열 (예: ["ignore_friendly_fire", "pawn_backward", "ghost_movement"])
static func is_move_valid(piece_name: String, start_tile: String, target_tile: String, board_state: Dictionary, custom_rules: Array = []) -> bool:
	# 1. 제자리 이동 금지
	if start_tile == target_tile:
		return false
		
	var is_white = piece_name.begins_with("W_")
	
	# 2. 목적지에 아군 기물이 있는지 확인 (아군 공격 불가 룰)
	if board_state.has(target_tile):
		var target_piece = board_state[target_tile]
		if is_instance_valid(target_piece):
			var target_is_white = target_piece.name.begins_with("W_")
			if is_white == target_is_white:
				# 특수 카드가 아군 공격/포획을 허용하지 않는 이상 이동 불가
				if not custom_rules.has("ignore_friendly_fire") and not custom_rules.has("allow_friendly_capture"):
					return false
				# 아군 킹 기물은 포획 대상에서 제외 (아군 킹 자멸 방지)
				if "King" in target_piece.name or target_piece.is_in_group("Objective"):
					return false
	
	var start_pos = get_grid_pos(start_tile)
	var target_pos = get_grid_pos(target_tile)
	var dx = target_pos.x - start_pos.x
	var dy = target_pos.y - start_pos.y
	var abs_dx = abs(dx)
	var abs_dy = abs(dy)
	
	# 기물의 원본 종류 파악 (예: W_Pawn_1 -> Pawn)
	var parts = piece_name.split("_")
	var piece_type = ""
	if parts.size() >= 2:
		piece_type = parts[1]
		
	# 3. 기물별 고유 이동 패턴 판별
	match piece_type:
		"Pawn":
			var forward = 1 if is_white else -1
			var start_row = 1 if is_white else 6 # 0-indexed (a2는 row 1, a7은 row 6)
			
			# 3-1. 직진 이동 (적을 공격할 수 없음)
			if dx == 0:
				if not board_state.has(target_tile):
					# 기본 1칸 전진
					if dy == forward:
						return true
					# 첫 턴 2칸 전진 (중간에 기물이 없어야 함)
					if start_pos.y == start_row and dy == forward * 2:
						var mid_tile = String.chr("a".unicode_at(0) + int(start_pos.x)) + str(int(start_pos.y) + forward + 1)
						if not board_state.has(mid_tile):
							return true
							
			# 3-2. 대각선 이동 (오직 적을 공격할 때만 가능)
			elif abs_dx == 1 and dy == forward:
				if board_state.has(target_tile):
					return true
			
			# [카드 효과 예시] 뒤로 이동 가능 카드
			if custom_rules.has("pawn_backward") and dy == -forward and dx == 0 and not board_state.has(target_tile):
				return true
				
			return false

		"Knight":
			# L자 이동 (기본적으로 장애물 무시, knight_no_jump 규칙 시 인접 길목 장애물 검사)
			if (abs_dx == 2 and abs_dy == 1) or (abs_dx == 1 and abs_dy == 2):
				if custom_rules.has("knight_no_jump"):
					# 직진 1칸 앞 인접 타일(길목) 위치 계산
					var step_x = sign(dx) if abs_dx == 2 else 0
					var step_y = sign(dy) if abs_dy == 2 else 0
					var first_step_pos = Vector2(start_pos.x + step_x, start_pos.y + step_y)
					var first_step_tile = String.chr("a".unicode_at(0) + int(first_step_pos.x)) + str(int(first_step_pos.y) + 1)
					if board_state.has(first_step_tile):
						return false
				return true
			return false

		"Rook":
			if abs_dx == 0 or abs_dy == 0:
				# [카드 효과 예시] 장애물 관통(유령 이동) 카드
				if custom_rules.has("ghost_movement"): return true
				return _is_path_clear(start_pos, target_pos, board_state)
			return false

		"Bishop":
			if abs_dx == abs_dy:
				if custom_rules.has("ghost_movement"): return true
				return _is_path_clear(start_pos, target_pos, board_state)
			elif is_white and custom_rules.has("bishop_straight_move") and (abs_dx == 0 or abs_dy == 0):
				if custom_rules.has("ghost_movement"): return true
				return _is_path_clear(start_pos, target_pos, board_state)
			return false

		"Queen":
			if abs_dx == 0 or abs_dy == 0 or abs_dx == abs_dy:
				if custom_rules.has("ghost_movement"): return true
				return _is_path_clear(start_pos, target_pos, board_state)
			return false

		"King":
			# 일반 이동 (모든 방향 1칸)
			if abs_dx <= 1 and abs_dy <= 1:
				return true
				
			# 캐슬링 이동 (가로 2칸 이동, 세로 이동 없음)
			if abs_dy == 0 and (dx == 2 or dx == -2):
				var king_piece = board_state.get(start_tile)
				if not is_instance_valid(king_piece): return false
				
				# 1. 킹이 이번 게임에서 이동한 적이 없어야 함
				if king_piece.get("move_count") != null and king_piece.move_count > 0:
					return false
					
				var row_str = start_tile.substr(1) # "1" 또는 "8" 등
				var is_kingside = (dx == 2)
				var rook_col = "h" if is_kingside else "a"
				var rook_tile = rook_col + row_str
				
				var rook_piece = board_state.get(rook_tile)
				if not is_instance_valid(rook_piece): return false
				
				# 2. 룩이 이번 게임에서 이동한 적이 없어야 함
				if rook_piece.get("move_count") != null and rook_piece.move_count > 0:
					return false
					
				# 3. 킹과 룩 사이의 타일들이 모두 비어있어야 함
				var between_cols = ["f", "g"] if is_kingside else ["b", "c", "d"]
				for b_col in between_cols:
					var b_tile = b_col + row_str
					if board_state.has(b_tile) and is_instance_valid(board_state[b_tile]):
						return false
						
				return true
				
			return false

	# 등록되지 않은 기물이면 기본적으로 이동 불가
	return false

# 룩, 비숍, 퀸의 이동 경로 상에 장애물이 있는지 검사
static func _is_path_clear(start_pos: Vector2, target_pos: Vector2, board_state: Dictionary) -> bool:
	var dx = sign(target_pos.x - start_pos.x)
	var dy = sign(target_pos.y - start_pos.y)
	
	var curr_x = start_pos.x + dx
	var curr_y = start_pos.y + dy
	
	# 목적지에 도달할 때까지 1칸씩 검사
	while int(curr_x) != int(target_pos.x) or int(curr_y) != int(target_pos.y):
		var tile_name = String.chr("a".unicode_at(0) + int(curr_x)) + str(int(curr_y) + 1)
		# 중간 경로에 기물이 존재하면 이동 불가
		if board_state.has(tile_name):
			return false
		curr_x += dx
		curr_y += dy
		
	return true
