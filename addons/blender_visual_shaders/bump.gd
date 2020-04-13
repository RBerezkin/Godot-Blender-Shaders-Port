tool
extends VisualShaderNodeCustom
class_name VisualShaderNodeBlenderBump


func _init():
	set_default_input_values([
		0, false,
		1, 1.0,
		2, 1.0,
		3, 1.0,
		4, Vector3.ZERO
	])


func _get_name():
	return "BlenderBump"


func _get_category():
	return "BlenderNodes"


func _get_subcategory():
	return "Vertex"


func _get_description():
	return "Port of Blender Bump Node"


func _get_return_icon_type():
	return VisualShaderNode.PORT_TYPE_VECTOR


func _get_input_port_count():
	return 5


func _get_input_port_name(port):
	match port:
		0:
			return "Invert"
		1:
			return "Strength"
		2:
			return "Distance"
		3:
			return "Height"
		4:
			return "Normal"


func _get_input_port_type(port):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_BOOLEAN
		1:
			return VisualShaderNode.PORT_TYPE_SCALAR
		2:
			return VisualShaderNode.PORT_TYPE_SCALAR
		3:
			return VisualShaderNode.PORT_TYPE_SCALAR
		4:
			return VisualShaderNode.PORT_TYPE_VECTOR


func _get_output_port_count():
	return 1


func _get_output_port_name(port):
	match port:
		0:
			return "Normal"


func _get_output_port_type(port):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_VECTOR


func _get_global_code(mode):
	return """
		void node_bump (
			float strength,
			float dist,
			float height,
			vec3 normal,
			vec3 surf_pos,
			float invert,
			mat4 ViewMatrix,
			mat4 ViewMatrixInverse,
			out vec3 out_normal
		) {
			normal = mat3(ViewMatrix) * normalize(normal);
			
			if (invert != 0.0) {
				dist *= -1.0;
			}
			
			vec3 dPdx = dFdx(surf_pos);
			vec3 dPdy = dFdy(surf_pos);
			
			/* Get surface tangents from normal. */
			vec3 Rx = cross(dPdy, normal);
			vec3 Ry = cross(normal, dPdx);
			
			/* Compute surface gradient and determinant. */
			float det = dot(dPdx, Rx);
			float absdet = abs(det);
			
			float dHdx = dFdx(height);
			float dHdy = dFdy(height);
			vec3 surfgrad = dHdx * Rx + dHdy * Ry;
			
			strength = max(strength, 0.0);
			
			out_normal = normalize(absdet * normal - dist * sign(det) * surfgrad);
			out_normal = normalize(mix(normal, out_normal, strength));
			
			out_normal = mat3(ViewMatrixInverse) * out_normal;
		}
	"""


func _get_code(input_vars, output_vars, mode, type):
	return """
		vec3 outResult;
		
		bool param_invert = %s;
		float parm_strength = %s;
		float parm_distance = %s;
		float parm_height = %s;
		vec3 parm_normal = %s;
		
		node_bump(
			parm_strength,
			parm_distance,
			parm_height,
			parm_normal,
			VERTEX,
			param_invert ? 1.0 : 0.0,
			INV_CAMERA_MATRIX,
			CAMERA_MATRIX,
			outResult
		);
		
		%s = outResult;
	""" % [
		input_vars[0],
		input_vars[1],
		input_vars[2],
		input_vars[3],
		input_vars[4],
		
		output_vars[0]
	]
