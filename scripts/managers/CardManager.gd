extends Node3D
class_name CardManager

@export var main_camera: Camera3D

var hand: Array[CardData] = []
var card_visuals: Array[CardVisual3D] = []

enum State { IDLE, DRAWING, PLAYING, VIEWING }
var current_state: State = State.IDLE

var deck_component: DeckComponent
var selected_card: CardVisual3D = null

# 덱 시각화 관련 변수
var deck_visual: Area3D
var deck_mesh: MeshInstance3D
var deck_label: Label3D

# 버린 카드 더미 시각화 관련 변수
var discard_visual: Area3D
var discard_mesh: MeshInstance3D
var discard_label: Label3D

# 손패 부채꼴 정렬 제어 변수
var hand_radius: float = 4.0 # 호의 반지름
var hand_spacing: float = 0.25 # 카드 사이의 각도(라디안)

# 턴 및 드로우 시스템 변수
var base_draw_amount: int = 4 # 기본 드로우 장수
var turn_draw_amount: int = 4 # 이번 턴에 실제로 뽑을 장수 (디버프/버프 등 고려)

# 가용 코스트 시스템 변수
var base_max_cost: int = 4 # 기본 코스트 최대치
var turn_max_cost: int = 4 # 이번 턴 가용 코스트 최대치 (유물, 버프 등 반영)
var current_cost: int = 4 # 현재 남은 코스트

# UI 참조 변수
var cost_label: Label

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
			
	# 덱 컴포넌트 생성 및 초기화
	deck_component = DeckComponent.new()
	add_child(deck_component)
	
	_setup_deck_visual()
	_setup_discard_visual()
	deck_component.counts_changed.connect(_on_counts_changed)
	
	var p_data = PlayerData.load_data()
	deck_component.initialize(p_data)
			
	# 게임 시작 시 첫 턴 강제 시작
	start_turn()
	
	# 좌측 상단 테스트용 드로우 버튼 생성
	_setup_test_ui()

func _setup_test_ui():
	# 3D 환경에서도 화면(카메라) 렌즈 앞에 UI를 딱 붙이기 위해 CanvasLayer를 사용합니다.
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	# 세로로 버튼들을 정렬하기 위해 VBoxContainer 사용
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer" # 노드 검색용 이름 부여
	vbox.position = Vector2(20, 20) # 좌측 상단 여백
	vbox.add_theme_constant_override("separation", 10)
	canvas.add_child(vbox)
	
	# 코스트 표시 라벨 추가
	cost_label = Label.new()
	cost_label.text = "현재 코스트: " + str(current_cost) + " / " + str(turn_max_cost)
	cost_label.add_theme_font_size_override("font_size", 28)
	cost_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0)) # 코스트 느낌의 파란색
	vbox.add_child(cost_label)
	
	var draw_btn = Button.new()
	draw_btn.text = "1장 드로우 (테스트)"
	draw_btn.custom_minimum_size = Vector2(200, 60)
	draw_btn.add_theme_font_size_override("font_size", 20)
	draw_btn.pressed.connect(func(): execute_drawing(1))
	vbox.add_child(draw_btn)
	
	var end_btn = Button.new()
	end_btn.text = "턴 종료 (테스트)"
	end_btn.custom_minimum_size = Vector2(200, 60)
	end_btn.add_theme_font_size_override("font_size", 20)
	end_btn.pressed.connect(func(): end_turn())
	vbox.add_child(end_btn)
	
	var start_btn = Button.new()
	start_btn.text = "내 턴 시작 (테스트)"
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(func(): start_turn())
	vbox.add_child(start_btn)

# --- 코스트 UI 업데이트 ---
func _update_cost_ui():
	if cost_label != null:
		cost_label.text = "현재 코스트: " + str(current_cost) + " / " + str(turn_max_cost)

# --- 턴 시스템 로직 ---
func start_turn():
	if current_state != State.IDLE:
		return
		
	# 턴 시작 시 코스트 꽉 채우기
	current_cost = turn_max_cost
	_update_cost_ui()
	
	print("내 턴 시작! 지정된 카드 장수(", turn_draw_amount, "장)를 드로우합니다.")
	execute_drawing(turn_draw_amount)

func end_turn():
	if current_state != State.IDLE:
		return
	print("내 턴 종료! 남은 손패를 모두 버립니다.")
	
	# 루프 중 원본 배열을 삭제하는 오류를 막기 위해 손패를 복제해서 사용
	var cards_to_discard = hand.duplicate()
	for data in cards_to_discard:
		var card_3d = null
		# 일치하는 3D 메쉬 찾기
		for c in card_visuals:
			if c.data == data:
				card_3d = c
				break
				
		if card_3d:
			deck_component.discard_card(data.id)
			hand.erase(data)
			card_visuals.erase(card_3d)
			_animate_discard_card(card_3d) # 화려하게 버리기 연출
			
	# 모든 카드를 버렸으므로 드래그 중인 카드(있었다면)도 해제
	selected_card = null
	_recalculate_hand_positions()
	
	print("--> 적의 턴으로 넘어갑니다... (미구현. 버튼으로 다시 내 턴 시작 가능)")


func _setup_deck_visual():
	deck_visual = Area3D.new()
	deck_visual.name = "DeckVisual"
	deck_visual.position = Vector3(-5.4, -0.3, -0.5) # 손패 좌측 둥둥 띄우기
	
	# 향후 덱 클릭(펼쳐보기)을 위한 충돌체 추가
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.36, 0.1)
	collision.shape = box
	deck_visual.add_child(collision)
	deck_visual.collision_layer = 2 # 카드와 동일 레이어
	
	# 카드 뒷면 메쉬 추가
	deck_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.36)
	deck_mesh.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load("res://Asset/test/card_back_test.png")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	deck_mesh.material_override = mat
	deck_visual.add_child(deck_mesh)
	
	# 남은 카드 수 라벨 추가
	deck_label = Label3D.new()
	deck_label.text = "0"
	deck_label.pixel_size = 0.01
	deck_label.font_size = 32
	deck_label.outline_size = 12
	deck_label.position = Vector3(0, -0.9, 0.05) # 덱 바로 아래
	deck_visual.add_child(deck_label)
	
	add_child(deck_visual)

func _setup_discard_visual():
	discard_visual = Area3D.new()
	discard_visual.name = "DiscardVisual"
	discard_visual.position = Vector3(5.4, -0.3, -0.5) # 덱과 Y, Z는 동일하게 유지, X축을 양수(우측)로 대칭
	
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.36, 0.1)
	collision.shape = box
	discard_visual.add_child(collision)
	discard_visual.collision_layer = 2 
	
	discard_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.36)
	discard_mesh.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load("res://Asset/test/card_back_test.png")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	discard_mesh.material_override = mat
	discard_visual.add_child(discard_mesh)
	
	discard_label = Label3D.new()
	discard_label.text = "0"
	discard_label.pixel_size = 0.01
	discard_label.font_size = 32
	discard_label.outline_size = 12
	discard_label.position = Vector3(0, -0.9, 0.05) 
	discard_visual.add_child(discard_label)
	
	# 초기에는 버린 카드가 0장이므로 숨김 처리
	discard_mesh.visible = false
	
	add_child(discard_visual)

func _on_counts_changed(draw_count: int, discard_count: int):
	deck_label.text = str(draw_count)
	discard_label.text = str(discard_count)
	
	if draw_count <= 0:
		deck_mesh.visible = false
	else:
		deck_mesh.visible = true
		
	if discard_count <= 0:
		discard_mesh.visible = false
	else:
		discard_mesh.visible = true

# 지정된 장수만큼 덱에서 뽑아오는 과정을 총괄하는 FSM 코루틴 함수 (drawing 키워드 모듈화)
func execute_drawing(amount: int):
	# 이미 다른 연출 중이면 무시 (버그 원천 차단)
	if current_state != State.IDLE:
		return
		
	current_state = State.DRAWING # 상태를 DRAWING으로 변경 (모든 입력 차단)
	
	var drawn_cards = []
	for i in range(amount):
		var drawn_id = deck_component.draw_card()
		if drawn_id != "":
			var data = CardData.get_card(drawn_id)
			if data:
				hand.append(data)
				var card_3d = CardVisual3D.new(data)
				add_child(card_3d)
				card_visuals.append(card_3d)
				
				# 초기 상태 세팅 (덱 뭉치에 스폰, 보이지 않음)
				card_3d.global_position = deck_visual.global_position + (global_transform.basis.z * 0.1)
				card_3d.visible = false
				card_3d.set_process(false)
				drawn_cards.append(card_3d)
				
	if drawn_cards.size() > 0:
		# 카드가 논리적으로 손패에 다 들어왔으므로 최종 목적지 한 번에 계산
		_recalculate_hand_positions()
		
		# 0.15초 간격으로 시각적 등장 애니메이션 시작
		for card_3d in drawn_cards:
			_animate_drawn_card(card_3d)
			await get_tree().create_timer(0.15).timeout
			
		# 마지막 카드의 트윈 연출(0.6초)이 완전히 끝날 때까지 여유롭게 대기
		await get_tree().create_timer(0.5).timeout
		
	current_state = State.IDLE # 애니메이션이 모두 끝나면 상태를 IDLE로 복귀 (조작 가능)

# 드로우 시각 효과 처리 (위치 이동은 lerp가 전담, 여기서는 회전/크기만)
func _animate_drawn_card(card_3d: CardVisual3D):
	card_3d.visible = true
	card_3d.set_process(true) # 기존 lerp 로직 가동! (자신의 최종 자리로 일직선 비행)
	
	# 시작 회전: 뒷면이 보이게 Y축으로 뒤집어둠 (덱에서 바로 나온 느낌)
	card_3d.global_rotation = global_rotation + Vector3(0, PI, 0)
	
	# 시작 크기: 작게 시작해서 커지도록 연출
	card_3d.scale = Vector3(0.2, 0.2, 0.2)
	
	# Tween 애니메이션 (회전과 크기만 담당)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card_3d, "global_rotation", card_3d.target_rotation, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_3d, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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

func _unhandled_input(event: InputEvent):
	# FSM: 드로우 등 애니메이션 중에는 플레이어의 입력을 완전히 차단
	if current_state != State.IDLE:
		return
		
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
		elif hit_collider.name == "DeckVisual":
			execute_card_view(deck_component.draw_pile, "남은 카드 덱", true)
		elif hit_collider.name == "DiscardVisual":
			execute_card_view(deck_component.discard_pile, "버린 카드 더미", false)

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
		# 위쪽 필드 영역에서 마우스를 놓음 -> 카드 사용 시도!
		var data = selected_card.data
		var cost_to_pay = data.cost
		
		# 특수: X 코스트 카드 처리 (현재 코스트를 전부 지불 코스트로 산정)
		if "X_Cost" in data.tags:
			cost_to_pay = current_cost
			
		# 코스트 부족 검사
		if current_cost < cost_to_pay:
			print("코스트가 부족합니다! (필요: ", cost_to_pay, " / 현재: ", current_cost, ")")
			selected_card.is_dragging = false
			selected_card = null
			_recalculate_hand_positions() # 제자리로 스르륵 돌아감
			return
			
		# 코스트 차감 및 UI 갱신
		current_cost -= cost_to_pay
		_update_cost_ui()
		
		print("카드 사용됨! : ", data.card_name, " (소모 코스트: ", cost_to_pay, ")")
		
		# 사용된 카드를 DeckComponent의 버린 카드 더미로 보냅니다.
		# 만약 "Exhaust" 태그가 있다면 exhaust_card로 보낼 수 있습니다.
		if "Exhaust" in data.tags:
			deck_component.exhaust_card(data.id)
			print(" -> 카드 소멸됨 (Exhaust)")
		else:
			deck_component.discard_card(data.id)
			print(" -> 버린 카드 더미로 이동")
		
		hand.erase(data)
		card_visuals.erase(selected_card)
		
		# 즉시 삭제하지 않고 우측 하단으로 빨려 들어가는 애니메이션 재생
		_animate_discard_card(selected_card)
		
		selected_card = null
		_recalculate_hand_positions()

# 카드를 사용하거나 버릴 때 버린 카드 더미(우측 하단)로 빨려 들어가는 시각 효과
func _animate_discard_card(card_3d: CardVisual3D):
	# 더 이상 마우스 조작이나 _process 보간을 받지 않도록 프로세스 강제 종료
	card_3d.is_dragging = false
	card_3d.set_process(false)
	
	# 충돌체 비활성화 (공중에서 날아가는 도중 클릭 방지)
	card_3d.collision_layer = 0
	card_3d.collision_mask = 0
	
	var tween = create_tween().set_parallel(true)
	
	# 1. 목표 위치: 우측 하단 버린 카드 뭉치 (점점 가속하며 빨려 들어감 - EASE_IN)
	tween.tween_property(card_3d, "global_position", discard_visual.global_position, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# 2. 목표 회전: 덱처럼 뒷면이 보이도록 뒤집어짐
	var target_rot = discard_visual.global_rotation + Vector3(0, PI, 0)
	tween.tween_property(card_3d, "global_rotation", target_rot, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# 3. 목표 크기: 뭉치에 들어가며 0.2배로 작아짐
	tween.tween_property(card_3d, "scale", Vector3(0.2, 0.2, 0.2), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# 연출이 완전히 끝나면 메모리에서 안전하게 삭제
	tween.chain().tween_callback(func(): card_3d.queue_free())

# 카드 확인 시스템 (덱/버린 덱 클릭 시) - FSM 뷰어 상태 진입 키워드
func execute_card_view(pile_cards: Array[String], title: String, sort_by_cost: bool = true):
	if current_state != State.IDLE:
		return
		
	current_state = State.VIEWING # 상태 전환 (뒷배경 조작 완전 차단)
	
	var viewer_canvas = CanvasLayer.new()
	viewer_canvas.layer = 10 # 3D 씬이나 다른 UI보다 무조건 위에 띄움
	add_child(viewer_canvas)
	
	# 어두운 배경 필터 (블랙 반투명)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewer_canvas.add_child(bg)
	
	# 상단 제목 라벨
	var title_label = Label.new()
	title_label.text = title + " (" + str(pile_cards.size()) + "장)"
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.position.y = 30
	viewer_canvas.add_child(title_label)
	
	# 스크롤 가능한 영역 생성
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 100
	scroll.offset_right = -100
	scroll.offset_top = 100
	scroll.offset_bottom = -120
	viewer_canvas.add_child(scroll)
	
	# 가로 5칸짜리 그리드 (바둑판) 생성
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	# 스크롤 영역 내부 정렬
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	# 원본 덱 배열(순서)을 건드리지 않기 위해 복제본 생성
	var sorted_cards = pile_cards.duplicate()
	
	if sort_by_cost:
		# 남은 덱: 코스트 오름차순, 코스트가 같으면 ID 알파벳순으로 정렬 (스포일러 방지)
		sorted_cards.sort_custom(func(a: String, b: String):
			var data_a = CardData.get_card(a)
			var data_b = CardData.get_card(b)
			if data_a.cost != data_b.cost:
				return data_a.cost < data_b.cost
			return data_a.id < data_b.id
		)
	else:
		# 버린 덱: 최근에 버린 카드가 배열의 맨 끝(append)에 있으므로, 배열을 뒤집어(reverse) 가장 최근 것이 맨 앞(좌측 상단)에 오도록 함
		sorted_cards.reverse()
	
	# 정렬된 배열을 순회하며 TextureRect로 2D UI 생성
	for card_id in sorted_cards:
		var data = CardData.get_card(card_id)
		if data:
			var tex_rect = TextureRect.new()
			tex_rect.texture = data.get_texture()
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.custom_minimum_size = Vector2(180, 245)
			grid.add_child(tex_rect)
			
	# 배경(ColorRect) 클릭 시 닫기
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			viewer_canvas.queue_free()
			current_state = State.IDLE
	)
	
	# 닫기 버튼 명시적 제공
	var close_btn = Button.new()
	close_btn.text = "닫기 (또는 어두운 배경 클릭)"
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	close_btn.offset_left = 300
	close_btn.offset_right = -300
	close_btn.offset_top = -80
	close_btn.offset_bottom = -20
	close_btn.pressed.connect(func():
		viewer_canvas.queue_free()
		current_state = State.IDLE
	)
	viewer_canvas.add_child(close_btn)
