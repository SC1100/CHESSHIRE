extends Control
class_name StageManager

@onready var stage_1_button: Button = %Stage1Button
@onready var stage_2_button: Button = %Stage2Button
@onready var stage_3_button: Button = %Stage3Button

func _ready() -> void:
	if stage_1_button:
		stage_1_button.pressed.connect(_on_stage_1_pressed)
	if stage_2_button:
		stage_2_button.pressed.connect(_on_stage_2_pressed)
	if stage_3_button:
		stage_3_button.pressed.connect(_on_stage_3_pressed)

func _on_stage_1_pressed() -> void:
	BoardManager.current_stage_id = "stage1"
	get_tree().change_scene_to_file("res://Scene/Battle_Scene.tscn")

func _on_stage_2_pressed() -> void:
	BoardManager.current_stage_id = "stage2"
	get_tree().change_scene_to_file("res://Scene/Battle_Scene.tscn")

func _on_stage_3_pressed() -> void:
	# 추후 호출 씬 지정 예정 (현재는 대기)
	pass
