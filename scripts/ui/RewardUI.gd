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
	var title_label = Label.new()
	title_label.text = "STAGE CLEAR!"
	title_label.add_theme_font_size_override("font_size", 54)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)

	# 서브 타이틀
	var sub_label = Label.new()
	sub_label.text = "해금된 보상 카드 3장 중 1장을 선택하여 덱을 강화하세요."
	sub_label.add_theme_font_size_override("font_size", 22)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(sub_label)

	# 카드 선택 영역
	card_options_container = HBoxContainer.new()
	card_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_options_container.add_theme_constant_override("separation", 30)
	main_container.add_child(card_options_container)

	_generate_card_rewards()

	# 안내/상태 표시 라벨
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(status_label)

	# 하단 버튼 하모니 (카드 삭제 / 다음 스테이지)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	main_container.add_child(btn_hbox)

	var remove_btn = Button.new()
	remove_btn.text = "🗑️ 덱에서 카드 1장 삭제 (정제)"
	remove_btn.custom_minimum_size = Vector2(260, 50)
	remove_btn.add_theme_font_size_override("font_size", 18)
	remove_btn.pressed.connect(_on_remove_card_pressed)
	btn_hbox.add_child(remove_btn)

	var next_btn = Button.new()
	next_btn.text = "다음 스테이지로 ➔"
	next_btn.custom_minimum_size = Vector2(200, 50)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.pressed.connect(_on_next_stage_pressed)
	btn_hbox.add_child(next_btn)

func _generate_card_rewards():
	var pm = get_pm()
	var unlocked_pool: Array[String] = []
	if pm and pm.has_method("get_unlocked_cards"):
		unlocked_pool = pm.get_unlocked_cards()
	if unlocked_pool.is_empty():
		unlocked_pool = ["w_pawn", "w_knight", "w_bishop", "w_rook", "w_queen"]

	unlocked_pool.shuffle()
	var selected_cards: Array[String] = []
	for i in range(min(3, unlocked_pool.size())):
		selected_cards.append(unlocked_pool[i])

	while selected_cards.size() < 3 and not unlocked_pool.is_empty():
		selected_cards.append(unlocked_pool.pick_random())

	for card_id in selected_cards:
		var card_panel = _create_reward_card_panel(card_id)
		card_options_container.add_child(card_panel)

func _create_reward_card_panel(card_id: String) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 340)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var data = CardData.database.get(card_id, null)
	var card_name = data.card_name if data else card_id
	var card_cost = data.cost if data else 1
	var card_desc = data.description if data else ""

	if data and ResourceLoader.exists(data.image_path):
		var tex_rect = TextureRect.new()
		tex_rect.texture = data.get_texture()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(200, 160)
		vbox.add_child(tex_rect)

	var name_lbl = Label.new()
	name_lbl.text = card_name + " (코스트: %d)" % card_cost
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = card_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)

	var claim_btn = Button.new()
	claim_btn.text = "덱에 추가"
	claim_btn.custom_minimum_size = Vector2(180, 45)
	claim_btn.add_theme_font_size_override("font_size", 18)
	claim_btn.pressed.connect(func(): _claim_card(card_id, card_name))
	vbox.add_child(claim_btn)

	return panel

func _claim_card(card_id: String, card_name: String):
	if card_claimed: return
	card_claimed = true
	var pm = get_pm()
	if pm and pm.has_method("add_card_to_master_deck"):
		pm.add_card_to_master_deck(card_id)
	status_label.text = "✨ [%s] 카드를 덱에 추가했습니다!" % card_name

	for child in card_options_container.get_children():
		child.modulate = Color(0.5, 0.5, 0.5, 0.6)

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
	p_title.text = "🗑️ 덱에서 삭제할 카드를 선택하세요"
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
		status_label.text = "🗑️ [%s] 카드를 덱에서 삭제했습니다!" % card_name
		pop_canvas.queue_free()
	)

	return btn

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
		# 모든 스테이지 완료 시 스테이지 선택 화면으로 복귀
		print("RewardUI: 모든 스테이지를 클리어했습니다!")
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
