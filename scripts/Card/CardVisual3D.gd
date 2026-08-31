class_name CardVisual3D
extends Area3D

var data: CardData
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

# 애니메이션 및 위치 제어용 변수
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var is_dragging: bool = false
var is_drawing: bool = false # 드로우 애니메이션 진행 여부

func _init(_data: CardData):
	data = _data
	
	# 1. 3D 메쉬(외형) 생성 - 앞면
	mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.5) # 카드의 3D 비율 (정확한 2:3 비율 / 800x1200 에셋 동기화)
	mesh_instance.mesh = quad
	
	# 매테리얼 설정
	var mat = StandardMaterial3D.new()
	
	# 개별 이미지 텍스처를 적용합니다.
	var tex = data.get_texture()
	mat.albedo_texture = tex
	
	mat.cull_mode = BaseMaterial3D.CULL_BACK # 뒷면은 안 보이도록(뒷면용 메쉬 따로 생성)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # 빛 영향 없이 선명하게 보이도록 설정
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	# 1-2. 3D 메쉬 생성 - 뒷면
	var back_mesh_instance = MeshInstance3D.new()
	back_mesh_instance.mesh = quad # 같은 크기의 판(Quad) 재사용
	
	var back_mat = StandardMaterial3D.new()
	back_mat.albedo_texture = load("res://Asset/test/card_back_test.png")
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	back_mesh_instance.material_override = back_mat
	back_mesh_instance.rotation_degrees = Vector3(0, 180, 0) # 뒤집어지게 설정
	back_mesh_instance.position = Vector3(0, 0, -0.001) # 앞면과 겹쳐서 깨지지(Z-fighting) 않도록 살짝 뒤로 뺌
	add_child(back_mesh_instance)
	
	# 2. 충돌체(Raycast 감지용) 생성
	collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.36, 0.05) # 아주 얇은 두께의 충돌 박스
	collision_shape.shape = box
	add_child(collision_shape)
	
	# 3. 레이어 설정
	# 체스 보드와 충돌 간섭을 피하기 위해 collision_layer를 2로 설정 (원하시는 대로 수정 가능)
	collision_layer = 2
	collision_mask = 0

func _process(delta: float):
	if is_dragging or is_drawing:
		return # 드래그 중이거나 드로우 애니메이션 중에는 외부(매니저/트윈)에서 위치를 제어합니다.
		
	# 드래그 중이 아닐 때는 목표 위치(부채꼴 대형)로 부드럽게 날아갑니다.
	global_position = global_position.lerp(target_position, 10.0 * delta)
	
	# 회전 보간 시에는 쿼터니언(Quaternion)을 사용하는 것이 안전합니다.
	# 부모 노드(CardManager)가 Scale을 가지고 있기 때문에, 단순 형변환이 아닌 get_rotation_quaternion()을 써야 합니다.
	var current_scale = global_transform.basis.get_scale()
	var current_quat = global_transform.basis.get_rotation_quaternion()
	var target_quat = Quaternion.from_euler(target_rotation)
	
	var new_basis = Basis(current_quat.slerp(target_quat, 10.0 * delta))
	# 회전 후 기존 글로벌 스케일을 다시 곱해줍니다.
	global_transform.basis = new_basis.scaled(current_scale)

# 카드 앞/뒷면 메쉬의 알파(투명도) 일괄 조정 헬퍼
func set_card_alpha(alpha: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.material_override:
			var mat = child.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = clampf(alpha, 0.0, 1.0)
