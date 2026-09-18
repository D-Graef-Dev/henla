extends Node
## Fills the window with whole-number pixel scaling.
##
## Godot's integer mode keeps the base height of 360 and leaves wide black
## bars when the window isn't a multiple of it. So we pick the scale and the
## viewport size ourselves and hand Godot a size that fits the window.

var _base := Vector2i(
	ProjectSettings.get_setting("display/window/size/viewport_width"),
	ProjectSettings.get_setting("display/window/size/viewport_height"))
var _last_window_size := Vector2i.ZERO


# Checked every frame on purpose: size_changed only fires when the viewport
# size changes, so some window changes (fullscreen, maximize) slip through.
func _process(_delta: float) -> void:
	var window := get_window()
	if window.size == _last_window_size:
		return
	_last_window_size = window.size

	var fit := window.size / _base
	var pixel_scale := maxi(1, mini(fit.x, fit.y))
	# Even sizes keep the screen centre on a whole pixel. On odd sizes it sits
	# on a pixel edge, and some GPUs then draw single pixels cut in half.
	window.content_scale_size = window.size / pixel_scale / 2 * 2
	print("window ", window.size, " -> view ", window.content_scale_size)
