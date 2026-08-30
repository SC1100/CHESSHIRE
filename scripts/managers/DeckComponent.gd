class_name DeckComponent
extends Node

# UI 업데이트를 위한 시그널
signal deck_shuffled
signal counts_changed(draw_count: int, discard_count: int)

# 런타임에 쓰이는 3가지 덱 영역 (저장되는 파일이 아닌 휘발성 메모리 데이터)
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []

# 문자열 배열 덱을 기반으로 덱을 초기화합니다.
func initialize_from_deck_list(deck_list: Array[String]):
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	draw_pile = deck_list.duplicate()
	draw_pile.shuffle()
	_update_counts()
	print("덱 초기화 완료! 현재 남은 카드 수: ", draw_pile.size())

# 게임/스테이지 시작 시 플레이어 세이브 데이터를 기반으로 덱을 초기화합니다.
func initialize(player_data: PlayerData):
	initialize_from_deck_list(player_data.deck_card_ids)

# 카드 한 장을 뽑아 그 ID를 반환합니다.
func draw_card() -> String:
	# 뽑을 덱도 없고 버린 덱도 없다면 뽑을 수 없음 (탈진 상태 등)
	if draw_pile.is_empty() and discard_pile.is_empty():
		return ""
		
	# 뽑을 카드가 다 떨어졌다면 버린 카드 더미를 가져와 섞습니다.
	if draw_pile.is_empty():
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		draw_pile.shuffle()
		deck_shuffled.emit()
		print("덱을 모두 소모하여 버린 카드 더미를 다시 섞었습니다!")
		
	# 배열의 맨 끝(맨 위)에서 카드를 한 장 빼서 반환합니다.
	var drawn_card_id = draw_pile.pop_back()
	
	_update_counts()
	return drawn_card_id

# 사용한 카드를 버린 카드 더미로 보냅니다.
func discard_card(card_id: String):
	discard_pile.append(card_id)
	_update_counts()

# 소멸(Exhaust) 특성을 가진 카드 등을 소멸 더미로 보냅니다.
func exhaust_card(card_id: String):
	exhaust_pile.append(card_id)
	_update_counts()

# 남은 카드 수 등에 변동이 생길 때마다 시그널을 방출합니다.
func _update_counts():
	counts_changed.emit(draw_pile.size(), discard_pile.size())
