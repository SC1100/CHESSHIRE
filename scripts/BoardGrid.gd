@tool
extends Node3D

## 체스판 메쉬를 기준으로 a1~h8 총 64개 Area3D 콜리전 칸을 자동 생성하는 도구
## 사용법:
##   1. Node3D에 이 스크립트를 붙인다
##   2. 인스펙터에서 board_mesh에 Chess Board_07 메쉬를 할당
##   3. generate_grid 체크박스를 클릭 → 64칸 생성

@export var board_mesh: MeshInstance3D

@export_group("도구")
@export var generate_grid: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_build_grid()
		generate_grid = false

@export var clear_grid: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_clear_grid()
		clear_grid = false


@export_group("그리드 설정")
## X축 방향 분할 칸 수 (행)
@export var cells_x: int = 8
## Z축 방향 분할 칸 수 (열)
@export var cells_z: int = 8

func _build_grid() -> void:
	if not board_mesh:
		push_error("BoardGrid: board_mesh를 지정해주세요.")
		return

	_clear_grid()

	var aabb := board_mesh.get_aabb()
	var size := aabb.size
	var origin := aabb.position

	# 메쉬의 AABB에서 가장 넓은 두 축(표면)과 좁은 축(두께)을 찾음
	var axes = [
		{"axis": 0, "size": size.x},
		{"axis": 1, "size": size.y},
		{"axis": 2, "size": size.z}
	]
	axes.sort_custom(func(a, b): return a["size"] > b["size"])
	
	var axis_a = axes[0]["axis"]
	var axis_b = axes[1]["axis"]
	var up_axis = axes[2]["axis"]

	# 보통 로컬 X축이 가로 역할을 하므로, X축이 표면에 포함되면 X축을 행(숫자)으로 사용
	var row_axis = axis_a
	var col_axis = axis_b
	if axis_b == 0: # 0은 X축
		row_axis = axis_b
		col_axis = axis_a

	# 표면의 두 축을 기준으로 타일 크기 계산
	var tile_size_x: float = size[row_axis] / float(cells_x)
	var tile_size_z: float = size[col_axis] / float(cells_z)
	
	# 높이(표면) 위치
	var surface_y: float = origin[up_axis] + size[up_axis]

	var mesh_xform := board_mesh.global_transform
	var inv_self := global_transform.affine_inverse()

	# 콜리전 크기: 각 칸에 꽉 차는 크기 (두께는 0.05로 얇게 설정)
	var tile_local := Vector3.ZERO
	tile_local[row_axis] = tile_size_x
	tile_local[col_axis] = tile_size_z
	tile_local[up_axis] = 0.05
	var collision_size := (inv_self.basis * (mesh_xform.basis * tile_local)).abs()

	for x in cells_x:
		for z in cells_z:
			# Z루프를 열(a, b, c...), X루프를 행(1, 2, 3...)으로 가정하여 이름 생성
			var col_letter := String.chr(97 + z) if z < 26 else "c" + str(z)
			var square_name := col_letter + str(x + 1)

			# Z방향(열)은 현재 상태에서 반전(왼쪽부터 a,b,c...)되도록 (cells_z - 1 - z) 적용
			var mesh_pos := Vector3.ZERO
			mesh_pos[row_axis] = origin[row_axis] + tile_size_x * (x + 0.5)
			mesh_pos[col_axis] = origin[col_axis] + tile_size_z * (cells_z - 1 - z + 0.5)
			mesh_pos[up_axis] = surface_y

			# 좌표 변환: 메쉬 로컬 → 글로벌 → 이 노드 로컬
			var pos := inv_self * (mesh_xform * mesh_pos)

			var area := Area3D.new()
			area.name = square_name
			area.position = pos

			var col_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = collision_size
			col_shape.shape = box

			# 주의: owner를 설정하기 전에 먼저 트리에 추가되어야 합니다.
			add_child(area)
			area.owner = get_tree().edited_scene_root
			
			area.add_child(col_shape)
			col_shape.owner = get_tree().edited_scene_root

	print("BoardGrid: 총 %d칸 생성 완료 (X축 %d칸, Z축 %d칸)" % [cells_x * cells_z, cells_x, cells_z])
	print("  타일 크기: X=%.4f, Z=%.4f" % [tile_size_x, tile_size_z])

func _clear_grid() -> void:
	var targets: Array[Node] = []
	for child in get_children():
		if child is Area3D:
			targets.append(child)
	for node in targets:
		node.queue_free()
