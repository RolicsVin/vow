extends ColorRect


func _ready() -> void:
	show()
	var mat: ShaderMaterial = material
	
	if 'brightness' in GodoTools._get_buffer():
		mat.set_shader_parameter('brightness', GodoTools._get_buffer()['brightness'])
	else:
		GodoTools._get_buffer()['brightness'] = mat.get_shader_parameter('brightness')
	
	if 'contrast' in GodoTools._get_buffer():
		mat.set_shader_parameter('contrast', GodoTools._get_buffer()['contrast'])
	else:
		GodoTools._get_buffer()['contrast'] = mat.get_shader_parameter('contrast')
	
	if 'saturation' in GodoTools._get_buffer():
		mat.set_shader_parameter('saturation', GodoTools._get_buffer()['saturation'])
	else:
		GodoTools._get_buffer()['saturation'] = mat.get_shader_parameter('saturation')
	
	if 'noise_intensity' in GodoTools._get_buffer():
		mat.set_shader_parameter('noise_intensity', GodoTools._get_buffer()['noise_intensity'])
	else:
		GodoTools._get_buffer()['noise_intensity'] = mat.get_shader_parameter('noise_intensity')
