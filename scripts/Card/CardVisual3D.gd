class_name CardVisual3D
extends Area3D

var data: CardData
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

# 애니메이션 및 위치 제어용 변수
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var target_scale: Vector3 = Vector3.ONE
var is_hovered: bool = false
var is_dragging: bool = false
var is_drawing: bool = false # 드로우 애니메이션 진행 여부
var is_ready_to_play: bool = false # 사용 영역 진입 및 발동 준비 완료 상태

var highlight_mesh_instance: MeshInstance3D

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
	
	# 1-3. 3D 테두리 하이라이트 메쉬 생성 (사용 영역 진입 시 노출)
	highlight_mesh_instance = MeshInstance3D.new()
	var hl_quad = QuadMesh.new()
	hl_quad.size = Vector2(1.24, 1.76) # 부드러운 빛 번짐(Glow) 공간 확보를 위한 판
	highlight_mesh_instance.mesh = hl_quad
	
	# 부드럽게 빛나는 황금빛 마법 아우라 3D 쉐이더 (SDF 라운디드 박스 둥근 모서리 연동)
	var hl_shader = Shader.new()
	hl_shader.code = """
	shader_type spatial;
	render_mode unshaded, cull_disabled, depth_draw_never;

	uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.25, 0.95);

	float sd_round_box(vec2 p, vec2 b, float r) {
		vec2 d = abs(p) - b + vec2(r);
		return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
	}

	void fragment() {
		vec2 p = UV - vec2(0.5);
		
		// 카드 형태에 맞춘 라운디드 박스 크기 및 동글동글한 모서리 반경(0.07)
		vec2 box_size = vec2(0.39, 0.42);
		float corner_radius = 0.07;
		
		float dist = sd_round_box(p, box_size, corner_radius);
		
		// 카드 뒤쪽은 투명, 둥근 테두리 부근에서 1.0, 외곽으로 부드럽게 투명 소멸
		float alpha_in = smoothstep(-0.06, -0.01, dist);
		float alpha_out = 1.0 - smoothstep(-0.01, 0.07, dist);
		float mask = alpha_in * alpha_out;
		
		// 은은하게 일렁이는 글로우 펄스
		float pulse = 0.88 + 0.12 * sin(TIME * 6.0);
		
		ALBEDO = glow_color.rgb;
		ALPHA = mask * glow_color.a * pulse;
	}
	"""
	
	var hl_mat = ShaderMaterial.new()
	hl_mat.shader = hl_shader
	
	highlight_mesh_instance.material_override = hl_mat
	highlight_mesh_instance.position = Vector3(0, 0, -0.002) # 카드 뒷면보다 뒤쪽에 배치
	highlight_mesh_instance.visible = false
	add_child(highlight_mesh_instance)
	
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
		
	# 1. 위치 보간
	global_position = global_position.lerp(target_position, 12.0 * delta)
	
	# 2. 회전 보간 (lerp_angle로 오일러 각도를 안전하게 보간하여 NaN 행렬 붕괴 방지)
	global_rotation.x = lerp_angle(global_rotation.x, target_rotation.x, 12.0 * delta)
	global_rotation.y = lerp_angle(global_rotation.y, target_rotation.y, 12.0 * delta)
	global_rotation.z = lerp_angle(global_rotation.z, target_rotation.z, 12.0 * delta)
	
	# 3. 크기 보간 (Node3D scale 독립 보간)
	scale = scale.lerp(target_scale, 12.0 * delta)

# 카드 사용 영역 진입 시 테두리 하이라이트 표시 헬퍼
func set_ready_to_play_highlight(enabled: bool) -> void:
	if is_ready_to_play == enabled:
		return
	is_ready_to_play = enabled
	if highlight_mesh_instance:
		highlight_mesh_instance.visible = enabled

# 카드 앞/뒷면 메쉬의 알파(투명도) 일괄 조정 헬퍼
func set_card_alpha(alpha: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.material_override:
			var mat = child.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = clampf(alpha, 0.0, 1.0)

# 카드 3D 메쉬의 렌더링 우선순위(sorting_offset) 일괄 조정 헬퍼
func set_sorting_offset(offset: float) -> void:
	for child in get_children():
		if child is VisualInstance3D:
			child.sorting_offset = offset
