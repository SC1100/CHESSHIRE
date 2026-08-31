extends CanvasLayer
class_name PromotionUI

signal promotion_selected(piece_type: String)

func _ready() -> void:
	layer = 95 # 최상단 오버레이
	
	# 어두운 반투명 필터 배경
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(backdrop)
	
	# 화면 중앙 컨테이너
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)
	
	# 1. 헤더: 소멸 텍스트 시퀀스 양식과 동기화된 [ PROMOTION ] 타이틀
	var title = Label.new()
	title.text = "[ PROMOTION ]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35)) # 골드 헤더
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0)) # 뚜렷한 검은 테두리
	title.add_theme_constant_override("outline_size", 14)
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "폰이 최후방에 도달했습니다! 승급할 기물 카드를 선택하십시오."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	desc.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	desc.add_theme_constant_override("outline_size", 8)
	vbox.add_child(desc)
	
	# 2. 카드 4장 가로 배치 컨테이너
	var cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(cards_hbox)
	
	var option_cards = [
		{"id": "w_queen", "type": "Queen"},
		{"id": "w_rook", "type": "Rook"},
		{"id": "w_bishop", "type": "Bishop"},
		{"id": "w_knight", "type": "Knight"}
	]
	
	for opt in option_cards:
		var card_widget = _create_promotion_card_widget(opt["id"], opt["type"])
		cards_hbox.add_child(card_widget)

func _create_promotion_card_widget(card_id: String, piece_type: String) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(200, 250)
	
	# 카드 기본 래퍼 버튼
	var card_btn = Button.new()
	card_btn.custom_minimum_size = Vector2(200, 250)
	card_btn.pivot_offset = Vector2(100, 125)
	
	# 카드 룩앤필 프레임 스타일
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style_normal.set_corner_radius_all(14)
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(0.8, 0.7, 0.35, 0.9) # 골드 카드 프레임
	style_normal.shadow_color = Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 8
	card_btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.22, 0.28)
	style_hover.border_color = Color(1.0, 0.9, 0.4)
	style_hover.shadow_size = 14
	card_btn.add_theme_stylebox_override("hover", style_hover)
	
	container.add_child(card_btn)
	
	# 카드 내부 레이아웃 (이미지, 이름)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(vbox)
	
	var data = CardData.database.get(card_id, null)
	
	if data and ResourceLoader.exists(data.image_path):
		var tex_rect = TextureRect.new()
		tex_rect.texture = data.get_texture()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(170, 160)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)
		
	var name_lbl = Label.new()
	name_lbl.text = data.card_name if data else piece_type
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	
	# 마우스 호버 애니메이션 (위로 살짝 솟아오름)
	card_btn.mouse_entered.connect(func():
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card_btn, "position:y", -12.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card_btn.mouse_exited.connect(func():
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card_btn, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	
	card_btn.pressed.connect(func():
		promotion_selected.emit(piece_type)
		queue_free()
	)
	
	return container
