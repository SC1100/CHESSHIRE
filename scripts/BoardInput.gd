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
		info_label.text = "현재 위치: " + result.collider.name
	else:
		info_label.text = "현재 위치: None"
