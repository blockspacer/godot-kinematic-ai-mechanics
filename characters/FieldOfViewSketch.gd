extends Spatial

var local_forward:Vector3 = Vector3()
var global_forward:Vector3 = Vector3()

var line_collection:Array = []

var target_character:Node
const ROTATION_SPEED = .3
#const ROTATION_DELAY_PERIOD = .1 # If other characters are super fast and this one can't catch up.
var rotation_delayed = 0
var done_rotating:bool
var accum_rotation = 0.0

var positionsOfInterest = {
	'lastSeenPosition': false, # Position of player last seen
	'lastLostPosition': false, # Position of enemy when player lost
	'outsideRange': false
	}

func _ready():
	# FORWARD transform.basis.z
	line_collection = [
		{'color': Color(1,0,0,1), 'end' : transform.origin + Vector3(3,0,5), 'start' : transform.origin },
		{'color': Color(1,1,0,1), 'end' : (global_transform.origin + Vector3(0,0,5) ) , 'start' : global_transform.origin }
	]
	
	for i in range(0, line_collection.size()):
		draw_line(line_collection[i].start, line_collection[i].end, line_collection[i].color)

	$RayCast.exclude_parent = true
	$RayCast.add_exception(self)
	for child in get_parent().get_children():
		print(get_parent().name, ' - > ' , child.name)
		$RayCast.add_exception(child)
		
	print('PARENT: ', get_parent())




func _physics_process(delta):
	var parent = get_parent().transform

	if bodies_in_awareness.empty():
		return


	#if target_character:
	#
	#	# I lost sight of the character, but I can still hear them! Panic and quickly turn around
	#	# to some random direction to see if they are there.
	#	# If body is too far, (Least audible distance, then just be on alert)

	#	var pa = (target_character.transform.origin - parent.origin).normalized()
	#	if pa.dot(parent.basis.z) < 0:
	#		target_character
	#
	#	print(pa.dot(parent.basis.z))

	if not target_character:
		target_character = find_nearest_character(parent)


	if target_character:
		# ROTATION IS BACKWARDS -Z IN GODOT....
		var inverted_character_position = Vector3(-target_character.transform.origin.x, parent.origin.y, -target_character.transform.origin.z)
		var target_rotation = false
		var currentRotation = false
		var characterInSight = false
		
		$RayCast.look_at(inverted_character_position, Vector3(0,1,0))
		$RayCast.force_raycast_update()
		if $RayCast.is_colliding():
			var body = $RayCast.get_collider()
			if body.is_in_group('Character'):
				
				if character_in_view(target_character.transform.origin, parent.origin, parent.basis.z):
					target_rotation = parent.looking_at(inverted_character_position, Vector3(0,1,0))
					currentRotation = Quat(parent.basis).slerp(target_rotation.basis, delta * ROTATION_SPEED)
					positionsOfInterest.lastSeenPosition = inverted_character_position
					pursue_character(currentRotation, parent.origin)
					look_around_rotation = false
					characterInSight = true
					#print('Character is in view')
				elif not looked_around_for_character:
					# Look around wildly for character, maybe he is behind you!
					looked_around_for_character = look_around_for_character(delta, parent, PI)
						
					pass
				
				pass
			else:
				# Character is behind something.
				positionsOfInterest.lastLostPosition = positionsOfInterest.lastSeenPosition
				
				target_rotation = parent.looking_at(positionsOfInterest.lastLostPosition, Vector3(0,1,0))
				currentRotation = Quat(parent.basis).slerp(target_rotation.basis, delta * ROTATION_SPEED)
				pursue_character(currentRotation, parent.origin)
				
				#print('Character Last Seen: ', positionsOfInterest.lastLostPosition)
				
			# WHERE WAS THE TARGET LAST SEEN???!?! GO THERE.
			# If lost body....then target_character == ?!
			# Depending on agression, hunt character or just find the other target.
			#print(body.name)
		#else:
		#	print('nocolission..')
			#if body.has_method("bullet_hit"):
				#body.bullet_hit(TURRET_DAMAGE_RAYCAST, $RayCast.get_collision_point())
		
		if characterInSight == false:
			if character_is_audible():
				# Pay Attention, he's around here somewhere...
				pass

func find_nearest_character(parent:Transform):
	var shortest_body = null
	var shortest_distance = false
	for i in range(0, bodies_in_awareness.size()):

		# Who is in our field of vision?
		if not character_in_view(bodies_in_awareness[i].transform.origin, parent.origin, parent.basis.z):
			continue

		# Which body is closer?
		var distance = parent.origin.distance_to(bodies_in_awareness[i].transform.origin)

		if not shortest_body:
			shortest_body = bodies_in_awareness[i]

		if parent.origin.distance_to(bodies_in_awareness[i].transform.origin) < parent.origin.distance_to(shortest_body.transform.origin):
			shortest_distance = distance
			shortest_body = bodies_in_awareness[i]

	return shortest_body

func character_in_view(characterPosition:Vector3, currentPosition:Vector3, forwardVector:Vector3):
	var pa = (characterPosition - currentPosition).normalized()
	#print(pa.dot(forwardVector))
	if pa.dot(forwardVector) > 0:
		return true
		
	return false

# Footsteps
func character_is_audible():
	pass

func pursue_character(currentRotation:Quat, currentPosition:Vector3):
	get_parent().set_transform( Transform(currentRotation, currentPosition).orthonormalized() )
	pass
	

const QUAT_EQUIVALENCE_DEADZONE:float = .15

func quat_roughly_equal_to(quat1:Quat, quat2:Quat):
	
	if quat1.y - QUAT_EQUIVALENCE_DEADZONE < quat2.y and\
		quat1.y + QUAT_EQUIVALENCE_DEADZONE > quat2.y and\
		quat1.w - QUAT_EQUIVALENCE_DEADZONE < quat2.w and\
		quat1.w + QUAT_EQUIVALENCE_DEADZONE > quat2.w:
		return true
		
	return false

var looked_around_for_character = false
var look_around_rotation = false
func look_around_for_character(delta:float, parent:Transform, targetAngle:float=PI):
	if not look_around_rotation:
		look_around_rotation = parent.rotated(Vector3(0,1,0), targetAngle)
		
	if quat_roughly_equal_to(get_parent().transform.basis.get_rotation_quat(), look_around_rotation.basis.get_rotation_quat()):
		print('Quat match')
		return true
		
	var targetRotation = Quat(parent.basis).slerp(look_around_rotation.basis, delta * ROTATION_SPEED)
	pursue_character(targetRotation, parent.origin)
	
var bodies_in_awareness = []
func _entered_field_of_awareness(body:Node):

	if body.is_in_group('Character'):
		bodies_in_awareness.append(body)
		print(body)

	pass # Replace with function body.

func _exited_field_of_awareness(body):

	if target_character == body:
		target_character = null

	var index = bodies_in_awareness.find(body)
	if index != -1:
		bodies_in_awareness.remove(index)
	print(body, ' => ', index)
	pass # Replace with function body.



var go_reverse = false
func back_forth_rotate(delta):

	var parent = get_parent().transform
	var look_to # Normalized Vector, just gives us a direction.
	var incrementer = delta * ROTATION_SPEED

	if go_reverse:
		look_to = Vector3(1,0,0)
	else:
		look_to = Vector3(-1,0,0)

	var edge = parent.looking_at(parent.origin + look_to, Vector3(0,1,0))
	var rotated = Quat(parent.basis.orthonormalized()).slerp(edge.basis, clamp(accum_rotation, 0, 1))
	#var something= parent.origin.cross(parent.origin+look_to)
	#var something2 = Vector2(parent.origin.x, parent.origin.z).dot(Vector2(1,0))

	get_parent().transform.basis = Transform(rotated, parent.origin).basis

	accum_rotation += incrementer
	if accum_rotation >= 1:
		accum_rotation = 0
		go_reverse = !go_reverse




func draw_line(start, end, color):

	var _m = SpatialMaterial.new()
	_m.albedo_color = color
	_m.flags_unshaded = true
	_m.flags_use_point_size = true

	var draw_path_node = ImmediateGeometry.new()

	draw_path_node.set_material_override(_m)
	draw_path_node.clear()
	#draw_path_node.begin(Mesh.PRIMITIVE_POINTS, null)

	#draw_path_node.add_vertex(Vector3(navigation_path[0].x, navigation_path[0].y, navigation_path[0].z ) )
	#draw_path_node.add_vertex(Vector3(navigation_path[navigation_path.size()-1].x, navigation_path[navigation_path.size()-1].y, navigation_path[navigation_path.size()-1].z ) )
	#draw_path_node.end()

	draw_path_node.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	draw_path_node.add_vertex(start )
	draw_path_node.add_vertex(end )
	draw_path_node.end()

	add_child(draw_path_node)

