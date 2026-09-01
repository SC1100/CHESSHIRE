extends CanvasLayer

var bg_rect: ColorRect
var main_container: VBoxContainer
var card_options_container: HBoxContainer
var status_label: Label
var card_claimed: bool = false
var card_removed: bool = false

func _ready():
	layer = 100
	_build_ui()

func get_pm() -> Node:
	if get_tree() and get_tree().root.has_node("ProfileManager"):
		return get_tree().root.get_node("ProfileManager")
	return null

func _build_ui():
	# 1. 어두운 배경 오버레이
	bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0.05, 0.05, 0.1, 0.88)
	add_child(bg_rect)

	# 2. 화면 전체를 커버하는 CenterContainer (완벽 중앙 정렬)
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	# 3. 메인 패널 수직 컨테이너
	main_container = VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(1000, 700)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 24)
	center_container.add_child(main_container)

	# 타이틀
	var is_final_stage = (BoardManager.current_stage_id == "stage3")
	var title_label = Label.new()
	title_label.text = "ALL STAGES CLEAR!" if is_final_stage else "STAGE CLEAR!"
	title_label.add_theme_font_size_override("font_size", 54)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)

	# 서브 타이틀
	var sub_label = Label.new()
	sub_label.text = "보상 카드 4장 중 1장을 선택하여 덱에 추가하세요."
	sub_label.add_theme_font_size_override("font_size", 22)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(sub_label)

	# 카드 선택 영역
	card_options_container = HBoxContainer.new()
	card_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_options_container.add_theme_constant_override("separation", 24)
	main_container.add_child(card_options_container)

	_generate_card_rewards()

	# 안내/상태 표시 라벨
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(status_label)

	# 하단 버튼 하모니 (카드 삭제 / 덱 유지 1스테이지 재도전 / 다음 스테이지 또는 런 종료)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	main_container.add_child(btn_hbox)

	var remove_btn = Button.new()
	remove_btn.text = "덱에서 카드 1장 삭제"
	remove_btn.custom_minimum_size = Vector2(260, 50)
	remove_btn.add_theme_font_size_override("font_size", 18)
	remove_btn.pressed.connect(_on_remove_card_pressed)
	btn_hbox.add_child(remove_btn)

	if is_final_stage:
		# 3스테이지 클리어 특수 선택지: 덱을 유지한 채 1스테이지 재도전 (회차 루프)
		var loop_btn = Button.new()
		loop_btn.text = "덱 유지하고 1스테이지 재도전"
		loop_btn.custom_minimum_size = Vector2(280, 50)
		loop_btn.add_theme_font_size_override("font_size", 18)
		loop_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		loop_btn.pressed.connect(_on_restart_with_current_deck_pressed)
		btn_hbox.add_child(loop_btn)

	var next_btn = Button.new()
	next_btn.text = "런 완료 (메인으로)" if is_final_stage else "다음 스테이지로 ➔"
	next_btn.custom_minimum_size = Vector2(200, 50)
	next_btn.add_theme_font_size_override("font_size", 18 if is_final_stage else 20)
	next_btn.pressed.connect(_on_next_stage_pressed)
	btn_hbox.add_child(next_btn)

func _generate_card_rewards():
	var piece_pool: Array[String] = []
	var tactic_pool: Array[String] = []

	# 전체 카드 DB에서 기물 카드와 전술 카드를 각각 분리
	for card_id in CardData.database.keys():
		if _is_piece_card(card_id):
			piece_pool.append(card_id)
		else:
			tactic_pool.append(card_id)

	piece_pool.shuffle()
	tactic_pool.shuffle()

	var selected_cards: Array[String] = []

	# 보상 카드 4슬롯을 순회하며 슬롯별로 기물(40%) / 전술(60%) 확률 롤 적용
	for slot in range(4):
		var pick: String = ""
		var roll = randf() # 0.0 ~ 1.0 무작위 난수
		
		# 40% 확률로 기물 카드, 60% 확률로 전술 카드 선호 선택
		if roll < 0.40:
			pick = _pick_unique_card(piece_pool, selected_cards)
			if pick == "":
				pick = _pick_unique_card(tactic_pool, selected_cards)
		else:
			pick = _pick_unique_card(tactic_pool, selected_cards)
			if pick == "":
				pick = _pick_unique_card(piece_pool, selected_cards)

		if pick != "":
			selected_cards.append(pick)

	for card_id in selected_cards:
		var card_panel = _create_reward_card_panel(card_id)
		card_options_container.add_child(card_panel)

func _is_piece_card(card_id: String) -> bool:
	var data = CardData.database.get(card_id, null)
	if data:
		return data.type == CardData.CardType.PIECE or "Piece" in data.tags
	return card_id.begins_with("w_")

func _pick_unique_card(pool: Array[String], already_selected: Array[String]) -> String:
	for card_id in pool:
		if not already_selected.has(card_id):
			return card_id
	return ""

func _create_reward_card_panel(card_id: String) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(210, 310)

	var data = CardData.database.get(card_id, null)
	var card_name = data.card_name if data else card_id

	# 카드 기본 래퍼 버튼 (카드 전체 클릭 영역 및 호버 애니메이션 연동)
	var card_btn = Button.new()
	card_btn.custom_minimum_size = Vector2(210, 310)
	card_btn.pivot_offset = Vector2(105, 155)

	# 카드 프레임 고급 스타일 (골드/다크 룩앤필)
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style_normal.set_corner_radius_all(14)
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(0.8, 0.7, 0.35, 0.9)
	style_normal.shadow_color = Color(0, 0, 0, 0.6)
	style_normal.shadow_size = 10
	card_btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.22, 0.28)
	style_hover.border_color = Color(1.0, 0.9, 0.45)
	style_hover.shadow_size = 16
	card_btn.add_theme_stylebox_override("hover", style_hover)

	container.add_child(card_btn)

	# 카드 내부 텍스처 (크고 명확하게 카드 이미지 전면 노출)
	if data and ResourceLoader.exists(data.image_path):
		var tex_rect = TextureRect.new()
		tex_rect.texture = data.get_texture()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.offset_left = 6
		tex_rect.offset_top = 6
		tex_rect.offset_right = -6
		tex_rect.offset_bottom = -6
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(tex_rect)

	# 프로모션 스타일 마우스 호버 애니메이션 (부드럽게 솟아오르고 확대)
	card_btn.mouse_entered.connect(func():
		if card_claimed: return
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card_btn, "position:y", -14.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_btn, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card_btn.mouse_exited.connect(func():
		if card_claimed: return
		var tw = create_tween().set_parallel(true)
		tw.tween_property(card_btn, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

	card_btn.pressed.connect(func():
		_claim_card(card_id, card_name, card_btn)
	)

	return container

func _claim_card(card_id: String, card_name: String, selected_btn: Button):
	if card_claimed: return
	card_claimed = true
	var pm = get_pm()
	if pm and pm.has_method("add_card_to_master_deck"):
		pm.add_card_to_master_deck(card_id)
	status_label.text = "[ %s ] 카드를 덱에 추가했습니다!" % card_name

	for child in card_options_container.get_children():
		var btn = child.get_child(0) as Button
		if btn == selected_btn:
			var tw = create_tween().set_parallel(true)
			tw.tween_property(btn, "position:y", -18.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			btn.modulate = Color(0.4, 0.4, 0.4, 0.45)

func _on_remove_card_pressed():
	if card_removed:
		status_label.text = "이번 보상에서는 이미 카드 1장을 삭제했습니다."
		return

	var pm = get_pm()
	var current_deck: Array[String] = []
	if pm and pm.has_method("get_master_deck"):
		current_deck = pm.get_master_deck()

	if current_deck.is_empty():
		status_label.text = "삭제할 카드가 덱에 없습니다."
		return

	var pop_canvas = CanvasLayer.new()
	pop_canvas.layer = 110
	add_child(pop_canvas)

	var pop_bg = ColorRect.new()
	pop_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_bg.color = Color(0, 0, 0, 0.88)
	pop_canvas.add_child(pop_bg)

	var center_pop = CenterContainer.new()
	center_pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_canvas.add_child(center_pop)

	var pop_vbox = VBoxContainer.new()
	pop_vbox.custom_minimum_size = Vector2(960, 560)
	pop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pop_vbox.add_theme_constant_override("separation", 16)
	center_pop.add_child(pop_vbox)

	var p_title = Label.new()
	p_title.text = "덱에서 삭제할 카드를 선택하세요"
	p_title.add_theme_font_size_override("font_size", 32)
	p_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_vbox.add_child(p_title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 420)
	pop_vbox.add_child(scroll)

	var grid_center = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_center)

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid_center.add_child(grid)

	for c_id in current_deck:
		var card_panel = _create_removal_card_panel(c_id, pm, pop_canvas)
		grid.add_child(card_panel)

	var cancel_btn = Button.new()
	cancel_btn.text = "닫기"
	cancel_btn.custom_minimum_size = Vector2(140, 45)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(func(): pop_canvas.queue_free())
	pop_vbox.add_child(cancel_btn)

func _create_removal_card_panel(card_id: String, pm: Node, pop_canvas: CanvasLayer) -> Control:
	var data = CardData.database.get(card_id, null)
	var card_name = data.card_name if data else card_id

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(160, 220)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	if data and ResourceLoader.exists(data.image_path):
		btn.texture_normal = data.get_texture()

	# 카드 클릭 시 삭제 처리
	btn.pressed.connect(func():
		if pm and pm.has_method("remove_card_from_master_deck"):
			pm.remove_card_from_master_deck(card_id)
		card_removed = true
		status_label.text = "[ %s ] 카드를 덱에서 삭제했습니다." % card_name
		pop_canvas.queue_free()
	)

	return btn

# --- 3스테이지 완료 후 현재 덱을 유지한 채 1스테이지로 재도전 (회차 플레이) ---
func _on_restart_with_current_deck_pressed():
	BoardManager.current_stage_id = "stage1"
	var pm = get_pm()
	if pm and "profile_data" in pm and pm.profile_data.has("current_run"):
		pm.profile_data["current_run"]["current_stage_id"] = "stage1"
		pm.save_profile()
	print("RewardUI: 강화된 덱을 그대로 유지한 채 1스테이지 재도전(NEW GAME+)을 시작합니다!")
	get_tree().change_scene_to_file("res://Scene/Battle_Scene.tscn")

func _on_next_stage_pressed():
	# 현재 스테이지 확인 후 다음 스테이지 진입
	var current_id = BoardManager.current_stage_id
	var next_id = "stage2"
	
	if current_id == "stage1":
		next_id = "stage2"
	elif current_id == "stage2":
		next_id = "stage3"
	elif current_id == "test_stage":
		next_id = "stage1"
	elif current_id == "stage3":
		# 모든 스테이지 완료 시 런 소멸 처리 및 스테이지 선택 화면으로 복귀
		print("RewardUI: 모든 스테이지를 클리어했습니다! 런을 성공적으로 완료합니다.")
		var pm_node = get_pm()
		if pm_node and pm_node.has_method("clear_current_run"):
			pm_node.clear_current_run()
		get_tree().change_scene_to_file("res://Scene/Stage.tscn")
		return
	
	# 다음 스테이지로 ID 변경 및 세이브 업데이트
	BoardManager.current_stage_id = next_id
	
	var pm = get_pm()
	if pm and "profile_data" in pm and pm.profile_data.has("current_run"):
		pm.profile_data["current_run"]["current_stage_id"] = next_id
		pm.save_profile()
		
	print("RewardUI: 다음 스테이지 '%s'로 직행합니다." % next_id)
	get_tree().change_scene_to_file("res://Scene/Battle_Scene.tscn")
