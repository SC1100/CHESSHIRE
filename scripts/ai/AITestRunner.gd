extends Node

@onready var board_manager = $"../BoardManager"
var is_player_turn = true

# ==========================================
# [AI 가중치 조절 패널]
# 에디터 우측 인스펙터나 여기서 직접 수치를 변경하며 테스트하세요.
# ==========================================
@export var WEIGHT_PROXIMITY_BONUS: float = 1.5 # VIP에게 1칸 다가갈 때마다 얻는 보너스 점수 (좀비 호드 튜닝용)
@export var WEIGHT_THREAT_RATIO: float = 0.3 # 적군을 위협할 때 얻는 점수 비율 (0.3 = 적 가치의 20%)
@export var WEIGHT_DANGER_RATIO: float = 1.0 # 자신이 위험에 처했을 때 깎이는 점수 비율 (1.0 = 내 가치의 100%)
@export var WEIGHT_DEFENSE_RATIO: float = 0.05 # 아군을 수비할 때 얻는 점수 비율 (평시 5%)
@export var WEIGHT_ACTIVE_DEFENSE_RATIO: float = 0.2 # 적에게 공격받는 아군을 방어할 때의 점수 비율 (20%)
@export var WEIGHT_THREAT_REMOVAL_BONUS: float = 0.3 # 하위 기물로 상위 기물의 위협을 제거할 때 얻는 보너스 비율 (30%)
@export var WEIGHT_UNPROTECTED_CAPTURE_BONUS: float = 0.3 # 보호받지 않는 적 기물을 포획할 때 얻는 추가 보너스 비율 (30%)
# ==========================================

# --- 캐싱(Incremental Evaluation) 전용 상태 ---
var cache_base_score: float = 0.0
var cache_white_vips: Array[String] = []
var cache_piece_controls: Dictionary = {}
var cache_piece_control_pts: Dictionary = {}
var cache_tile_threats: Dictionary = {}

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
		
	# 시뮬레이션 전, 전체 보드를 1회만 순회하여 캐시를 생성합니다.
	_build_cache(board_manager.current_board_state)
		
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
	var sim_board = board_manager.current_board_state.duplicate()
	var cap_p = null
	if sim_board.has(target_tile):
		cap_p = sim_board[target_tile]
		if cap_p.is_in_group("VIP_Target"): return 9999999.0
		sim_board.erase(target_tile)
	
	sim_board.erase(start_tile)
	sim_board[target_tile] = piece
	
	var delta_black = 0.0
	var delta_white = 0.0
	
	# 1. 이동에 따른 기물 기본 가치 및 프록시미티 델타
	delta_black -= _get_base_score(piece, start_tile)
	delta_black += _get_base_score(piece, target_tile)
	
	if cap_p != null:
		var cap_val = _get_base_score(cap_p, target_tile)
		if cap_p.name.begins_with("B_"): delta_black -= cap_val
		else:
			delta_white -= cap_val
			# [보호받지 않는 기물 포획 보너스]
			var is_cap_protected = _is_tile_attacked_by_enemy(target_tile, piece.name.begins_with("B_"), board_manager.current_board_state)
			if not is_cap_protected:
				delta_black += _get_piece_value(cap_p) * 10.0 * WEIGHT_UNPROTECTED_CAPTURE_BONUS
		
		# [위협 제거 보너스 (Threat Removal Bonus)]
		# 하위 기물로 상위 기물(아군)에 가해지던 위협을 제거한 경우 보너스
		var mover_val = _get_piece_value(piece)
		if cache_piece_controls.has(cap_p.name):
			for c_tile in cache_piece_controls[cap_p.name]:
				if board_manager.current_board_state.has(c_tile):
					var saved_p = board_manager.current_board_state[c_tile]
					if is_instance_valid(saved_p) and (saved_p.name.begins_with("B_") == piece.name.begins_with("B_")):
						var saved_val = _get_piece_value(saved_p)
						# 나보다 가치가 높은 아군을 구출했는가?
						if mover_val < saved_val:
							var bonus = saved_val * 10.0 * WEIGHT_THREAT_REMOVAL_BONUS
							if piece.name.begins_with("B_"): delta_black += bonus
							else: delta_white += bonus
		
	# 2. 선 관통(Ray) 변화 및 타겟 변경에 의한 통제력 재계산 대상 식별
	var recalc_set = {}
	recalc_set[piece.name] = true
	if cap_p != null: recalc_set[cap_p.name] = false
	
	if cache_tile_threats.has(start_tile):
		for pn in cache_tile_threats[start_tile]: recalc_set[pn] = true
	if cache_tile_threats.has(target_tile):
		for pn in cache_tile_threats[target_tile]: recalc_set[pn] = true
		
	# 3. 통제력 델타 연산
	for pn in recalc_set.keys():
		var p_is_black = pn.begins_with("B_")
		
		# 기존 캐시된 점수 삭감
		if cache_piece_control_pts.has(pn):
			var old_pts = cache_piece_control_pts[pn]
			if p_is_black: delta_black -= old_pts
			else: delta_white -= old_pts
			
		# 새 상태에서 재계산 (생존한 기물만)
		if recalc_set[pn]:
			var cur_tile = ""
			var t_node = null
			for t in sim_board:
				if is_instance_valid(sim_board[t]) and sim_board[t].name == pn:
					cur_tile = t
					t_node = sim_board[t]
					break
					
			if cur_tile != "":
				var ctrls = _get_controlled_tiles(pn, cur_tile, sim_board)
				var new_pts = _calc_piece_ctrl_pts(t_node, p_is_black, ctrls, sim_board)
				if p_is_black: delta_black += new_pts
				else: delta_white += new_pts
				
	# 4. 캐시된 초기 점수에 델타를 합산
	var base_score = cache_base_score + delta_black - delta_white
	
	# 5. 위험 점수 (Danger Score)
	var is_in_danger = _is_tile_attacked_by_enemy(target_tile, piece.name.begins_with("B_"), sim_board)
	if is_in_danger:
		base_score -= _get_piece_value(piece) * 10.0 * WEIGHT_DANGER_RATIO
		
	return base_score

# 매 턴 1회 실행되어 전체 보드를 스캔하고 캐시를 빌드
func _build_cache(board: Dictionary):
	cache_white_vips.clear()
	cache_piece_controls.clear()
	cache_piece_control_pts.clear()
	cache_tile_threats.clear()
	
	var b_score = 0.0
	var w_score = 0.0
	
	# VIP 위치 식별
	for tile in board:
		var p = board[tile]
		if is_instance_valid(p) and p.is_in_group("VIP_Target") and p.name.begins_with("W_"):
			cache_white_vips.append(tile)
			
	for tile in board:
		var p = board[tile]
		if not is_instance_valid(p): continue
		var p_black = p.name.begins_with("B_")
		
		var val = _get_base_score(p, tile)
		if p_black: b_score += val
		else: w_score += val
		
		var ctrls = _get_controlled_tiles(p.name, tile, board)
		cache_piece_controls[p.name] = ctrls
		
		var pts = _calc_piece_ctrl_pts(p, p_black, ctrls, board)
		cache_piece_control_pts[p.name] = pts
		if p_black: b_score += pts
		else: w_score += pts
		
		for c_tile in ctrls:
			if not cache_tile_threats.has(c_tile):
				cache_tile_threats[c_tile] = []
			cache_tile_threats[c_tile].append(p.name)
			
	cache_base_score = b_score - w_score

# 기물의 기본 가치 + VIP 근접 가중치 계산
func _get_base_score(piece: Node, tile: String) -> float:
	var val = _get_piece_value(piece) * 10.0
	# 자신이 킹(VIP)인 경우 사냥개가 아니므로 거리 보너스를 받지 않음
	if piece.name.begins_with("B_") and not piece.is_in_group("VIP_Target"):
		for vip in cache_white_vips:
			val += (14.0 - _get_manhattan_distance(tile, vip)) * WEIGHT_PROXIMITY_BONUS
	return val

# 기물의 통제력(Grid Control) 점수 산출
func _calc_piece_ctrl_pts(piece: Node, is_black: bool, controls: Array[String], board: Dictionary) -> float:
	var pts = 0.0
	for c_tile in controls:
		pts += _get_static_tile_value(c_tile)
		if _is_near_enemy(c_tile, is_black, board):
			pts += 20.0
		if board.has(c_tile):
			var tp = board[c_tile]
			if is_instance_valid(tp):
				if is_black == tp.name.begins_with("B_"):
					var def_val = _get_piece_value(tp)
					if tp.is_in_group("VIP_Target") or "King" in tp.name:
						def_val = 0.0 # 킹(메인 타겟)은 포획 시 게임 오버이므로 '교환'을 가정한 방어 점수 산정에서 제외
						
					if _is_tile_attacked_by_enemy(c_tile, is_black, board):
						pts += def_val * WEIGHT_ACTIVE_DEFENSE_RATIO
					else:
						pts += def_val * WEIGHT_DEFENSE_RATIO
				else:
					pts += _get_piece_value(tp) * WEIGHT_THREAT_RATIO
	return pts


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

# 특정 타일이 적군에게 현재 공격(위협)받고 있는지 판별
func _is_tile_attacked_by_enemy(target_tile: String, is_black: bool, board: Dictionary) -> bool:
	for tile in board:
		var p = board[tile]
		if is_instance_valid(p):
			if p.name.begins_with("B_") != is_black:
				if ChessRules.is_move_valid(p.name, tile, target_tile, board):
					return true
	return false

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
	# 그룹 부여가 누락되는 초기화 시점 버그를 대비한 안전장치(Fallback)
	if piece.is_in_group("VIP_Target") or "King" in piece.name:
		return 99999.0
		
	# 정체 현상(오실레이션) 해결을 위해 통제력 대비 기물 가치를 5배 상향 조정
	var piece_name = piece.name
	if "Pawn" in piece_name: return 25.0
	if "Knight" in piece_name or "Bishop" in piece_name: return 75.0
	if "Rook" in piece_name: return 125.0
	if "Queen" in piece_name: return 225.0
	return 0.0

# 두 타일 사이의 맨해튼 거리(격자 이동 거리) 계산
func _get_manhattan_distance(tile1: String, tile2: String) -> float:
	var c1 = tile1[0].unicode_at(0)
	var r1 = int(tile1[1])
	var c2 = tile2[0].unicode_at(0)
	var r2 = int(tile2[1])
	return abs(c1 - c2) + abs(r1 - r2)
