extends Node3D
class_name CardManager

@export var main_camera: Camera3D

var hand: Array[CardData] = []
var card_visuals: Array[CardVisual3D] = []

var selected_card: CardVisual3D = null

# 손패 부채꼴 정렬 제어 변수
var hand_radius: float = 4.0 # 호의 반지름
var hand_spacing: float = 0.25 # 카드 사이의 각도(라디안)

func _ready():
	# 사용자가 에디터에서 이동시키지 않아도 자동으로 카메라 앞쪽 하단에 배치되도록 강제 설정
	position = Vector3(0, -0.6, -1.2) # 카메라 기준 아래로 0.6, 앞으로 1.8미터
	scale = Vector3(0.3, 0.3, 0.3) # 1미터짜리 거대한 카드를 예쁜 크기로 축소
	
	# 카드 DB 강제 로드
	if CardData.database.is_empty():
		CardData._static_init()
		
	# 메인 카메라가 지정되지 않았을 경우 씬에서 자동 탐색
	if not main_camera:
		main_camera = get_viewport().get_camera_3d()
		if not main_camera:
			push_error("CardManager: 씬에 Camera3D가 필요합니다!")
			return
			
	# 테스트용 5장 드로우
	var all_cards = CardData.get_all_cards()
	for i in range(min(5, all_cards.size())):
		draw_card(all_cards[i].id)

func draw_card(card_id: String):
	var data = CardData.get_card(card_id)
	if not data: return
	
	hand.append(data)
	var card_3d = CardVisual3D.new(data)
	add_child(card_3d)
	card_visuals.append(card_3d)
	
	# 드로우 연출: 화면 아래쪽에서 생성되도록 초기 위치 설정
	card_3d.global_position = global_position + Vector3(0, -2, 0)
	
	_recalculate_hand_positions()

func _recalculate_hand_positions():
	var count = card_visuals.size()
	if count == 0: return
	
	var total_angle = (count - 1) * hand_spacing
	var start_angle = total_angle / 2.0
	
	for i in range(count):
		var card = card_visuals[i]
		if card == selected_card:
			continue # 마우스로 잡고 있는 카드는 정렬 대형에서 제외
			
		var angle = start_angle - (i * hand_spacing)
		
		# CardManager의 로컬 좌표계 기준으로 부채꼴 수학 연산
		# Y축 아래를 중심으로 카드가 둥글게 배치되도록 합니다.
		var local_pos = Vector3(
			sin(angle) * hand_radius,
			cos(angle) * hand_radius - hand_radius,
			abs(angle) * 0.1 # 양 끝에 있는 카드는 살짝 뒤(Z)로 밀어서 겹침을 방지
		)
		
		# 카드들이 호를 따라 회전하도록 설정 (Z축 회전)
		var local_rot = Vector3(0, 0, -angle)
		
		card.target_position = to_global(local_pos)
		card.target_rotation = global_transform.basis.get_euler() + local_rot

func _input(event: InputEvent):
	if not main_camera: return
	
	if event is InputEventMouseMotion:
		if selected_card:
			# 드래그 처리: 카메라 앞 일정 거리에 가상의 평면(Plane)을 만들고 교차점을 구함
			var mouse_pos = event.position
			var ray_origin = main_camera.project_ray_origin(mouse_pos)
			var ray_dir = main_camera.project_ray_normal(mouse_pos)
			
			var plane_dist = 1.5 # 카메라 앞 1.5m 거리를 드래그 평면으로 설정
			var plane = Plane(main_camera.global_transform.basis.z, main_camera.global_position + (main_camera.global_transform.basis.z * -plane_dist))
			
			var intersect = plane.intersects_ray(ray_origin, ray_dir)
			if intersect:
				# 부드럽게 마우스를 따라오도록 보간(Lerp) 적용
				selected_card.global_position = selected_card.global_position.lerp(intersect, 20.0 * get_process_delta_time())
				# 들고 있을 때는 기울어지지 않고 똑바로 세움 (스케일 파괴 방지)
				selected_card.global_rotation = main_camera.global_rotation
				
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 마우스 클릭: 레이캐스트로 카드 집어들기
			if selected_card == null:
				_raycast_to_pickup_card(event.position)
		else:
			# 마우스 놓기: 사용 또는 취소 판정
			if selected_card != null:
				_try_play_or_return_card(event.position)

func _raycast_to_pickup_card(mouse_pos: Vector2):
	var space_state = get_world_3d().direct_space_state
	var ray_origin = main_camera.project_ray_origin(mouse_pos)
	var ray_dir = main_camera.project_ray_normal(mouse_pos)
	var ray_length = 100.0
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + ray_dir * ray_length
	query.collision_mask = 2 # 카드 감지 전용 레이어 (Area3D)
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	if result:
		var hit_collider = result.collider
		if hit_collider is CardVisual3D:
			selected_card = hit_collider
			selected_card.is_dragging = true
			_recalculate_hand_positions() # 집어든 카드를 제외하고 빈자리 좁히기

func _try_play_or_return_card(mouse_pos: Vector2):
	var screen_height = get_viewport().size.y
	var hand_area_height = screen_height * 0.4 # 화면 하단 40% 영역을 손패 공간으로 간주
	
	if mouse_pos.y > screen_height - hand_area_height:
		# 손패 영역에서 마우스를 놓음 -> 사용 취소, 제자리 복귀
		print("카드 드래그 취소")
		selected_card.is_dragging = false
		selected_card = null
		_recalculate_hand_positions()
	else:
		# 위쪽 필드 영역에서 마우스를 놓음 -> 카드 사용!
		var data = selected_card.data
		print("카드 사용됨! : ", data.card_name)
		
		# 향후 체스판 연동 로직(이펙트, 마나 차감 등)은 여기에 추가됩니다.
		
		hand.erase(data)
		card_visuals.erase(selected_card)
		selected_card.queue_free()
		selected_card = null
		_recalculate_hand_positions()
