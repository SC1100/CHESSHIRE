extends Control

var card_manager: CardManager
var log_label: RichTextLabel
var state_label: Label
var hand_container: HBoxContainer

var current_mulligan_cards: Array[CardData] = []

func _ready() -> void:
	# 1. UI 동적 생성 (에디터 작업 최소화를 위해 코드로 자동 생성)
	_setup_ui()
	
	# 2. 카드 매니저 생성 및 씬에 추가
	card_manager = CardManager.new()
	add_child(card_manager)
	
	# 3. 매니저 시그널 연결
	card_manager.hand_updated.connect(_on_hand_updated)
	card_manager.mana_changed.connect(_on_mana_changed)
	card_manager.deck_shuffled.connect(_on_deck_shuffled)
	card_manager.mulligan_started.connect(_on_mulligan_started)
	card_manager.mulligan_ended.connect(_on_mulligan_ended)
	
	# 4. 가짜(더미) 덱 10장 만들기
	var dummy_deck: Array[CardData] = []
	for i in range(10):
		var c_id = "c_" + str(i)
		var c_name = "카드 " + str(i + 1)
		var c_cost = (i % 3) + 1
		# CardData의 _init()은 최소 6개의 인자를 요구합니다.
		var card = CardData.new(c_id, c_name, c_cost, CardData.CardType.SKILL, Rect2(), "테스트 카드입니다.")
		dummy_deck.append(card)
		
	# 5. 전투 시작! (초기 손패 3장 드로우 및 멀리건)
	_log("전투 시작! 덱 10장을 섞고 초기 멀리건을 진행합니다.")
	card_manager.start_combat(dummy_deck, 3)

# --- 시그널 콜백 ---
func _on_mulligan_started(cards: Array[CardData]) -> void:
	_log(">> 멀리건 페이즈 시작! 현재 뽑힌 카드: " + _cards_to_str(cards))
	current_mulligan_cards = cards
	_update_hand_ui_for_mulligan(cards)

func _on_mulligan_ended() -> void:
	_log(">> 멀리건 완료. 본 게임을 시작합니다.")
	current_mulligan_cards.clear()

func _on_hand_updated(hand: Array[CardData]) -> void:
	_log("손패 갱신됨: " + _cards_to_str(hand))
	_update_hand_ui_for_play(hand)

func _on_mana_changed(current: int, max_m: int) -> void:
	state_label.text = "마나: %d / %d\n" % [current, max_m]
	state_label.text += "덱: %d 장 | 무덤: %d 장" % [card_manager.draw_pile.size(), card_manager.discard_pile.size()]

func _on_deck_shuffled(draw_count: int, discard_count: int) -> void:
	_log("덱이 셔플되었습니다! (남은 덱: %d, 무덤: %d)" % [draw_count, discard_count])
	_on_mana_changed(card_manager.current_mana, card_manager.max_mana) # UI 갱신

# --- UI 인터랙션 (버튼 클릭) ---
func _on_mulligan_confirm_pressed() -> void:
	# 테스트: 맨 첫 번째 카드만 버리고(교체), 나머지는 남긴다고 가정
	var kept = []
	var rejected = []
	if current_mulligan_cards.size() > 0:
		rejected.append(current_mulligan_cards[0]) # 1장 교체
		for i in range(1, current_mulligan_cards.size()):
			kept.append(current_mulligan_cards[i])
			
	_log("멀리건 확정! 1번째 카드를 버리고 새로 1장을 뽑습니다.")
	card_manager.confirm_mulligan(kept, rejected)

func _on_draw_button_pressed() -> void:
	_log("1장 드로우 시도...")
	card_manager.draw_cards(1)

func _on_end_turn_button_pressed() -> void:
	_log("턴 종료! 손패를 모두 버리고 마나를 회복합니다.")
	card_manager.end_turn()

func _on_card_play_pressed(card: CardData) -> void:
	var success = card_manager.play_card(card, "target_tile")
	if success:
		_log("카드 사용 성공: %s (남은 코스트: %d)" % [card.card_name, card_manager.current_mana])
	else:
		_log("[실패] 카드 사용 불가: %s (코스트 부족)" % card.card_name)

# --- 헬퍼 함수들 (UI 동적 생성 및 로그) ---
func _log(msg: String) -> void:
	log_label.text += msg + "\n"

func _cards_to_str(cards: Array[CardData]) -> String:
	var names = []
	for c in cards:
		names.append(c.card_name + "(코스트" + str(c.cost) + ")")
	return ", ".join(names)

func _update_hand_ui_for_mulligan(cards: Array[CardData]) -> void:
	for child in hand_container.get_children():
		child.queue_free()
		
	for card in cards:
		var btn = Button.new()
		btn.text = card.card_name + "\n(코스트 " + str(card.cost) + ")"
		btn.disabled = true # 멀리건 중에는 카드를 쓰지 못함
		hand_container.add_child(btn)
		
	var confirm_btn = Button.new()
	confirm_btn.text = "멀리건 확정\n(첫카드 교체)"
	confirm_btn.modulate = Color(1, 0.5, 0.5)
	confirm_btn.pressed.connect(_on_mulligan_confirm_pressed)
	hand_container.add_child(confirm_btn)

func _update_hand_ui_for_play(cards: Array[CardData]) -> void:
	for child in hand_container.get_children():
		child.queue_free()
		
	for card in cards:
		var btn = Button.new()
		btn.text = card.card_name + "\n(코스트 " + str(card.cost) + ")"
		# 버튼 클릭 시 해당 카드 사용
		btn.pressed.connect(func(): _on_card_play_pressed(card))
		hand_container.add_child(btn)

func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	state_label = Label.new()
	state_label.text = "마나: 0 / 0 | 덱: 0 | 무덤: 0"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(state_label)
	
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 300)
	log_label.scroll_following = true
	vbox.add_child(log_label)
	
	var control_hbox = HBoxContainer.new()
	control_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(control_hbox)
	
	var draw_btn = Button.new()
	draw_btn.text = "1장 드로우"
	draw_btn.pressed.connect(_on_draw_button_pressed)
	control_hbox.add_child(draw_btn)
	
	var end_btn = Button.new()
	end_btn.text = "턴 종료"
	end_btn.pressed.connect(_on_end_turn_button_pressed)
	control_hbox.add_child(end_btn)
	
	hand_container = HBoxContainer.new()
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(hand_container)
