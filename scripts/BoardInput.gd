extends Node

@export var camera: Camera3D
@export var info_label: Label

var current_hovered_piece: Node = null
var current_hovered_tile: String = ""
var selected_piece: Node = null
var outline_material: ShaderMaterial

func _ready() -> void:
	# 하이라이트(아웃라인)를 위한 쉐이더 생성
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.0, 1.0); // 노란색 아웃라인
uniform float outline_width = 2.0; // 두께

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader

func _physics_process(_delta: float) -> void:
	if not camera or not info_label:
		return

	# CardManager FSM 상태 확인: 뷰어(VIEWING)나 드로우 중에는 보드판 호버 하이라이트 제거 및 차단
	var card_manager = get_tree().get_first_node_in_group("CardManager")
	if card_manager and "current_state" in card_manager:
		if card_manager.current_state != CardManager.State.IDLE:
			if current_hovered_piece and is_instance_valid(current_hovered_piece):
				if current_hovered_piece != selected_piece:
					_set_piece_outline(current_hovered_piece, false)
				current_hovered_piece = null
			current_hovered_tile = ""
			info_label.text = "현재 위치 : None"
			return

	# 1. 2D 화면 픽셀 좌표 가져오기
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 2. 카메라를 이용해 2D 픽셀을 3D 공간을 관통하는 레이저(Ray)로 변환
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 1000.0 # 카메라에서 1000미터 길이로 쏨
	
	# 3. 물리 엔진에 레이캐스트 질의
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# 중요: BoardGrid에서 만든 것은 'Area3D'이므로 반드시 이 옵션을 켜야 감지됨
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	var new_hovered_piece = null
	
	# 4. 결과 처리하여 Label 업데이트
	if result and result.collider is Area3D:
		var collider = result.collider
		var board_manager = get_node_or_null("../BoardManager")
		
		# 1) 부딪힌 객체가 기물인지 확인 (기물은 BoardManager의 자식 노드임)
		if board_manager:
			var current = collider
			while current and current != get_tree().root:
				if current.get_parent() == board_manager:
					new_hovered_piece = current
					break
				current = current.get_parent()
				
		if new_hovered_piece:
			# 기물 위에 마우스를 올린 경우
			if board_manager:
				current_hovered_tile = board_manager.get_tile_of_piece(new_hovered_piece)
			info_label.text = "현재 위치 : " + new_hovered_piece.name
		else:
			# 2) 보드판 타일 위에 마우스를 올린 경우
			var tile_name = collider.name
			current_hovered_tile = tile_name
			var text = "현재 위치 : " + tile_name
			
			if board_manager:
				var piece_name = board_manager.get_piece_name_on_tile(tile_name)
				if piece_name != "":
					text += " (" + piece_name + ")"
					
			info_label.text = text
	else:
		current_hovered_tile = ""
		info_label.text = "현재 위치 : None"

	# 5. 하이라이트(아웃라인) 상태 업데이트
	if new_hovered_piece != current_hovered_piece:
		# 이전 기물의 하이라이트 해제 (단, 현재 '선택된 기물'이면 아웃라인 유지)
		if current_hovered_piece and is_instance_valid(current_hovered_piece):
			if current_hovered_piece != selected_piece:
				_set_piece_outline(current_hovered_piece, false)
		
		# 새로운 기물의 하이라이트 적용
		if new_hovered_piece and is_instance_valid(new_hovered_piece):
			_set_piece_outline(new_hovered_piece, true)
			
		current_hovered_piece = new_hovered_piece

func _unhandled_input(event: InputEvent) -> void:
	# CardManager FSM 상태 확인: 뷰어(VIEWING) 상태이거나 IDLE이 아닐 때는 보드 클릭 및 이동 차단
	var card_manager = get_tree().get_first_node_in_group("CardManager")
	if card_manager and "current_state" in card_manager:
		if card_manager.current_state != CardManager.State.IDLE:
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var board_manager = get_node_or_null("../BoardManager")
		if not board_manager: return
		
		if selected_piece:
			# 이미 기물이 선택된 상태에서 어딘가를 클릭했을 때 (이동 시도)
			if current_hovered_tile != "":
				var piece_tag = "Pawn"
				if selected_piece.get("data"):
					piece_tag = selected_piece.get("data").piece_name
				elif is_instance_valid(selected_piece):
					var parts = selected_piece.name.split("_")
					if parts.size() >= 2:
						piece_tag = parts[1] # W_Knight_1 -> "Knight" 추출
					
				if board_manager.attempt_move(selected_piece, current_hovered_tile):
					# 이동 성공! 토큰 차감
					board_manager.consume_action_token(piece_tag)
						
					# 랜스 차징 2회 이동 중 잔여 이동이 남아있는 경우 선택 상태 유지 및 2차 이동 하이라이트 자동 갱신
					if board_manager.lance_charge_moves_left > 0 and board_manager.lance_charge_target_knight == selected_piece:
						print("BoardInput: 랜스 차징 2차 이동 대기 - 선택 상태 유지 및 하이라이트 갱신")
						_set_piece_outline(selected_piece, true)
						board_manager.show_valid_moves(selected_piece)
					else:
						# 이동 성공 및 완전 완료 시 선택 해제
						if is_instance_valid(selected_piece) and selected_piece != current_hovered_piece:
							_set_piece_outline(selected_piece, false)
						selected_piece = null
					return
			
			# 이동 실패 시: 다른 기물을 클릭했으면 선택 변경, 아니면 선택 취소
			if not current_hovered_piece or current_hovered_piece == selected_piece:
				# 랜스 차징 중에는 지정된 나이트 해제 금지
				if board_manager.lance_charge_moves_left > 0 and board_manager.lance_charge_target_knight == selected_piece:
					print("BoardInput: 랜스 차징 2차 이동 대기 중에는 선택 해제할 수 없습니다.")
					return
					
				# 허공이나 이동 불가능한 빈 타일을 클릭한 경우
				if is_instance_valid(selected_piece) and selected_piece != current_hovered_piece:
					_set_piece_outline(selected_piece, false)
				selected_piece = null
				board_manager.clear_valid_moves()
				return
				
		var target_click_piece = current_hovered_piece
		if not target_click_piece and current_hovered_tile != "":
			var tile_piece = board_manager.current_board_state.get(current_hovered_tile)
			if is_instance_valid(tile_piece) and board_manager.is_player_piece(tile_piece):
				target_click_piece = tile_piece

		if target_click_piece:
			# 기물을 새로 클릭한 경우 -> 선택!
			if selected_piece != target_click_piece:
				# 아군 기물인지 검사 (플레이어 진영 기물만 조작 가능)
				if not board_manager.is_player_piece(target_click_piece):
					info_label.text = "[거절] 아군 기물만 선택할 수 있습니다!"
					return
					
				# 기물 선택 전 행동권 및 턴 제한 검사
				var piece_tag = "Pawn"
				if target_click_piece.get("data"):
					piece_tag = target_click_piece.get("data").piece_name
				elif is_instance_valid(target_click_piece):
					var parts = target_click_piece.name.split("_")
					if parts.size() >= 2:
						piece_tag = parts[1] # W_Knight_1 -> "Knight" 추출
				
				if not board_manager.has_action_token(piece_tag):
					info_label.text = "[거절] 해당 기물의 행동권(카드)이 부족합니다!"
					return
					
				if target_click_piece.has_method("can_move") and not target_click_piece.can_move():
					info_label.text = "[거절] 이 기물은 이번 턴에 이미 행동했습니다!"
					return
					
				if selected_piece and is_instance_valid(selected_piece) and selected_piece != target_click_piece:
					_set_piece_outline(selected_piece, false)
				selected_piece = target_click_piece
				_set_piece_outline(selected_piece, true)
				board_manager.show_valid_moves(selected_piece)

func _set_piece_outline(piece: Node, enable: bool) -> void:
	# 기물의 자식 중 MeshInstance3D를 찾아서 material_overlay 적용/해제
	for child in piece.get_children():
		if child is MeshInstance3D:
			if enable:
				child.material_overlay = outline_material
			else:
				child.material_overlay = null
			break

func clear_selection() -> void:
	if is_instance_valid(selected_piece):
		_set_piece_outline(selected_piece, false)
	selected_piece = null
	var bm = get_node_or_null("../BoardManager")
	if bm and bm.has_method("clear_valid_moves"):
		bm.clear_valid_moves()
