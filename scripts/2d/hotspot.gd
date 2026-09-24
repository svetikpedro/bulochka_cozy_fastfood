class_name Hotspot2D
extends Control

signal hovered(hotspot: Hotspot2D)
signal unhovered(hotspot: Hotspot2D)
signal clicked(hotspot: Hotspot2D)

var hotspot_id := ""
var display_name := ""
var action_type := ""
var item_id := ""
var enabled := true

var _visual: Control
var _visual_origin := Vector2.ZERO
var _visual_scale := Vector2.ONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(
	id: String,
	label: String,
	type: String,
	item: String = "",
	size := Vector2(80, 60),
	visual: Control = null
) -> void:
	hotspot_id = id
	display_name = label
	action_type = type
	item_id = item
	custom_minimum_size = size
	self.size = size

	_visual = visual
	if _visual:
		_visual_origin = _visual.position
		_visual_scale = _visual.scale

func set_highlight(active: bool) -> void:
	if not _visual:
		return
	if active:
		_visual.scale = _visual_scale * 1.03
		_visual.position = _visual_origin + Vector2(0, -3)
	else:
		_visual.scale = _visual_scale
		_visual.position = _visual_origin

func _on_mouse_entered() -> void:
	if not enabled:
		return
	set_highlight(true)
	hovered.emit(self)

func _on_mouse_exited() -> void:
	set_highlight(false)
	unhovered.emit(self)

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()
