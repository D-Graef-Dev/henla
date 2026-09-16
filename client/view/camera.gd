extends Camera2D

const ZOOM_STEPS := [1, 2, 3]
# placeholders, tune by feel
const KEY_SPEED := 400.0
const PINCH_STEP := 1.4

var _zoom_index := 0
# unrounded position - rounding every event would swallow slow drags
var _target := Vector2.ZERO
# finger index -> last position
var _touches := {}
var _pinch_start := 0.0


func _ready() -> void:
	_target = position
	zoom = Vector2.ONE * float(ZOOM_STEPS[_zoom_index])
	_apply()


func _process(delta: float) -> void:
	# delta is fine here, this is view code, not core
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir != Vector2.ZERO:
		_target += dir * KEY_SPEED * delta / zoom.x
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	# touch also arrives as emulated left mouse, so left must stay unused here
	if motion.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
		_pan(motion.relative)


func _on_mouse_button(button: InputEventMouseButton) -> void:
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_to(_zoom_index + 1, button.position)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_to(_zoom_index - 1, button.position)


func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_touches[touch.index] = touch.position
	else:
		_touches.erase(touch.index)
	# new baseline whenever a second finger lands or a third one leaves
	if _touches.size() == 2:
		_pinch_start = _finger_distance()


func _on_drag(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return
	_touches[drag.index] = drag.position
	var count := _touches.size()
	if count > 2:
		return
	# each finger moves the midpoint by its share
	_pan(drag.relative / count)
	if count == 2:
		var dist := _finger_distance()
		# step-wise: zoom once per clear pinch, then start measuring again
		if dist > _pinch_start * PINCH_STEP:
			_zoom_to(_zoom_index + 1, _finger_center())
			_pinch_start = dist
		elif dist < _pinch_start / PINCH_STEP:
			_zoom_to(_zoom_index - 1, _finger_center())
			_pinch_start = dist


func _finger_distance() -> float:
	var p := _touches.values()
	var a: Vector2 = p[0]
	var b: Vector2 = p[1]
	return a.distance_to(b)


func _finger_center() -> Vector2:
	var p := _touches.values()
	var a: Vector2 = p[0]
	var b: Vector2 = p[1]
	return (a + b) / 2.0


func _pan(screen_delta: Vector2) -> void:
	_target -= screen_delta / zoom.x
	_apply()


func _zoom_to(index: int, anchor: Vector2) -> void:
	index = clampi(index, 0, ZOOM_STEPS.size() - 1)
	if index == _zoom_index:
		return
	# keep the world point under the anchor where it is
	var half := get_viewport_rect().size / 2.0
	var world := _target + (anchor - half) / zoom.x
	_zoom_index = index
	zoom = Vector2.ONE * float(ZOOM_STEPS[index])
	_target = world - (anchor - half) / zoom.x
	_apply()


func _apply() -> void:
	position = _target.round()
