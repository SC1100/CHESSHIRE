class_name ChessAIBrainConcept
extends Node

# AI의 '성격'을 결정하는 조율 변수 (인스펙터에서 적마다 다르게 설정 가능)
@export var aggressiveness: float = 1.0 # 공격성: 높을수록 무리해서라도 플레이어를 향해 돌격
@export var survival: float = 1.5       # 생존성: 높을수록 위험한 타일을 극도로 기피함

# ==========================================================
# 1. 의사결정 루프 진입점 (AI 턴 시작 시 호출됨)
# ==========================================================
func decide_next_move(current_pos: Vector2i, piece_type: String, board_manager) -> Vector2i:
	
	# [STEP 1] 보드 상태 분석: 
	# 플레이어가 이번 턴에 공격할 수 있는 '위험 타일(Threat Map)' 목록과
	# 현재 위치에서 플레이어에게 도달하기 위한 A* 최적 경로를 계산합니다.
	var threat_map = board_manager.get_threat_map() 
	var path_to_player = _calculate_astar_path(current_pos, board_manager.player_pos, board_manager)
	
	# [STEP 2] 이동 가능 반경 탐색:
	# 이 기물(예: 나이트)이 현재 룰 상 이동할 수 있는 모든 유효 타일 배열을 가져옵니다.
	var valid_moves = board_manager.get_valid_moves(current_pos, piece_type)
	
	var best_move = current_pos
	var highest_score = -9999.0
	
	# [STEP 3] 가치 평가 (Scoring):
	# 이동 가능한 타일들을 하나씩 돌아보며 가장 점수가 높은 타일을 찾아냅니다.
	for move in valid_moves:
		var score = _evaluate_move(move, path_to_player, threat_map, board_manager)
		
		# 가장 점수가 높은 타일을 갱신
		if score > highest_score:
			highest_score = score
			best_move = move
			
	# [STEP 4] 결정된 좌표 반환 -> 3D 체스 기물은 이 좌표로 애니메이션 이동 실행
	return best_move


# ==========================================================
# 2. 이동 타일 채점 (가치 평가 로직의 핵심 두뇌)
# ==========================================================
func _evaluate_move(target: Vector2i, path: Array, threat_map: Dictionary, board) -> float:
	var score = 0.0
	
	# [가중치 1] 타겟 도달 (1순위 목표): 
	# 이 타일로 이동하면 바로 플레이어를 칠 수 있는가?
	if target == board.player_pos:
		score += 1000.0 * aggressiveness
		
	# [가중치 2] 장기 목표 지향성 (A* 알고리즘 연동):
	# 지금 당장 때리지 못하더라도, A*가 추천해준 '최단 경로' 위에 있는 칸인가?
	if target in path:
		# 경로 배열의 뒤쪽(플레이어에게 가까운 쪽)일수록 더 높은 보너스 점수 부여
		var path_index = path.find(target)
		score += 50.0 + (path_index * 10.0) 
		
	# [가중치 3] 생존 본능 (영향력 맵 연동):
	# 이 타일로 이동했을 때 플레이어에게 역으로 죽을 위험이 있는가?
	if threat_map.has(target):
		var danger_level = threat_map[target] # 0 ~ 100 등급으로 위험도 세분화 가능
		score -= danger_level * survival
		
	return score


# ==========================================================
# 3. 장기 길찾기 (Godot 내장 AStarGrid2D 활용)
# ==========================================================
func _calculate_astar_path(start: Vector2i, target: Vector2i, board) -> Array:
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, 8, 8) # 8x8 체스판 크기 지정
	astar.cell_size = Vector2(1, 1)
	astar.update()
	
	# 맵에 있는 아군/적군 장애물을 A* 그리드에 '막힌 길'로 등록
	for obstacle in board.get_obstacles():
		if obstacle != target: # 플레이어 자체는 목적지이므로 막힌 길로 설정하면 안 됨
			astar.set_point_solid(obstacle, true)
			
	# 장애물을 피해 타겟까지 가는 최단 경로 좌표 배열을 반환
	var path_vectors = astar.get_id_path(start, target)
	return path_vectors
