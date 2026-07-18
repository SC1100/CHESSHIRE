extends SceneTree
func _init():
    var piece_script = preload("res://scripts/Piece.gd")
    var node = Node3D.new()
    node.set_script(piece_script)
    if node is Piece:
        print("YES_IT_IS_PIECE")
    else:
        print("NO_IT_IS_NOT_PIECE")
    quit()

