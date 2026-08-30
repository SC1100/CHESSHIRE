extends Node

static var current_nickname: String = "player"
var profile_data: Dictionary = {}

func _ready() -> void:
	load_profile(current_nickname)

func get_base_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	else:
		return OS.get_executable_path().get_base_dir()

func get_profile_directory() -> String:
	var profile_dir = get_base_directory().path_join("profile")
	if not DirAccess.dir_exists_absolute(profile_dir):
		DirAccess.make_dir_recursive_absolute(profile_dir)
	return profile_dir

func get_profile_path(nickname: String) -> String:
	return get_profile_directory().path_join(nickname + ".json")

func load_profile(nickname: String) -> Dictionary:
	current_nickname = nickname
	var file_path = get_profile_path(nickname)
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			profile_data = json.data
			print("ProfileManager: '%s.json' 프로필을 성공적으로 불러왔습니다." % nickname)
			return profile_data
			
	# 기존 프로필이 없을 경우 기본 프로필 새로 생성
	print("ProfileManager: '%s.json' 프로필이 없어 신규 프로필을 생성합니다." % nickname)
	profile_data = create_default_profile(nickname)
	save_profile()
	return profile_data

func create_default_profile(nickname: String) -> Dictionary:
	return {
		"profile_info": {
			"nickname": nickname,
			"created_at": Time.get_datetime_string_from_system()
		},
		"permanent_data": {
			"unlocked_cards": ["w_pawn", "w_knight", "w_bishop", "w_rook", "w_queen", "w_king"],
			"total_runs": 1,
			"wins": 0
		},
		"current_run": {
			"is_in_run": true,
			"current_stage_id": "stage1",
			"master_deck": [
				"w_pawn", "w_pawn", "w_pawn", "w_pawn",
				"w_knight", "w_bishop", "w_rook", "w_queen", "w_king"
			],
			"hp": 100
		}
	}

func save_profile() -> void:
	if current_nickname.is_empty():
		current_nickname = "player"
		
	var file_path = get_profile_path(current_nickname)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(profile_data, "\t")
		file.store_string(json_string)
		file.close()
		print("ProfileManager: '%s.json'에 프로필 저장이 완료되었습니다." % current_nickname)
	else:
		push_error("ProfileManager: 프로필 저장 실패! - %s" % file_path)

func get_master_deck() -> Array[String]:
	var deck: Array[String] = []
	if profile_data.has("current_run") and profile_data["current_run"].has("master_deck"):
		for card in profile_data["current_run"]["master_deck"]:
			deck.append(str(card))
	return deck

func add_card_to_master_deck(card_id: String) -> void:
	if profile_data.has("current_run") and profile_data["current_run"].has("master_deck"):
		profile_data["current_run"]["master_deck"].append(card_id)
		save_profile()

func remove_card_from_master_deck(card_id: String) -> void:
	if profile_data.has("current_run") and profile_data["current_run"].has("master_deck"):
		var deck = profile_data["current_run"]["master_deck"]
		var idx = deck.find(card_id)
		if idx != -1:
			deck.remove_at(idx)
			save_profile()

func get_unlocked_cards() -> Array[String]:
	var cards: Array[String] = []
	if profile_data.has("permanent_data") and profile_data["permanent_data"].has("unlocked_cards"):
		for card in profile_data["permanent_data"]["unlocked_cards"]:
			cards.append(str(card))
	if cards.is_empty():
		cards = ["w_pawn", "w_knight", "w_bishop", "w_rook", "w_queen", "w_king"]
	return cards

func unlock_card(card_id: String) -> void:
	if profile_data.has("permanent_data") and profile_data["permanent_data"].has("unlocked_cards"):
		var unlocked = profile_data["permanent_data"]["unlocked_cards"]
		if not unlocked.has(card_id):
			unlocked.append(card_id)
			save_profile()
