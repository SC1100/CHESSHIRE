class_name Grid
extends RefCounted

static var current_grid_info: Dictionary = {}

# 스테이지를 불러올 때 호출하여 그리드 정보를 세팅합니다.
static func setup(info: Dictionary) -> void:
	current_grid_info = info

# 해당 타일이 지나갈 수 없는(블락된) 특수 타일인지 확인합니다.
static func is_tile_blocked(tile_name: String) -> bool:
	if current_grid_info.has("blocked_tiles"):
		var blocked = current_grid_info["blocked_tiles"]
		if tile_name in blocked:
			return true
	return false

# 향후 최대 크기(max_cols, max_rows)나 다른 맵 기믹을 확인하는 함수를 여기에 추가할 수 있습니다.
