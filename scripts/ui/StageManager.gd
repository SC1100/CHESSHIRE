extends Control
class_name StageManager

@onready var stage_1_button: Button = %Stage1Button
@onready var stage_2_button: Button = %Stage2Button
@onready var stage_3_button: Button = %Stage3Button
@onready var back_button: Button = %BackButton

func _ready() -> void:
	if stage_1_button:
		stage_1_button.pressed.connect(_on_stage_1_pressed)
	if stage_2_button:
		stage_2_button.pressed.connect(_on_stage_2_pressed)
	if stage_3_button:
		stage_3_button.pressed.connect(_on_stage_3_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

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
