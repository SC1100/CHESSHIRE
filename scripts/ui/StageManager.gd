extends Control
class_name StageManager

@onready var stage_1_button: Button = %Stage1Button
@onready var stage_2_button: Button = %Stage2Button
@onready var stage_3_button: Button = %Stage3Button
@onready var back_button: Button = %BackButton

func _ready() -> void:
	_apply_stage_button_styles()
	
	if stage_1_button:
		stage_1_button.pressed.connect(_on_stage_1_pressed)
	if stage_2_button:
		stage_2_button.pressed.connect(_on_stage_2_pressed)
	if stage_3_button:
		stage_3_button.pressed.connect(_on_stage_3_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _apply_stage_button_styles() -> void:
	var stage_buttons = [stage_1_button, stage_2_button, stage_3_button]
	for btn in stage_buttons:
		if not btn: continue
		
		# Normal State (스테이지 카드는 굵은 흰색 테두리 3px, 모서리 14px)
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.10, 0.12, 0.18, 0.88)
		style_normal.set_corner_radius_all(14)
		style_normal.set_border_width_all(3)
		style_normal.border_color = Color(0.92, 0.92, 0.96, 0.95)
		style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style_normal.shadow_size = 10
		btn.add_theme_stylebox_override("normal", style_normal)
		
		# Hover State
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.20, 0.23, 0.35, 0.95)
		style_hover.border_color = Color(1.0, 0.92, 0.45, 1.0) # 마우스 호버 시 골드/화이트 강조
		style_hover.shadow_size = 16
		btn.add_theme_stylebox_override("hover", style_hover)
		
		# Pressed State
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.06, 0.08, 0.14, 0.95)
		style_pressed.border_color = Color(0.75, 0.75, 0.8, 0.8)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		
		# Font Outlines & Colors
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		btn.add_theme_constant_override("outline_size", 6)

	if back_button:
		# 뒤로가기 버튼 전용 스타일 (모서리 10px, 테두리 2px)
		var style_back = StyleBoxFlat.new()
		style_back.bg_color = Color(0.12, 0.14, 0.20, 0.88)
		style_back.set_corner_radius_all(10)
		style_back.set_border_width_all(2)
		style_back.border_color = Color(0.92, 0.92, 0.96, 0.9)
		style_back.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style_back.shadow_size = 6
		back_button.add_theme_stylebox_override("normal", style_back)
		
		var style_back_hover = style_back.duplicate()
		style_back_hover.bg_color = Color(0.22, 0.25, 0.35, 0.95)
		style_back_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
		style_back_hover.shadow_size = 10
		back_button.add_theme_stylebox_override("hover", style_back_hover)
		
		var style_back_pressed = style_back.duplicate()
		style_back_pressed.bg_color = Color(0.08, 0.10, 0.16, 0.95)
		back_button.add_theme_stylebox_override("pressed", style_back_pressed)
		
		back_button.add_theme_color_override("font_color", Color.WHITE)
		back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.5))
		back_button.add_theme_color_override("font_outline_color", Color.BLACK)
		back_button.add_theme_constant_override("outline_size", 4)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/TitleScene.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _on_stage_1_pressed() -> void:
	_transition_to_battle("stage1")

func _on_stage_2_pressed() -> void:
	_transition_to_battle("stage2")

func _on_stage_3_pressed() -> void:
	_transition_to_battle("stage3")

func _transition_to_battle(stage_id: String) -> void:
	BoardManager.current_stage_id = stage_id
	
	# 플레이어가 실제로 스테이지 버튼을 눌러 전투 진입 시 런 공식 시작 확정!
	if ProfileManager.has_method("start_active_run"):
		ProfileManager.start_active_run(stage_id)
		
	# 중복 클릭 방지
	if stage_1_button: stage_1_button.disabled = true
	if stage_2_button: stage_2_button.disabled = true
	if stage_3_button: stage_3_button.disabled = true
	
	var battle_scene_path = "res://Scene/Battle_Scene.tscn"
	
	# 1. 백그라운드 스레드에 배틀 씬 비동기 사전로딩 요청 가동
	ResourceLoader.load_threaded_request(battle_scene_path)
	
	# 2. 최상단 검은색 페이드 레이어를 루트(get_tree().root)에 직접 부착 (씬 전환 시에도 파괴되지 않음!)
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	get_tree().root.add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0) # 투명 상태로 시작
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # 전환 중 클릭 차단
	fade_layer.add_child(fade_rect)
	
	# 0.35초 동안 스무스하게 검은 화면으로 페이드아웃 (Alpha 0.0 -> 1.0)
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	# 3. 비동기 사전로딩이 완전 완료될 때까지 검은 화면 상태로 프레임 대기
	while ResourceLoader.load_threaded_get_status(battle_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		
	# 4. 미리 메모리에 로딩 완료된 PackedScene을 받아 씬 전환
	# (fade_layer는 get_tree().root의 자식이므로 파괴되지 않고 화면을 100% 검게 유지함)
	var tree = fade_layer.get_tree()
	if ResourceLoader.load_threaded_get_status(battle_scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		var packed_scene: PackedScene = ResourceLoader.load_threaded_get(battle_scene_path)
		get_tree().change_scene_to_packed(packed_scene)
	else:
		get_tree().change_scene_to_file(battle_scene_path)
		
	# StageManager 노드는 씬 교체로 인해 트리에서 이탈하므로,
	# 루트(get_tree().root)에 부착된 fade_layer의 트리 참조를 이용해 안전하게 1프레임 후 삭제
	if tree:
		await tree.process_frame
	fade_layer.queue_free()
