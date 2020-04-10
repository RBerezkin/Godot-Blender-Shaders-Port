tool
extends VisualShaderNodeCustom
class_name VisualShaderNodeBlenderTexVoronoi


func _init():
	set_default_input_values([
		1, 0.0,
		2, 0.0,
		3, 5.0,
		4, 1.0,
		5, 0.5,
		6, 1.0
	])


func _get_name():
	return "BlenderTexVoronoi"


func _get_category():
	return "BlenderNodes"


func _get_description():
	return "Port of Blender Voronoi Texture Node"


func _get_return_icon_type():
	return VisualShaderNode.PORT_TYPE_SAMPLER


func _get_input_port_count():
	return 7


func _get_input_port_name(port):
	match port:
		0:
			return "Vector"
		1:
			return "Feature output"
		2:
			return "Distance metric"
		3:
			return "Scale"
		4:
			return "Smoothness"
		5:
			return "Exponent"
		6:
			return "Randomness"


func _get_input_port_type(port):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_VECTOR
		1:
			return VisualShaderNode.PORT_TYPE_SCALAR
		2:
			return VisualShaderNode.PORT_TYPE_SCALAR
		3:
			return VisualShaderNode.PORT_TYPE_SCALAR
		4:
			return VisualShaderNode.PORT_TYPE_SCALAR
		5:
			return VisualShaderNode.PORT_TYPE_SCALAR


func _get_output_port_count():
	return 4


func _get_output_port_name(port):
	match port:
		0:
			return "Distance"
		1:
			return "Color"
		2:
			return "Position"
		3:
			return "Radius"


func _get_output_port_type(port):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_SCALAR
		1:
			return VisualShaderNode.PORT_TYPE_VECTOR
		2:
			return VisualShaderNode.PORT_TYPE_VECTOR
		3:
			return VisualShaderNode.PORT_TYPE_SCALAR


func _get_global_code(mode):
	return """
		// Utils
		// =====================================================================
		vec3 hash33(vec3 p3) {
			p3 = fract(p3 * vec3(.1031, .1030, .0973));
			p3 += dot(p3, p3.yxz + 33.33);
			return fract((p3.xxy + p3.yxx) * p3.zyx);
		}
		
		
		vec3 safe_divide(vec3 a, float b) {
			return (b != 0.0) ? a / b : vec3(0.0);
		}
		// =====================================================================
		
		
		float voronoi_distance(vec3 a, vec3 b, float metric, float exponent) {
			if (metric == 0.0) {
				// EUCLIDEAN
				return distance(a, b);
			} else if (metric == 1.0) {
				//MANHATTAN
				return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z);
			} else if (metric == 2.0) {
				// CHEBYCHEV
				return max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z)));
			} else if (metric == 3.0) {
				// MINKOWSKI
				return pow(pow(abs(a.x - b.x), exponent) + pow(abs(a.y - b.y), exponent) + pow(abs(a.z - b.z), exponent), 1.0 / exponent);
			} else {
				return 0.0;
			}
		}
		
		
		// F1
		void node_tex_voronoi_f1_3d (
			vec3 param_coord,
			float param_scale,
			float param_smoothness,
			float param_exponent,
			float param_randomness,
			float param_metric,
			out float outDistance,
			out vec3 outColor,
			out vec3 outPosition,
			out float outRadius
		) {
			param_randomness = clamp(param_randomness, 0.0, 1.0);
			
			vec3 scaledCoord = param_coord * param_scale;
			vec3 cellPosition = floor(scaledCoord);
			vec3 localPosition = scaledCoord - cellPosition;
			
			float minDistance = 8.0;
			vec3 targetOffset, targetPosition;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 pointPosition = cellOffset + hash33(cellPosition + cellOffset) * param_randomness;
						float distanceToPoint = voronoi_distance(pointPosition, localPosition, param_metric, param_exponent);
						
						if (distanceToPoint < minDistance) {
							targetOffset = cellOffset;
							minDistance = distanceToPoint;
							targetPosition = pointPosition;
						}
					}
				}
			}
			
			outDistance = minDistance;
			outColor.xyz = hash33(cellPosition + targetOffset);
			outPosition = safe_divide(targetPosition + cellPosition, param_scale);
		}
		
		
		// F2
		void node_tex_voronoi_f2_3d (
			vec3 param_coord,
			float param_scale,
			float param_smoothness,
			float param_exponent,
			float param_randomness,
			float param_metric,
			out float outDistance,
			out vec3 outColor,
			out vec3 outPosition,
			out float outRadius
		) {
			param_randomness = clamp(param_randomness, 0.0, 1.0);
			
			vec3 scaledCoord = param_coord * param_scale;
			vec3 cellPosition = floor(scaledCoord);
			vec3 localPosition = scaledCoord - cellPosition;
			
			float distanceF1 = 8.0;
			float distanceF2 = 8.0;
			
			vec3 offsetF1 = vec3(0.0);
			vec3 positionF1 = vec3(0.0);
			vec3 offsetF2, positionF2;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 pointPosition = cellOffset + hash33(cellPosition + cellOffset) * param_randomness;
						float distanceToPoint = voronoi_distance(pointPosition, localPosition, param_metric, param_exponent);
						
						if (distanceToPoint < distanceF1) {
							distanceF2 = distanceF1;
							distanceF1 = distanceToPoint;
							
							offsetF2 = offsetF1;
							offsetF1 = cellOffset;
							
							positionF2 = positionF1;
							positionF1 = pointPosition;
						} else if (distanceToPoint < distanceF2) {
							distanceF2 = distanceToPoint;
							offsetF2 = cellOffset;
							positionF2 = pointPosition;
						}
					}
				}
			}
			
			outDistance = distanceF2;
			outColor.xyz = hash33(cellPosition + offsetF2);
			outPosition = safe_divide(positionF2 + cellPosition, param_scale);
		}
		
		
		// Smooth F1
		void node_tex_voronoi_smooth_f1_3d (
			vec3 param_coord,
			float param_scale,
			float param_smoothness,
			float param_exponent,
			float param_randomness,
			float param_metric,
			out float outDistance,
			out vec3 outColor,
			out vec3 outPosition,
			out float outRadius
		) {
			param_randomness = clamp(param_randomness, 0.0, 1.0);
			param_smoothness = clamp(param_smoothness / 2.0, 0, 0.5);
			
			vec3 scaledCoord = param_coord * param_scale;
			vec3 cellPosition = floor(scaledCoord);
			vec3 localPosition = scaledCoord - cellPosition;
			
			float smoothDistance = 8.0;
			vec3 smoothColor = vec3(0.0);
			vec3 smoothPosition = vec3(0.0);
			
			for (float k = -2.0; k <= 2.0; k += 1.0) {
				for (float j = -2.0; j <= 2.0; j += 1.0) {
					for (float i = -2.0; i <= 2.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 pointPosition = cellOffset + hash33(cellPosition + cellOffset) * param_randomness;
						
						float distanceToPoint = voronoi_distance(pointPosition, localPosition, param_metric, param_exponent);
						float h = smoothstep(0.0, 1.0, 0.5 + 0.5 * (smoothDistance - distanceToPoint) / param_smoothness);
						float correctionFactor = param_smoothness * h * (1.0 - h);
						
						smoothDistance = mix(smoothDistance, distanceToPoint, h) - correctionFactor;
						correctionFactor /= 1.0 + 3.0 * param_smoothness;
						
						vec3 cellColor = hash33(cellPosition + cellOffset);
						smoothColor = mix(smoothColor, cellColor, h) - correctionFactor;
						smoothPosition = mix(smoothPosition, pointPosition, h) - correctionFactor;
					}
				}
			}
			
			outDistance = smoothDistance;
			outColor.xyz = smoothColor;
			outPosition = safe_divide(cellPosition + smoothPosition, param_scale);
		}
		
		
		// Distance to edge
		void node_tex_voronoi_distance_to_edge_3d (
			vec3 param_coord,
			float param_scale,
			float param_smoothness,
			float param_exponent,
			float param_randomness,
			float param_metric,
			out float outDistance,
			out vec3 outColor,
			out vec3 outPosition,
			out float outRadius
		) {
			param_randomness = clamp(param_randomness, 0.0, 1.0);
			
			vec3 scaledCoord = param_coord * param_scale;
			vec3 cellPosition = floor(scaledCoord);
			vec3 localPosition = scaledCoord - cellPosition;
			
			vec3 vectorToClosest;
			float minDistance = 8.0;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 vectorToPoint = cellOffset + hash33(cellPosition + cellOffset) * param_randomness - localPosition;
						float distanceToPoint = dot(vectorToPoint, vectorToPoint);
						
						if (distanceToPoint < minDistance) {
							minDistance = distanceToPoint;
							vectorToClosest = vectorToPoint;
						}
					}
				}
			}
			
			minDistance = 8.0;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 vectorToPoint = cellOffset + hash33(cellPosition + cellOffset) * param_randomness - localPosition;
						vec3 perpendicularToEdge = vectorToPoint - vectorToClosest;
						
						if (dot(perpendicularToEdge, perpendicularToEdge) > 0.0001) {
							float distanceToEdge = dot((vectorToClosest + vectorToPoint) / 2.0, normalize(perpendicularToEdge));
							minDistance = min(minDistance, distanceToEdge);
						}
					}
				}
			}
			
 			outDistance = minDistance;
		}
		
		
		// N-Sphere radius
		void node_tex_voronoi_n_sphere_radius_3d (
			vec3 param_coord,
			float param_scale,
			float param_smoothness,
			float param_exponent,
			float param_randomness,
			float param_metric,
			out float outDistance,
			out vec3 outColor,
			out vec3 outPosition,
			out float outRadius
		) {
			param_randomness = clamp(param_randomness, 0.0, 1.0);
			
			vec3 scaledCoord = param_coord * param_scale;
			vec3 cellPosition = floor(scaledCoord);
			vec3 localPosition = scaledCoord - cellPosition;
			
			vec3 closestPoint;
			vec3 closestPointOffset;
			float minDistance = 8.0;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						vec3 cellOffset = vec3(i, j, k);
						vec3 pointPosition = cellOffset + hash33(cellPosition + cellOffset) * param_randomness;
						float distanceToPoint = distance(pointPosition, localPosition);
						
						if (distanceToPoint < minDistance) {
							minDistance = distanceToPoint;
							closestPoint = pointPosition;
							closestPointOffset = cellOffset;
						}
					}
				}
			}
			
			minDistance = 8.0;
			vec3 closestPointToClosestPoint;
			
			for (float k = -1.0; k <= 1.0; k += 1.0) {
				for (float j = -1.0; j <= 1.0; j += 1.0) {
					for (float i = -1.0; i <= 1.0; i += 1.0) {
						if (i == 0.0 && j == 0.0 && k == 0.0) {
							continue;
						}
						
						vec3 cellOffset = vec3(i, j, k) + closestPointOffset;
						vec3 pointPosition = cellOffset + hash33(cellPosition + cellOffset) * param_randomness;
						float distanceToPoint = distance(closestPoint, pointPosition);
						
						if (distanceToPoint < minDistance) {
							minDistance = distanceToPoint;
							closestPointToClosestPoint = pointPosition;
						}
					}
				}
			}
			
			outRadius = distance(closestPointToClosestPoint, closestPoint) / 2.0;
		}
	"""


func _get_code(input_vars, output_vars, mode, type):
	return """
		float outRadius;
		float outDistance;
		
		vec3 outColor;
		vec3 outPosition;
		
		float param_feature = %s;
		
		vec3 param_coord = %s;
		float param_scale = %s;
		float param_smoothness = %s;
		float param_exponent = %s;
		float param_randomness = %s;
		float param_metric = %s;
		
		if (param_feature == 1.0) {
			node_tex_voronoi_f2_3d (
				param_coord,
				param_scale,
				param_smoothness,
				param_exponent,
				param_randomness,
				param_metric,
				
				outDistance,
				outColor,
				outPosition,
				outRadius
			);
		} else if (param_feature == 2.0) {
			node_tex_voronoi_smooth_f1_3d (
				param_coord,
				param_scale,
				param_smoothness,
				param_exponent,
				param_randomness,
				param_metric,
				
				outDistance,
				outColor,
				outPosition,
				outRadius
			);
		} else if (param_feature == 3.0) {
			node_tex_voronoi_distance_to_edge_3d (
				param_coord,
				param_scale,
				param_smoothness,
				param_exponent,
				param_randomness,
				param_metric,
				
				outDistance,
				outColor,
				outPosition,
				outRadius
			);
		} else if (param_feature == 4.0) {
			node_tex_voronoi_n_sphere_radius_3d (
				param_coord,
				param_scale,
				param_smoothness,
				param_exponent,
				param_randomness,
				param_metric,
				
				outDistance,
				outColor,
				outPosition,
				outRadius
			);
		} else {
			node_tex_voronoi_f1_3d (
				param_coord,
				param_scale,
				param_smoothness,
				param_exponent,
				param_randomness,
				param_metric,
				
				outDistance,
				outColor,
				outPosition,
				outRadius
			);
		}
		
		%s = outDistance;
		%s = outColor;
		%s = outPosition;
		%s = outRadius;
	""" % [
		input_vars[1],
		input_vars[0],
		input_vars[3],
		input_vars[4],
		input_vars[5],
		input_vars[6],
		input_vars[2],
		
		output_vars[0],
		output_vars[1],
		output_vars[2],
		output_vars[3]
	]
