extends Node3D
class_name CardManager

@export var main_camera: Camera3D

@export_group("Exhaust Animation Settings")
@export var exhaust_card_offset: Vector3 = Vector3(0.0, 2.0, 0.5) ## 사멸 카드 중앙 위치 (X: 좌우, Y: 높이, Z: 앞뒤 깊이)
@export var exhaust_card_scale: Vector3 = Vector3(1.1, 1.1, 1.1) ## 사멸 카드 확대 크기 배율 (X, Y, Z)
@export var exhaust_text_offset: Vector3 = Vector3(0.0, 0.4, 0.1) ## 전멸 안내 텍스트 상대 위치 (X: 좌우, Y: 높이, Z: 앞뒤)
@export var exhaust_text_font_size: int = 48 ## 전멸 안내 텍스트 폰트 크기
@export var exhaust_display_time: float = 0.8 ## 안내 텍스트 정지 노출 시간 (초)
@export var exhaust_fade_time: float = 0.5 ## 페이드아웃 투명화 연출 시간 (초)

var hand: Array[CardData] = []
var card_visuals: Array[CardVisual3D] = []

enum State {IDLE, DRAWING, PLAYING, VIEWING}
var current_state: State = State.IDLE

var deck_component: DeckComponent
var selected_card: CardVisual3D = null
var hovered_card: CardVisual3D = null

# 덱 시각화 관련 변수
var deck_visual: Area3D
var deck_mesh: MeshInstance3D
var deck_label: Label3D

# 버린 카드 더미 시각화 관련 변수
var discard_visual: Area3D
var discard_mesh: MeshInstance3D
var discard_label: Label3D

# 손패 부채꼴 정렬 제어 변수
var hand_radius: float = 12.0 # 호의 반지름
var hand_spacing: float = 0.08 # 카드 사이의 각도(라디안)

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
	add_to_group("CardManager")
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
	
	var master_deck = ProfileManager.get_master_deck()
	if master_deck.is_empty():
		var p_data = PlayerData.load_data()
		master_deck = p_data.deck_card_ids
	deck_component.initialize_from_deck_list(master_deck)
			
	# 게임 시작 시 첫 턴은 화면 페이드인 암전 연출 후 드로우 되도록 대기 후 시작
	_start_initial_turn_with_delay()
	
	# 좌측 상단 테스트용 드로우 버튼 생성
	_setup_test_ui()

func _start_initial_turn_with_delay() -> void:
	await get_tree().create_timer(0.5).timeout
	start_turn()

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
	
	# 코스트 표시 라벨 추가 (좌측 중단 아래, 카드덱 이미지 바로 위)
	cost_label = Label.new()
	cost_label.text = "현재 코스트: " + str(current_cost) + " / " + str(turn_max_cost)
	cost_label.add_theme_font_size_override("font_size", 28)
	cost_label.add_theme_color_override("font_color", Color.WHITE) # 깔끔한 흰색 텍스트
	cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)) # 선명한 아웃라인
	cost_label.add_theme_constant_override("outline_size", 8)
	cost_label.position = Vector2(45, 570) # 좌측 중단 아래 (카드덱 이미지 바로 위)
	canvas.add_child(cost_label)
	
	var draw_btn = Button.new()
	draw_btn.text = "1장 드로우 (테스트)"
	draw_btn.custom_minimum_size = Vector2(200, 52)
	draw_btn.add_theme_font_size_override("font_size", 18)
	_apply_hud_button_style(draw_btn, false)
	draw_btn.pressed.connect(func(): execute_drawing(1))
	vbox.add_child(draw_btn)
	
	var start_btn = Button.new()
	start_btn.text = "내 턴 시작 (테스트)"
	start_btn.custom_minimum_size = Vector2(200, 52)
	start_btn.add_theme_font_size_override("font_size", 18)
	_apply_hud_button_style(start_btn, false)
	start_btn.pressed.connect(func(): start_turn())
	vbox.add_child(start_btn)
	
	var end_btn = Button.new()
	end_btn.text = "턴 종료 [Space]"
	end_btn.custom_minimum_size = Vector2(200, 56)
	end_btn.add_theme_font_size_override("font_size", 20)
	_apply_hud_button_style(end_btn, true) # 턴 종료 버튼 강조
	end_btn.pressed.connect(func(): end_turn())
	vbox.add_child(end_btn)

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
	
	# 턴 시작 시 보드의 행동권과 기물 상태를 초기화
	var bm = get_tree().get_first_node_in_group("BoardManager")
	if bm:
		bm.reset_all_action_tokens()
		if bm.has_method("reset_turn_captured_enemy_count"):
			bm.reset_turn_captured_enemy_count()
	
	print("내 턴 시작! 지정된 카드 장수(", turn_draw_amount, "장)를 드로우합니다.")
	execute_drawing(turn_draw_amount)

func end_turn():
	if current_state != State.IDLE:
		return
	print("내 턴 종료! 남은 손패를 모두 버립니다.")
	
	# 턴 종료 시 남아있는 모든 기물 행동권(토큰) 및 턴 제한 전술 카드 효과 즉시 초기화
	var bm = get_tree().get_first_node_in_group("BoardManager")
	if bm:
		bm.reset_all_action_tokens() # 모든 기물 행동권 토큰 0으로 즉시 소멸
		if bm.has_method("reset_friendly_capture_charges"):
			bm.reset_friendly_capture_charges()
		if bm.has_method("reset_lance_charge"):
			bm.reset_lance_charge()
			
	# 보드판 입력 및 기물 아웃라인 선택 상태 즉시 해제
	var board_input = get_tree().root.find_child("BoardInput", true, false)
	if board_input and board_input.has_method("clear_selection"):
		board_input.clear_selection()
	
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
	
	# 카드가 날아가는 애니메이션을 잠시 기다린 후 상대방 턴 호출
	await get_tree().create_timer(0.5).timeout
	var ai_runner = get_tree().root.find_child("AITestRunner", true, false)
	if ai_runner and ai_runner.has_method("_on_enemy_turn"):
		ai_runner._on_enemy_turn()
	print("--> 적의 턴으로 넘어갑니다... (미구현. 버튼으로 다시 내 턴 시작 가능)")


func _setup_deck_visual():
	deck_visual = Area3D.new()
	deck_visual.name = "DeckVisual"
	deck_visual.position = Vector3(-5.4, -0.3, -0.5) # 손패 좌측 둥둥 띄우기
	
	# 향후 덱 클릭(펼쳐보기)을 위한 충돌체 추가
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.5, 0.1)
	collision.shape = box
	deck_visual.add_child(collision)
	deck_visual.collision_layer = 2 # 카드와 동일 레이어
	
	# 카드 뒷면 메쉬 추가
	deck_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.5)
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
	box.size = Vector3(1.0, 1.5, 0.1)
	collision.shape = box
	discard_visual.add_child(collision)
	discard_visual.collision_layer = 2
	
	discard_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.5)
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
	
	var bm = get_tree().get_first_node_in_group("BoardManager")
	var drawn_cards = []
	var exhaust_items = [] # 손패 착직 후 소멸시킬 카드의 정보 수집 리스트
	
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
				
				# 전멸된 기물 태그 감지 (기물 카드 및 기물 관련 전술 카드 공통 지원)
				var valid_piece_tags = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
				var piece_tag = ""
				for tag in data.tags:
					if tag in valid_piece_tags:
						piece_tag = tag
						break
				
				if bm and piece_tag != "" and "eliminated_player_piece_tags" in bm:
					if bm.eliminated_player_piece_tags.has(piece_tag):
						exhaust_items.append({"visual": card_3d, "data": data, "tag": piece_tag})
				
	if drawn_cards.size() > 0:
		# 1단계: 모든 드로우 카드가 정상적으로 손패 목표 위치로 날아오는 등장 애니메이션
		_recalculate_hand_positions()
		
		for card_3d in drawn_cards:
			_animate_drawn_card(card_3d)
			await get_tree().create_timer(0.15).timeout
			
		# 카드들이 손패 위치에 착지할 때까지 대기
		await get_tree().create_timer(0.5).timeout
		
		# 2단계: 착지 후 전멸된 기물 카드가 있다면 손패 위치에서 위 공중으로 떠올라 소멸(Exhaust)
		if exhaust_items.size() > 0:
			for item in exhaust_items:
				var c_visual: CardVisual3D = item["visual"]
				var c_data: CardData = item["data"]
				var p_tag: String = item["tag"]
				
				print("CardManager: 손패에 들어온 [%s] (%s) 카드가 손패 위 공중으로 들어올려져 소멸(Exhaust)됩니다." % [c_data.card_name, p_tag])
				
				# 논리적 데이터에서 제거
				hand.erase(c_data)
				card_visuals.erase(c_visual)
				
				# 손패 위 공중으로 올라가 소멸하는 연출 코루틴 수행
				await _animate_exhaust_from_hand(c_visual, p_tag)
				
			# 소멸 후 남은 손패 카드들 재배치
			_recalculate_hand_positions()
			await get_tree().create_timer(0.3).timeout
		
	current_state = State.IDLE # 애니메이션이 모두 끝나면 상태를 IDLE로 복귀 (조작 가능)

# 손패에 착지한 사멸 카드가 화면 중앙으로 클로즈업되어 페이드 아웃 소멸(Exhaust)
func _animate_exhaust_from_hand(card_3d: CardVisual3D, piece_tag: String = ""):
	if not is_instance_valid(card_3d): return
	
	card_3d.is_dragging = false
	card_3d.is_drawing = true # lerp 위치 추종 일시 중단
	card_3d.set_process(false)
	card_3d.collision_layer = 0
	card_3d.collision_mask = 0
	
	# 1단계: 현재 손패 위치에서 CardManager 씬 카메라 정중앙 위치로 날아오며 클로즈업 확대 (0.35초)
	var center_pos = to_global(exhaust_card_offset)
	var tween1 = create_tween()
	tween1.set_parallel(true)
	tween1.tween_property(card_3d, "global_position", center_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween1.tween_property(card_3d, "scale", exhaust_card_scale, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween1.tween_property(card_3d, "global_rotation", global_rotation, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween1.finished
	
	# 2단계: 3D 안내 텍스트 생성 (기물 태그가 있을 때만)
	var label: Label3D = null
	if piece_tag != "":
		label = Label3D.new()
		label.text = "[ %s ] 기물 전멸!" % piece_tag.to_upper()
		label.font_size = exhaust_text_font_size
		label.outline_size = 12
		label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0) # 뚜렷한 검은색 외곽선
		label.modulate = Color(1.0, 1.0, 1.0, 1.0) # 하얀색 글씨
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true # 카드 전면에 시각적으로 뚜렷하게 보이도록 설정
		add_child(label)
		label.global_position = center_pos + exhaust_text_offset # 카드 대비 텍스트 상대 위치
	
	# 지정된 노출 시간 동안 대기
	var wait_time = exhaust_display_time if piece_tag != "" else 0.15
	await get_tree().create_timer(wait_time).timeout
	
	# 3단계: 카드와 텍스트가 동시에 투명해지며 페이드 아웃
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_method(func(a: float): card_3d.set_card_alpha(a), 1.0, 0.0, exhaust_fade_time)
	if is_instance_valid(label):
		tween2.tween_property(label, "modulate:a", 0.0, exhaust_fade_time)
	
	await tween2.finished
	if is_instance_valid(label):
		label.queue_free()
	if is_instance_valid(card_3d):
		card_3d.queue_free()

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

# 프로모션 등 특수 상황 시 카드를 손패로 직접 추가하고 드로우 연출 실행
func add_card_directly_to_hand(card_id: String) -> void:
	var data = CardData.get_card(card_id)
	if not data: return
	
	hand.append(data)
	var card_3d = CardVisual3D.new(data)
	add_child(card_3d)
	card_visuals.append(card_3d)
	
	if is_instance_valid(deck_visual):
		card_3d.global_position = deck_visual.global_position + (global_transform.basis.z * 0.1)
	else:
		card_3d.global_position = global_position
		
	_recalculate_hand_positions()
	_animate_drawn_card(card_3d)
	print("CardManager: 승급 카드 [%s]가 손패로 직접 추가되었습니다!" % data.card_name)

func _recalculate_hand_positions():
	var count = card_visuals.size()
	if count == 0: return
	
	# 동적 카드 간격 세팅 (기본 0.88m 간격으로 넓히고, 손패가 아주 많아지면 최대 폭 7.0m 이내로 자동 슬림 압축)
	var max_hand_width: float = 7.0
	var base_spacing: float = 0.88
	var card_spacing_x: float = minf(base_spacing, max_hand_width / maxf(1.0, float(count - 1)))
	var total_width: float = (count - 1) * card_spacing_x
	var start_x: float = total_width / 2.0 # i=0 첫 카드가 오른쪽 끝(+X)에 배치됨
	
	for i in range(count):
		var card = card_visuals[i]
		if card == selected_card:
			card.set_sorting_offset(200.0) # 잡고 있는 카드는 최우선순위 렌더링
			continue # 마우스로 잡고 있는 카드는 정렬 대형에서 제외
			
		# 첫 번째 카드(i=0)가 오른쪽 끝(+X), 다음 카드(i=1, 2...)가 왼쪽(-X)으로 배치됨
		var card_x: float = start_x - (i * card_spacing_x)
		var z_order_offset: float = float(count - 1 - i) # i=0(가장 오른쪽)이 가장 위(최상단 레이어)에 위치함
		var local_pos = Vector3(
			card_x,
			0.0,
			0.0 # 3D 깊이 차이로 인한 화면 투영 경사도를 없애 100% 완전한 수평 baseline 정렬
		)
		
		# 직선 정렬을 위해 카드 기울기 제거 (수직 똑바로 세움)
		var local_rot = Vector3.ZERO
		
		# 마우스 호버(Hover) 시 플레이어 눈앞(+0.25m Z)으로 쑥 다가오고 렌더링 레이어 최상단(100.0) 지정
		if card == hovered_card:
			local_pos.y += 0.10 # 약간의 가독성 상승 보정
			local_pos.z += 0.25 # 플레이어 가슴/눈 앞으로 쑥 다가옴
			card.target_scale = Vector3(1.15, 1.15, 1.15) # 1.15배 선명 확대
			card.set_sorting_offset(100.0) # 호버 카드는 무조건 3D 최상단 렌더링
		else:
			card.target_scale = Vector3.ONE
			card.set_sorting_offset(z_order_offset) # 맨 오른쪽(i=0)이 가장 위, 왼쪽으로 갈수록 차곡차곡 밑에 배치 (sorting_offset으로 겹침 제어)
			
		card.target_position = to_global(local_pos)
		card.target_rotation = global_transform.basis.get_euler() + local_rot

func _unhandled_input(event: InputEvent):
	# 단축키 처리: 스페이스바를 누르면 턴 종료
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			end_turn()
			return
			
	# FSM: 드로우/애니메이션 중에는 플레이어의 마우스/키보드 입력을 완전 차단
	if current_state != State.IDLE:
		if hovered_card:
			hovered_card.is_hovered = false
			hovered_card = null
			_recalculate_hand_positions()
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
		else:
			# 마우스 커서 위치에 있는 손패 3D 카드 실시간 호버 검사
			_update_hovered_card(event.position)
				
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 마우스 클릭: 레이캐스트로 카드 집어들기
			if selected_card == null:
				_raycast_to_pickup_card(event.position)
		else:
			# 마우스 놓기: 사용 또는 취소 판정
			if selected_card != null:
				_try_play_or_return_card(event.position)

# 마우스 커서에 있는 손패 카드를 3D 레이캐스트로 탐지하여 호버 효과 적용
func _update_hovered_card(mouse_pos: Vector2):
	var space_state = get_world_3d().direct_space_state
	var ray_origin = main_camera.project_ray_origin(mouse_pos)
	var ray_dir = main_camera.project_ray_normal(mouse_pos)
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + ray_dir * 100.0
	query.collision_mask = 2 # 카드 전용 레이어
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	var new_hovered: CardVisual3D = null
	if result and result.collider is CardVisual3D and card_visuals.has(result.collider):
		new_hovered = result.collider
		
	if new_hovered != hovered_card:
		if hovered_card and is_instance_valid(hovered_card):
			hovered_card.is_hovered = false
		hovered_card = new_hovered
		if hovered_card:
			hovered_card.is_hovered = true
		_recalculate_hand_positions()

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
			if hovered_card and is_instance_valid(hovered_card):
				hovered_card.is_hovered = false
				hovered_card = null
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
		
		# 전술/스킬/파워 카드 특수 효과 처리
		var bm = get_tree().get_first_node_in_group("BoardManager")
		if data.id == "t_crusade":
			if bm and bm.has_method("add_custom_rule"):
				bm.add_custom_rule("bishop_straight_move")
		elif data.id == "t_disband":
			if bm and bm.has_method("add_friendly_capture_charge"):
				bm.add_friendly_capture_charge(1)
		elif data.id == "t_lance_charge":
			if bm and bm.has_method("activate_lance_charge_pending"):
				bm.activate_lance_charge_pending()
		elif data.id == "t_last_stand":
			if bm and bm.has_method("activate_last_stand"):
				bm.activate_last_stand()
		elif data.id == "t_quick_decision":
			if bm and bm.has_method("apply_quick_decision"):
				bm.apply_quick_decision()
		elif data.id == "t_sabotage":
			if bm and bm.has_method("activate_sabotage"):
				bm.activate_sabotage()
		elif data.id == "t_spoils":
			apply_spoils()
		elif data.id == "t_two_cats":
			execute_drawing(2)

		# 기물 행동권(토큰) 부여 처리
		if CardData.CardType.PIECE == data.type or "Piece" in data.tags:
			var piece_tag = ""
			for t in data.tags:
				if t != "Piece" and t != "Objective":
					piece_tag = t
					break
			if piece_tag != "":
				if bm:
					if piece_tag == "Knight" and bm.has_method("trigger_lance_charge_on_knight_played") and bm.lance_charge_pending:
						bm.trigger_lance_charge_on_knight_played()
					else:
						bm.add_action_token(piece_tag)
				else:
					print("[CardManager] BoardManager를 찾을 수 없어 행동권을 부여하지 못했습니다.")
		
		# 사용된 카드를 DeckComponent의 버린 카드 더미(또는 소멸 더미)로 보냅니다.
		# "Exhaust" 태그가 있거나 파워 카드(Power)인 경우 화면 중앙 소멸(Exhaust) 시퀀스를 적용합니다.
		var is_exhaust = ("Exhaust" in data.tags) or ("Power" in data.tags) or (data.type == CardData.CardType.POWER)
		if is_exhaust:
			deck_component.exhaust_card(data.id)
			print(" -> 카드 소멸됨 (Power/Exhaust 화면 중앙 소멸 시퀀스 재생)")
			_animate_exhaust_from_hand(selected_card, "")
		else:
			deck_component.discard_card(data.id)
			print(" -> 버린 카드 더미로 이동")
			_animate_discard_card(selected_card)
		
		hand.erase(data)
		card_visuals.erase(selected_card)
		
		selected_card = null
		_recalculate_hand_positions()

# --- 전리품 (Spoils) 카드 효과 ---
func apply_spoils() -> void:
	var bm = get_tree().get_first_node_in_group("BoardManager")
	if bm and "captured_enemy_count_this_turn" in bm and bm.captured_enemy_count_this_turn >= 1:
		print("CardManager: [전리품] 이번 턴 적 기물 %d개 포획 성공! 코스트 +2 획득 및 카드 1장 드로우!" % bm.captured_enemy_count_this_turn)
		current_cost += 2
		_update_cost_ui()
		execute_drawing(1)
	else:
		print("CardManager: [전리품] 이번 턴 포획한 적 기물이 없습니다 (%d개). 카드가 소모되었지만 효과가 발동하지 않았습니다." % (bm.captured_enemy_count_this_turn if bm else 0))

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
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewer_canvas.add_child(bg)
	
	# 상단 제목 라벨
	var title_label = Label.new()
	title_label.text = title + " (" + str(pile_cards.size()) + "장)"
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.position.y = 30
	viewer_canvas.add_child(title_label)
	
	# 스크롤 가능한 영역 생성
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 90
	scroll.offset_bottom = -100
	viewer_canvas.add_child(scroll)
	
	# 중앙 정렬 컨테이너 (카드가 화면 중앙에 예쁘게 모이도록 보정)
	var center_box = CenterContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_box)
	
	# 가로 5칸짜리 그리드 (바둑판) 생성
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center_box.add_child(grid)
	
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
			# 호버 애니메이션 피벗을 가진 컨테이너 래퍼
			var card_wrapper = Control.new()
			card_wrapper.custom_minimum_size = Vector2(180, 270) # 정확한 2:3 비율 (손패 및 800x1200 표준 동기화)
			
			var tex_rect = TextureRect.new()
			tex_rect.texture = data.get_texture()
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.pivot_offset = Vector2(90, 135) # 카드 중앙 피벗
			card_wrapper.add_child(tex_rect)
			
			# 마우스 호버 효과 (마우스 올릴 시 1.18배 선명 확대)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			tex_rect.mouse_entered.connect(func():
				var tween = tex_rect.create_tween()
				tween.tween_property(tex_rect, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			tex_rect.mouse_exited.connect(func():
				var tween = tex_rect.create_tween()
				tween.tween_property(tex_rect, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			
			grid.add_child(card_wrapper)
			
	# 배경(ColorRect) 클릭 시 닫기
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			viewer_canvas.queue_free()
			current_state = State.IDLE
	)
	
	# 닫기 버튼 명시적 제공
	var close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	close_btn.offset_left = 360
	close_btn.offset_right = -360
	close_btn.offset_top = -75
	close_btn.offset_bottom = -20
	_apply_hud_button_style(close_btn, false)
	close_btn.pressed.connect(func():
		viewer_canvas.queue_free()
		current_state = State.IDLE
	)
	viewer_canvas.add_child(close_btn)

func _apply_hud_button_style(btn: Button, is_highlight: bool = false) -> void:
	if not btn: return
	
	# Normal State
	var style_normal = StyleBoxFlat.new()
	if is_highlight:
		style_normal.bg_color = Color(0.18, 0.13, 0.08, 0.92) # 턴 종료 버튼 전용 골드 틴트
		style_normal.border_color = Color(1.0, 0.88, 0.45, 0.95) # 선명한 골드 테두리
	else:
		style_normal.bg_color = Color(0.10, 0.12, 0.18, 0.88)
		style_normal.border_color = Color(0.92, 0.92, 0.96, 0.9)
		
	style_normal.set_corner_radius_all(10)
	style_normal.set_border_width_all(2)
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_normal.shadow_size = 6
	btn.add_theme_stylebox_override("normal", style_normal)
	
	# Hover State
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.24, 0.27, 0.38, 0.95)
	style_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style_hover.shadow_size = 10
	btn.add_theme_stylebox_override("hover", style_hover)
	
	# Pressed State
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	style_pressed.border_color = Color(0.75, 0.75, 0.8, 0.8)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	# Font Outlines & Colors
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 5)
