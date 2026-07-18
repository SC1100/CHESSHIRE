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
	# MOUSE_FILTER_PASS로 설정하여 빈 공간 클릭 시 뒤의 체스판(unhandled_input)으로 클릭이 넘어가게 함
	sv_container.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(sv_container)
	
	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true # 뒷 배경 투명화 (핵심)
	sub_viewport.own_world_3d = true # [핵심] 체스 씬의 하늘(WorldEnvironment)과 렌더링 분리
	sub_viewport.size = get_viewport().size
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.physics_object_picking = true # 3D 카드 레이캐스트 감지를 위해 필수
	sv_container.add_child(sub_viewport)
	
	# 창 크기 변경 시 서브뷰포트 크기 동기화
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
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

func _on_viewport_size_changed():
	if is_instance_valid(sub_viewport):
		sub_viewport.size = get_viewport().size

func _setup_token_ui(canvas: CanvasLayer):
	token_label = Label.new()
	# 화면 우측 상단쯤 배치 (필요에 따라 조절)
	token_label.position = Vector2(1600, 50) 
	token_label.add_theme_font_size_override("font_size", 28)
	token_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # 잘 보이도록 노란색
	token_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	token_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(token_label)

func _process(_delta: float):
	# 매 프레임마다 토큰(행동권) 현황을 가져와서 UI 갱신
	var bm = get_tree().get_first_node_in_group("BoardManager")
	if bm and token_label:
		var text = "== [ 기물 행동권 ] ==\n"
		for piece in bm.active_tokens.keys():
			if bm.active_tokens[piece] > 0:
				text += "%s : %d\n" % [piece, bm.active_tokens[piece]]
		token_label.text = text
