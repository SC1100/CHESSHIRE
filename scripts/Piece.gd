extends Node3D
class_name Piece

@export var data: PieceData

func _ready() -> void:
	# 나중에 여기에 "바닥(Y-)으로 레이를 쏴서 현재 칸 인식 후 BoardManager에 등록" 하는 로직이 들어갑니다.
	if data:
		print("기물 생성됨: 팀=%s, 타입=%s, 이름=%s" % [
			PieceData.Team.keys()[data.team], 
			PieceData.Type.keys()[data.type], 
			data.piece_name
		])
	else:
		push_warning("기물에 PieceData가 할당되지 않았습니다: " + name)
