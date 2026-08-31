extends Node
class_name BattleManager

# --- 서브뷰포트 방식을 코드로 동적 구축하는 배틀 매니저 ---

var chess_scene_path = "res://Scene/Chess_scene.tscn"
var card_scene_path = "res://Scene/card test.tscn"

var token_label: Label
var sub_viewport: SubViewport

func _ready():
	print("[BattleManager] 전투 씬 통합을 시작합니다...")
	
	# 1. 체스 보드 씬 로드 및 백그라운드 배치
	var chess_scene = load(chess_scene_path).instantiate()
	add_child(chess_scene)
	
	# [AI 시스템 연결] 이전에 만들어둔 AITestRunner를 체스 씬에 추가합니다.
	var ai_node = Node.new()
	ai_node.name = "AITestRunner"
	ai_node.set_script(preload("res://scripts/ai/AITestRunner.gd"))
	chess_scene.add_child(ai_node)
	print("[BattleManager] AITestRunner (AI 봇) 장착 완료!")
	
	# [테스트 픽스] 체스 씬 카메라의 하늘도 강제로 없애고 단색 배경을 적용합니다.
	var chess_camera = chess_scene.get_node_or_null("Camera3D")
	if not chess_camera:
		chess_camera = chess_scene.find_child("Camera3D", true, false)
	if chess_camera:
		var chess_env = Environment.new()
		chess_env.background_mode = Environment.BG_COLOR
		chess_env.background_color = Color(0.7, 0.7, 0.7) # 밝은 회색
		chess_camera.environment = chess_env
	
	# 2. UI 레이어 및 서브뷰포트 생성 (카드를 투명하게 띄우기 위함)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10 # 가장 앞에 보이도록 설정
	add_child(canvas_layer)
	
	var sv_container = SubViewportContainer.new()
	sv_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv_container.stretch = true # [핵심] 창 크기 변경 시 캔버스 스케일에 맞춰 자동 비례 확대/축소
	# MOUSE_FILTER_PASS로 설정하여 빈 공간 클릭 시 뒤의 체스판(unhandled_input)으로 클릭이 넘어가게 함
	sv_container.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(sv_container)
	
	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true # 뒷 배경 투명화 (핵심)
	sub_viewport.own_world_3d = true # [핵심] 체스 씬의 하늘(WorldEnvironment)과 렌더링 분리
	sub_viewport.size = Vector2i(1600, 900) # [핵심] 1600x900 기준 해상도 고정으로 3D 카드 시야각/위치 100% 동기화
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.physics_object_picking = true # 3D 카드 레이캐스트 감지를 위해 필수
	sv_container.add_child(sub_viewport)
	
	# 3. 카드 테스트 씬 로드 및 서브뷰포트에 넣기
	var card_scene = load(card_scene_path).instantiate()
	sub_viewport.add_child(card_scene)
	
	# [버그 수정] 고도 엔진 4의 기본 하늘(Default Sky) 렌더링 강제 종료
	# 카드 씬의 루트 노드가 Camera3D인 경우와 자식인 경우 모두 대응
	var card_camera = card_scene if card_scene is Camera3D else card_scene.get_node_or_null("Camera3D")
	if not card_camera and not card_scene is Camera3D:
		card_camera = card_scene.find_child("Camera3D", true, false)
		
	if card_camera:
		var env = Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR # 배경을 완전히 비워 투명하게 만듦
		card_camera.environment = env
	
	# 4. 행동권 현황 UI 생성 (기존 로그창을 덮지 않도록 우측 상단 배치)
	_setup_token_ui(canvas_layer)
	
	# 5. 화면 진입 페이드인 암전 연출 (1~2프레임 3D 씬/카메라 로딩 잔상 가림)
	_setup_fade_in_transition()

func _setup_fade_in_transition() -> void:
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100 # 최상단에 배치
	add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0) # 완전 암전
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	
	# 2프레임 동안 암전 상태 유지하여 3D 씬/카메라 초기화 완성
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 0.35초 동안 스무스하게 페이드인 (스테이지 페이드아웃 시간과 일치)
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	fade_layer.queue_free()

func _setup_token_ui(canvas: CanvasLayer):
	token_label = Label.new()
	token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	token_label.position = Vector2(1240, 100) # 현재 위치 라벨(Y=40) 아래로 배치
	token_label.custom_minimum_size = Vector2(320, 0)
	token_label.add_theme_font_size_override("font_size", 24)
	token_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) # 뚜렷한 흰색
	token_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	token_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(token_label)

func _process(_delta: float):
	# 매 프레임마다 토큰(행동권) 현황을 가져와서 UI 갱신
	var bm = get_tree().get_first_node_in_group("BoardManager")
	if bm and token_label:
		var text = " 행동가능 기물 \n"
		for piece in bm.active_tokens.keys():
			if bm.active_tokens[piece] > 0:
				text += "%s : %d\n" % [piece, bm.active_tokens[piece]]
		token_label.text = text
