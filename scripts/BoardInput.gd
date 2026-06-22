extends Node

@export var camera: Camera3D
@export var info_label: Label

func _physics_process(_delta: float) -> void:
	if not camera or not info_label:
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
	
	# 4. 결과 처리하여 Label 업데이트
	if result and result.collider is Area3D:
		var collider = result.collider
		var board_manager = get_node_or_null("../BoardManager")
		
		# 1) 부딪힌 객체가 기물인지 확인 (기물은 BoardManager의 자식 노드임)
		var hovered_piece = null
		if board_manager:
			var current = collider
			while current and current != get_tree().root:
				if current.get_parent() == board_manager:
					hovered_piece = current
					break
				current = current.get_parent()
				
		if hovered_piece:
			# 기물 위에 마우스를 올린 경우
			info_label.text = "현재 위치 : " + hovered_piece.name
		else:
			# 2) 보드판 타일 위에 마우스를 올린 경우
			var tile_name = collider.name
			var text = "현재 위치 : " + tile_name
			
			if board_manager:
				var piece_name = board_manager.get_piece_name_on_tile(tile_name)
				if piece_name != "":
					text += " (" + piece_name + ")"
					
			info_label.text = text
	else:
		info_label.text = "현재 위치 : None"
