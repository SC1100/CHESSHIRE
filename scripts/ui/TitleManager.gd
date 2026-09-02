extends Control
class_name TitleManager

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var option_button: Button = %OptionButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	_apply_title_button_styles()
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		# 저장된 런이 있을 때만 이어하기 활성화
		var has_run = ProfileManager.has_active_run()
		continue_button.disabled = not has_run
		if not has_run:
			continue_button.tooltip_text = "진행 중인 게임이 없습니다."
	if option_button:
		option_button.pressed.connect(_on_option_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _apply_title_button_styles() -> void:
	var buttons = [new_game_button, continue_button, option_button, quit_button]
	for btn in buttons:
		if not btn: continue
		
		# Normal State
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.10, 0.12, 0.18, 0.88)
		style_normal.set_corner_radius_all(10)
		style_normal.set_border_width_all(2)
		style_normal.border_color = Color(0.92, 0.92, 0.96, 0.9)
		style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style_normal.shadow_size = 6
		btn.add_theme_stylebox_override("normal", style_normal)
		
		# Hover State
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.20, 0.23, 0.33, 0.95)
		style_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)
		style_hover.shadow_size = 10
		btn.add_theme_stylebox_override("hover", style_hover)
		
		# Pressed State
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.06, 0.08, 0.14, 0.95)
		style_pressed.border_color = Color(0.75, 0.75, 0.8, 0.8)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		
		# Disabled State
		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = Color(0.08, 0.08, 0.1, 0.5)
		style_disabled.set_corner_radius_all(10)
		style_disabled.set_border_width_all(1)
		style_disabled.border_color = Color(0.35, 0.35, 0.4, 0.4)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		
		# Font Outlines & Colors
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.5))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.5))
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		btn.add_theme_constant_override("outline_size", 5)

func _on_new_game_pressed() -> void:
	# 스테이지 선택 화면으로 이동 (실제 스테이지 버튼 클릭 시 신규 런 시작 확정)
	get_tree().change_scene_to_file("res://Scene/Stage.tscn")

func _on_continue_pressed() -> void:
	if not ProfileManager.has_active_run():
		return
		
	var stage_id = ProfileManager.get_current_stage_id()
	print("TitleManager: 이어서 하기 진행 - 스테이지:", stage_id)
	BoardManager.current_stage_id = stage_id
	
	# 중복 클릭 방지
	if continue_button: continue_button.disabled = true
	if new_game_button: new_game_button.disabled = true
	
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
	var tree = fade_layer.get_tree()
	if ResourceLoader.load_threaded_get_status(battle_scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		var packed_scene: PackedScene = ResourceLoader.load_threaded_get(battle_scene_path)
		get_tree().change_scene_to_packed(packed_scene)
	else:
		get_tree().change_scene_to_file(battle_scene_path)
		
	if tree:
		await tree.process_frame
	fade_layer.queue_free()

func _on_option_pressed() -> void:
	# 추후 기능 지정 예정
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
