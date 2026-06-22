extends RayCast3D
class_name GridDetectorComponent

signal tile_detected(tile_name: String)

var current_tile_name: String = ""

func _ready() -> void:
	# 1. 자동 업데이트 끄기 (성능 최적화: 필요할 때만 수동으로 쏨)
	enabled = false
	
	# 2. 아래(-Y) 방향으로 길게 레이캐스트 설정 (로컬 좌표계 기준)
	target_position = Vector3(0, -100, 0)
	
	# 3. 체스판 그리드는 Area3D로 이루어져 있으므로 Area 감지 켜기
	collide_with_areas = true
	# 기물 자체에 Body가 있다면 무시 (지금은 Area3D만 씀)
	collide_with_bodies = false
	
	# 4. 자기 자신(기물)의 콜리전은 쏘면서 맞지 않도록 예외 처리
	# 부모(기물의 최상단 루트)부터 탐색하여 기물이 가진 Area3D를 예외로 등록
	var root_node = owner if owner else get_parent()
	if root_node:
		_add_exceptions_recursive(root_node)

func _add_exceptions_recursive(node: Node) -> void:
	if node is Area3D:
		add_exception(node)
	for child in node.get_children():
		if child != self:
			_add_exceptions_recursive(child)

## 수동으로 호출하여 바닥의 타일(그리드)을 감지하고 반환합니다.
func detect_tile() -> String:
	# 강제로 레이캐스트 1회 발사
	force_raycast_update()
	
	if is_colliding():
		var collider = get_collider()
		# 부딪힌 객체가 Area3D(타일)라면
		if collider and collider is Area3D:
			# collider.name은 "a1", "b2" 등의 형태를 가짐
			current_tile_name = collider.name
			tile_detected.emit(current_tile_name)
			return current_tile_name
			
	# 감지 실패 시 초기화
	current_tile_name = ""
	return ""
