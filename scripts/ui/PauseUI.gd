extends CanvasLayer
class_name PauseUI

# 배틀 일시정지 오버레이 UI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 상태에서도 버튼 입력 및 ESC 감지 유지
	layer = 99 # 최상단 오버레이
	_build_ui()

func _build_ui() -> void:
	# 1. 화면 전체를 커버하는 블러 & 어두운 배경 오버레이 (마우스 클릭 100% 차단)
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP # 배틀 씬으로 클릭 전달 완벽 차단
	
	# 블러 + 어두운 틴트 쉐이더 적용
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
	uniform vec4 color_tint : source_color = vec4(0.03, 0.03, 0.08, 0.80);
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	
	void fragment() {
		vec4 lod_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
		COLOR = mix(lod_color, color_tint, color_tint.a);
	}
	"""
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	backdrop.material = shader_mat
	add_child(backdrop)

	# 2. 화면 중앙 정렬 컨테이너
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# 3. 타이틀 헤더: [ PAUSE ]
	var title = Label.new()
	title.text = "[ PAUSE ]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35)) # 골드 헤더
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 12)
	vbox.add_child(title)

	# 여백 서브 타이틀
	var subtitle = Label.new()
	subtitle.text = "일시 정지됨"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vbox.add_child(subtitle)

	# 간격 여백
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# 4. 메뉴 버튼 생성
	var btn_resume = _create_styled_button("Resume", "이어서 하기")
	var btn_option = _create_styled_button("Option", "옵션")
	var btn_title = _create_styled_button("Title", "타이틀로 이동")
	var btn_quit = _create_styled_button("Quit", "게임 종료")

	vbox.add_child(btn_resume)
	vbox.add_child(btn_option)
	vbox.add_child(btn_title)
	vbox.add_child(btn_quit)

	# 버튼 이벤트 연결
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_option.pressed.connect(_on_option_pressed)
	btn_title.pressed.connect(_on_title_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _create_styled_button(btn_text: String, sub_text: String) -> Button:
	var btn = Button.new()
	btn.text = "%s  (%s)" % [btn_text, sub_text]
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pivot_offset = Vector2(150, 26)
	
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
	
	# Font Outlines & Colors
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.5))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 5)
	
	# 호버 애니메이션 효과 (1.05배 부드럽게 확대)
	btn.mouse_entered.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn.mouse_exited.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_option_pressed() -> void:
	# 옵션 기능 - 추후 구현 예정 (아무 동작도 하지 않음)
	print("[PauseUI] 옵션 버튼 클릭됨 (미구현)")

func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/TitleScene.tscn")
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()
