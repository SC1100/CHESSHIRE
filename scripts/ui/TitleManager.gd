extends Control
class_name TitleManager

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var option_button: Button = %OptionButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if option_button:
		option_button.pressed.connect(_on_option_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Stage.tscn")

func _on_continue_pressed() -> void:
	# 추후 기능 지정 예정
	pass

func _on_option_pressed() -> void:
	# 추후 기능 지정 예정
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
