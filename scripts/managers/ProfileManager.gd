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
			"unlocked_cards": [
				"w_pawn", "w_knight", "w_bishop", "w_rook", "w_queen", "w_king",
				"t_crusade", "t_disband", "t_lance_charge", "t_last_stand",
				"t_quick_decision", "t_sabotage", "t_spoils", "t_two_cats"
			],
			"total_runs": 0,
			"wins": 0
		},
		"current_run": {
			"is_in_run": false,
			"current_stage_id": "stage1",
			"master_deck": [
				"w_pawn", "w_pawn", "w_pawn", "w_pawn",
				"w_knight", "w_bishop", "w_rook", "w_queen", "w_king",
				"t_lance_charge"
			],
			"hp": 100,
			"stage_snapshot": {}
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

# --- 휘발성 런(Current Run) 스냅샷 관리 ---

func has_active_run() -> bool:
	if profile_data.has("current_run"):
		return profile_data["current_run"].get("is_in_run", false) == true
	return false

func start_new_run() -> void:
	print("ProfileManager: 신규 런을 시작합니다. (런 데이터 초기화)")
	var default_deck = [
		"w_king", "w_queen", "w_rook", "w_knight", "w_bishop",
		"w_pawn", "w_pawn", "w_pawn",
		"t_two_cats", "t_quick_decision"
	]
	
	profile_data["current_run"] = {
		"is_in_run": true,
		"current_stage_id": "stage1",
		"master_deck": default_deck,
		"hp": 100,
		"stage_snapshot": {}
	}
	
	if profile_data.has("permanent_data"):
		profile_data["permanent_data"]["total_runs"] = profile_data["permanent_data"].get("total_runs", 0) + 1
		
	save_profile()

func clear_current_run() -> void:
	print("ProfileManager: 런이 종료되었습니다. (휘발성 런 데이터 소멸)")
	if profile_data.has("current_run"):
		profile_data["current_run"]["is_in_run"] = false
		profile_data["current_run"]["stage_snapshot"] = {}
	save_profile()

# 스테이지 시작 시점의 스냅샷 채록 및 저장
func save_stage_snapshot(stage_id: String, board_state: Dictionary, draw_pile: Array, hand: Array, discard_pile: Array) -> void:
	if not profile_data.has("current_run"):
		return
		
	profile_data["current_run"]["is_in_run"] = true
	profile_data["current_run"]["current_stage_id"] = stage_id
	profile_data["current_run"]["stage_snapshot"] = {
		"stage_id": stage_id,
		"saved_at": Time.get_datetime_string_from_system(),
		"board_state": board_state,
		"draw_pile": draw_pile,
		"hand": hand,
		"discard_pile": discard_pile
	}
	save_profile()
	print("ProfileManager: [%s] 스테이지 시작 시점 스냅샷 채록 완료!" % stage_id)

func get_stage_snapshot() -> Dictionary:
	if profile_data.has("current_run") and profile_data["current_run"].has("stage_snapshot"):
		return profile_data["current_run"]["stage_snapshot"]
	return {}

func get_current_stage_id() -> String:
	if profile_data.has("current_run") and profile_data["current_run"].has("current_stage_id"):
		return str(profile_data["current_run"]["current_stage_id"])
	return "stage1"

# --- 덱 및 영구 데이터 접근자 ---

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
