extends Control

const GAME_VERSION_2D := "0.1.01-2D"

const VIEW_COUNTER := 0
const VIEW_KITCHEN := 1
const VIEW_COUNT := 2

const TRANSITION_TIME := 0.25
const EDGE_MARGIN := 48.0

const BURGER_RECIPE := ["bun_bottom", "cooked_patty", "cheese", "lettuce", "tomato", "bun_top"]

const PALETTE := {
	"pink": Color("#E98FA9"),
	"pink_light": Color("#F4B6C7"),
	"cream": Color("#FFF0DA"),
	"cream_light": Color("#FFF7ED"),
	"wood": Color("#B87958"),
	"wood_light": Color("#D29A72"),
	"green": Color("#78B96A"),
	"green_light": Color("#A6D68E"),
	"dark": Color("#5A454B"),
	"blue": Color("#A9D8ED"),
}

const FOOD_PATHS := {
	"bun_bottom": "res://assets/2d/food/bun_bottom.svg",
	"bun_top": "res://assets/2d/food/bun_top.svg",
	"raw_patty": "res://assets/2d/food/raw_patty.svg",
	"cooked_patty": "res://assets/2d/food/cooked_patty.svg",
	"cheese": "res://assets/2d/food/cheese.svg",
	"lettuce": "res://assets/2d/food/lettuce.svg",
	"tomato": "res://assets/2d/food/tomato.svg",
	"burger": "res://assets/2d/food/burger.svg",
	"fries": "res://assets/2d/food/fries.svg",
	"soda": "res://assets/2d/food/drink.svg",
}

const CUSTOMER_PATHS := {
	"Мурка": "res://assets/2d/characters/customer_cat.svg",
	"Фунтик": "res://assets/2d/characters/customer_bunny.svg",
	"Зайка": "res://assets/2d/characters/customer_bunny.svg",
	"Лисёнок": "res://assets/2d/characters/customer_fox.svg",
}

const ITEM_NAMES := {
	"bun_bottom": "Нижняя булка",
	"bun_top": "Верхняя булка",
	"raw_patty": "Сырая котлета",
	"cooked_patty": "Котлета",
	"cheese": "Сыр",
	"lettuce": "Салат",
	"tomato": "Помидор",
	"burger": "Бургер",
	"fries": "Фри",
	"soda": "Напиток",
}

const ORDER_POOL := [
	["burger", "fries"],
	["burger", "soda"],
	["burger", "fries", "soda"],
	["fries", "soda"],
]

var current_view := VIEW_COUNTER
var _transitioning := false

var held_item := ""
var burger_stack: Array[String] = []
var tray: Array[String] = []
var current_order: Array[String] = []
var customer_name := "Фунтик"

var coins := 10
var hearts := 1
var day := 1
var served_today := 0
var target_today := 5

var grill_busy := false
var grill_timer := 0.0
var grill_has_patty := false
var grill_cooked := false

var fryer_busy := false
var fryer_timer := 0.0
var _fryer_basket_origin := Vector2.ZERO

var soda_busy := false
var soda_timer := 0.0

var _hovered_hotspot: Hotspot2D = null
var _hotspots: Array[Hotspot2D] = []
var _edge_turn_cooldown := 0.0

var _view_roots: Array[Control] = []
var _parallax_layers: Dictionary = {}

var _font: Font
var _font_bold: Font
var _font_semi: Font

@onready var world_layer: Control = $WorldLayer
@onready var character_layer: Control = $CharacterLayer
@onready var hands_layer: Control = $HandsLayer
@onready var interaction_layer: Control = $InteractionLayer
@onready var hud: Control = $HUD

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _day_label: Label
var _stats_label: Label
var _fps_label: Label
var _left_arrow: Button
var _right_arrow: Button

var _paw_left: Control
var _paw_right: Control
var _held_visual: Control
var _burger_stack_container: Control
var _tray_items: Control
var _customer_sprite: TextureRect
var _order_bubble: Control
var _customer_name_label: Label
var _grill_patty_visual: TextureRect
var _grill_progress: ProgressBar
var _fryer_progress: ProgressBar
var _soda_progress: ProgressBar
var _grill_steam: Control
var _fryer_basket: TextureRect
var _soda_cup: TextureRect
var _ingredient_visuals: Dictionary = {}


func _ready() -> void:
	_load_fonts()
	_build_views()
	_build_hands()
	_build_hud()
	_build_edge_arrows()
	_build_prompt()
	_spawn_customer()
	_refresh_hotspot_visibility()
	_refresh_character_visibility()
	_update_hud()
	_update_tray_visual()
	_update_burger_stack_visual()
	_update_held_visual()
	set_process(true)


func _load_fonts() -> void:
	_font = load("res://assets/fonts/Nunito-Regular-Cyrillic.ttf")
	_font_bold = load("res://assets/fonts/Nunito-Bold-Cyrillic.ttf")
	_font_semi = load("res://assets/fonts/Nunito-SemiBold-Cyrillic.ttf")


func _process(delta: float) -> void:
	_process_cooking(delta)
	_process_edge_turn(delta)
	_process_steam(delta)
	_update_fps_label()
	_update_parallax()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		_turn_view(-1)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		_turn_view(1)


func _build_views() -> void:
	_view_roots.clear()
	_view_roots.append(_create_counter_view())
	_view_roots.append(_create_kitchen_view())
	for i in _view_roots.size():
		var view := _view_roots[i]
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.modulate.a = 1.0 if i == current_view else 0.0
		view.visible = i == current_view
		world_layer.add_child(view)


func _create_counter_view() -> Control:
	var root := Control.new()
	root.name = "CounterView"

	var bg := _make_layer("bg", Vector2.ZERO)
	bg.add_child(_bg_sprite("res://assets/2d/backgrounds/counter_cafe.svg"))
	root.add_child(bg)
	_register_parallax(bg, 2.0)

	var mid := _make_layer("mid", Vector2.ZERO)
	var diner_specs := [
		{"path": "res://assets/2d/characters/customer_bunny.svg", "pos": Vector2(200, 300)},
		{"path": "res://assets/2d/characters/customer_cat.svg", "pos": Vector2(480, 310)},
		{"path": "res://assets/2d/characters/customer_fox.svg", "pos": Vector2(760, 305)},
	]
	for spec in diner_specs:
		var diner := _sprite(spec.path, spec.pos, 120.0)
		diner.modulate = Color(0.72, 0.72, 0.72, 0.55)
		mid.add_child(diner)
	root.add_child(mid)
	_register_parallax(mid, 4.0)

	var fg := _make_layer("fg", Vector2.ZERO)
	fg.add_child(_sprite("res://assets/2d/kitchen/register.svg", Vector2(8, 360), 300.0))
	var tray_base := _sprite("res://assets/2d/kitchen/tray.svg", Vector2(480, 520), 130.0)
	tray_base.name = "TrayBase"
	fg.add_child(tray_base)

	_tray_items = Control.new()
	_tray_items.position = Vector2(500, 540)
	fg.add_child(_tray_items)

	_customer_sprite = _sprite(CUSTOMER_PATHS["Фунтик"], Vector2(520, 120), 300.0)
	character_layer.add_child(_customer_sprite)

	var serve := Hotspot2D.new()
	serve.setup("serve", "Выдать заказ", "serve", "", Vector2(300, 110))
	serve.position = Vector2(490, 530)
	serve.clicked.connect(_on_hotspot_clicked)
	serve.hovered.connect(_on_hotspot_hovered)
	serve.unhovered.connect(_on_hotspot_unhovered)
	interaction_layer.add_child(serve)
	_hotspots.append(serve)

	root.add_child(fg)
	_register_parallax(fg, 7.0)
	return root


func _create_kitchen_view() -> Control:
	var root := Control.new()
	root.name = "KitchenView"

	var bg := _make_layer("bg", Vector2.ZERO)
	bg.add_child(_bg_sprite("res://assets/2d/backgrounds/kitchen_cafe.svg"))
	root.add_child(bg)
	_register_parallax(bg, 2.0)

	var mid := _make_layer("mid", Vector2.ZERO)
	mid.add_child(_sprite("res://assets/2d/kitchen/grill.svg", Vector2(450, 310), 190.0))
	mid.add_child(_sprite("res://assets/2d/kitchen/fryer.svg", Vector2(210, 310), 190.0))
	mid.add_child(_sprite("res://assets/2d/kitchen/soda_machine.svg", Vector2(960, 260), 230.0))
	mid.add_child(_sprite("res://assets/2d/kitchen/ketchup.svg", Vector2(990, 250), 70.0))
	mid.add_child(_sprite("res://assets/2d/kitchen/mustard.svg", Vector2(1040, 248), 70.0))
	root.add_child(mid)
	_register_parallax(mid, 4.0)

	var fg := _make_layer("fg", Vector2.ZERO)

	_burger_stack_container = Control.new()
	_burger_stack_container.position = Vector2(490, 300)
	var board := _sprite("res://assets/2d/kitchen/assembly_board.svg", Vector2.ZERO, 210.0)
	board.name = "Board"
	_burger_stack_container.add_child(board)
	fg.add_child(_burger_stack_container)

	_fryer_basket = _sprite("res://assets/2d/kitchen/fryer_basket.svg", Vector2(240, 280), 90.0)
	_fryer_basket_origin = _fryer_basket.position
	fg.add_child(_fryer_basket)

	_grill_patty_visual = _food_sprite("raw_patty", Vector2.ZERO, 70.0)
	_grill_patty_visual.position = Vector2(520, 390)
	_grill_patty_visual.visible = false
	fg.add_child(_grill_patty_visual)

	_grill_progress = _make_progress_bar(Vector2(500, 470))
	_grill_progress.visible = false
	fg.add_child(_grill_progress)

	_grill_steam = Control.new()
	_grill_steam.position = Vector2(510, 330)
	_grill_steam.add_child(_sprite("res://assets/2d/decor/steam_1.svg", Vector2(0, 0), 36.0))
	_grill_steam.add_child(_sprite("res://assets/2d/decor/steam_2.svg", Vector2(36, -8), 32.0))
	_grill_steam.add_child(_sprite("res://assets/2d/decor/steam_1.svg", Vector2(72, 4), 28.0))
	_grill_steam.visible = false
	fg.add_child(_grill_steam)

	_fryer_progress = _make_progress_bar(Vector2(240, 470))
	_fryer_progress.visible = false
	fg.add_child(_fryer_progress)

	_soda_cup = _food_sprite("soda", Vector2.ZERO, 55.0)
	_soda_cup.position = Vector2(1040, 420)
	_soda_cup.visible = false
	fg.add_child(_soda_cup)

	_soda_progress = _make_progress_bar(Vector2(1000, 490))
	_soda_progress.visible = false
	fg.add_child(_soda_progress)

	var bin_layout := {
		"bun_bottom": Vector2(195, 205),
		"cheese": Vector2(355, 205),
		"lettuce": Vector2(515, 205),
		"tomato": Vector2(675, 205),
		"bun_top": Vector2(835, 205),
		"raw_patty": Vector2(195, 395),
	}
	for item_id in bin_layout:
		var food_vis := _food_sprite(item_id, bin_layout[item_id], 58.0)
		fg.add_child(food_vis)
		_ingredient_visuals[item_id] = food_vis

		var spot := Hotspot2D.new()
		spot.setup(
			"bin_%s" % item_id,
			"Взять %s" % _item_name(item_id).to_lower(),
			"take",
			item_id,
			Vector2(90, 70),
			food_vis
		)
		spot.position = bin_layout[item_id] + Vector2(-8, -8)
		spot.clicked.connect(_on_hotspot_clicked)
		spot.hovered.connect(_on_hotspot_hovered)
		spot.unhovered.connect(_on_hotspot_unhovered)
		interaction_layer.add_child(spot)
		_hotspots.append(spot)

	var grill_vis := mid.get_child(0)
	var grill := Hotspot2D.new()
	grill.setup("grill", "Положить котлету", "grill", "", Vector2(200, 110), grill_vis)
	grill.position = Vector2(450, 330)
	grill.clicked.connect(_on_hotspot_clicked)
	grill.hovered.connect(_on_hotspot_hovered)
	grill.unhovered.connect(_on_hotspot_unhovered)
	interaction_layer.add_child(grill)
	_hotspots.append(grill)

	var assembly := Hotspot2D.new()
	assembly.setup("assembly", "Собрать бургер", "assembly", "", Vector2(260, 180), _burger_stack_container)
	assembly.position = Vector2(490, 300)
	assembly.clicked.connect(_on_hotspot_clicked)
	assembly.hovered.connect(_on_hotspot_hovered)
	assembly.unhovered.connect(_on_hotspot_unhovered)
	interaction_layer.add_child(assembly)
	_hotspots.append(assembly)

	var fryer_vis := mid.get_child(1)
	var fryer := Hotspot2D.new()
	fryer.setup("fryer", "Пожарить картошку", "fryer", "", Vector2(150, 130), fryer_vis)
	fryer.position = Vector2(220, 340)
	fryer.clicked.connect(_on_hotspot_clicked)
	fryer.hovered.connect(_on_hotspot_hovered)
	fryer.unhovered.connect(_on_hotspot_unhovered)
	interaction_layer.add_child(fryer)
	_hotspots.append(fryer)

	var soda_vis := mid.get_child(2)
	var soda := Hotspot2D.new()
	soda.setup("soda", "Налить напиток", "soda", "", Vector2(140, 180), soda_vis)
	soda.position = Vector2(980, 290)
	soda.clicked.connect(_on_hotspot_clicked)
	soda.hovered.connect(_on_hotspot_hovered)
	soda.unhovered.connect(_on_hotspot_unhovered)
	interaction_layer.add_child(soda)
	_hotspots.append(soda)

	root.add_child(fg)
	_register_parallax(fg, 7.0)
	return root


func _build_hands() -> void:
	_paw_left = _sprite("res://assets/2d/ui/paw_left.svg", Vector2(300, 610), 90.0)
	_paw_right = _sprite("res://assets/2d/ui/paw_right.svg", Vector2(880, 610), 90.0)
	hands_layer.add_child(_paw_left)
	hands_layer.add_child(_paw_right)

	_held_visual = Control.new()
	_held_visual.position = Vector2(590, 580)
	_held_visual.visible = false
	hands_layer.add_child(_held_visual)


func _build_hud() -> void:
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(24, 20)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_left)

	_day_label = _make_label("День 1   0/5", 14, true)
	top_left.add_child(_day_label)

	_stats_label = _make_label("10 монет   ♥ 1", 14, false)
	top_left.add_child(_stats_label)

	_fps_label = _make_label("75 FPS • v%s" % GAME_VERSION_2D, 11, false)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_top = 16
	_fps_label.offset_right = -16
	_fps_label.add_theme_color_override("font_color", Color("#171417", 0.65))
	hud.add_child(_fps_label)


func _build_edge_arrows() -> void:
	_left_arrow = _make_arrow_button("<")
	_left_arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_left_arrow.offset_left = 4
	_left_arrow.offset_top = -28
	_left_arrow.offset_right = 36
	_left_arrow.offset_bottom = 28
	_left_arrow.pressed.connect(func(): _turn_view(-1))
	hud.add_child(_left_arrow)

	_right_arrow = _make_arrow_button(">")
	_right_arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_right_arrow.offset_left = -36
	_right_arrow.offset_top = -28
	_right_arrow.offset_right = -4
	_right_arrow.offset_bottom = 28
	_right_arrow.pressed.connect(func(): _turn_view(1))
	hud.add_child(_right_arrow)


func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.visible = false
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_bottom = -90
	_prompt_panel.offset_top = -130
	_prompt_panel.offset_left = -160
	_prompt_panel.offset_right = 160

	var box := StyleBoxFlat.new()
	box.bg_color = Color("#FFF7ED", 0.82)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_prompt_panel.add_theme_stylebox_override("panel", box)

	_prompt_label = _make_label("", 15, false, true)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)
	hud.add_child(_prompt_panel)


func _turn_view(direction: int) -> void:
	if _transitioning:
		return
	var next := posmod(current_view + direction, VIEW_COUNT)
	if next == current_view:
		return
	_transition_to_view(next)


func _transition_to_view(next: int) -> void:
	_transitioning = true
	var old_view := _view_roots[current_view]
	var new_view := _view_roots[next]
	new_view.visible = true
	new_view.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_view, "modulate:a", 0.0, TRANSITION_TIME)
	tween.tween_property(new_view, "modulate:a", 1.0, TRANSITION_TIME)
	tween.finished.connect(func():
		old_view.visible = false
		current_view = next
		_transitioning = false
		_edge_turn_cooldown = 0.35
		_refresh_hotspot_visibility()
		_refresh_character_visibility()
		_clear_prompt()
	)


func _process_edge_turn(delta: float) -> void:
	if _transitioning:
		return
	_edge_turn_cooldown = maxf(0.0, _edge_turn_cooldown - delta)
	if _edge_turn_cooldown > 0.0:
		return
	var vp := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	if mouse.x <= EDGE_MARGIN:
		_edge_turn_cooldown = 0.45
		_turn_view(-1)
	elif mouse.x >= vp.x - EDGE_MARGIN:
		_edge_turn_cooldown = 0.45
		_turn_view(1)


func _refresh_character_visibility() -> void:
	var on_counter := current_view == VIEW_COUNTER
	if _customer_sprite:
		_customer_sprite.visible = on_counter
	if _order_bubble:
		_order_bubble.visible = on_counter


func _refresh_hotspot_visibility() -> void:
	for spot in _hotspots:
		var visible := false
		match spot.action_type:
			"serve":
				visible = current_view == VIEW_COUNTER
			"take", "grill", "assembly", "fryer", "soda":
				visible = current_view == VIEW_KITCHEN
		spot.visible = visible
		spot.enabled = visible


func _on_hotspot_hovered(spot: Hotspot2D) -> void:
	_hovered_hotspot = spot
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_show_prompt(_prompt_for(spot))


func _on_hotspot_unhovered(_spot: Hotspot2D) -> void:
	_hovered_hotspot = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_clear_prompt()


func _on_hotspot_clicked(spot: Hotspot2D) -> void:
	_paw_reach()
	_show_prompt(_prompt_for(spot))
	match spot.action_type:
		"take":
			_take_item(spot.item_id)
		"grill":
			_use_grill()
		"assembly":
			_use_assembly()
		"fryer":
			_start_fryer()
		"soda":
			_start_soda()
		"serve":
			_serve_customer()


func _prompt_for(spot: Hotspot2D) -> String:
	match spot.action_type:
		"take":
			if held_item != "":
				return "Сначала освободи лапки"
			return "Взять %s" % _item_name(spot.item_id).to_lower()
		"grill":
			if grill_busy and grill_cooked:
				return "Забрать котлету"
			if grill_busy:
				return "Жарится..."
			if held_item == "raw_patty":
				return "Положить котлету"
			return "Нужна сырая котлета"
		"assembly":
			if held_item == "":
				return "Добавить ингредиент"
			return "Положить %s" % _item_name(held_item).to_lower()
		"fryer":
			if fryer_busy:
				return "Жарится..."
			if "fries" in tray:
				return "Фри уже готовы"
			return "Пожарить картошку"
		"soda":
			if soda_busy:
				return "Наливается..."
			if "soda" in tray:
				return "Напиток уже готов"
			return "Налить напиток"
		"serve":
			return "Выдать заказ"
	return spot.display_name


func _take_item(item_id: String) -> void:
	if held_item != "":
		return
	held_item = item_id
	_update_held_visual()
	_update_hud()


func _use_grill() -> void:
	if grill_busy and grill_cooked:
		if held_item != "":
			return
		held_item = "cooked_patty"
		grill_busy = false
		grill_has_patty = false
		grill_cooked = false
		_grill_patty_visual.visible = false
		_grill_progress.visible = false
		_grill_steam.visible = false
		_update_held_visual()
		_update_hud()
		return
	if grill_busy:
		return
	if held_item != "raw_patty":
		return
	held_item = ""
	grill_busy = true
	grill_timer = 0.0
	grill_has_patty = true
	grill_cooked = false
	_grill_patty_visual.texture = load(FOOD_PATHS["raw_patty"])
	_grill_patty_visual.visible = true
	_grill_progress.visible = true
	_grill_progress.value = 0
	_grill_steam.visible = true
	_update_held_visual()
	_update_hud()


func _use_assembly() -> void:
	if held_item == "":
		return
	var expected: String = BURGER_RECIPE[burger_stack.size()] if burger_stack.size() < BURGER_RECIPE.size() else ""
	if held_item != expected:
		hearts = maxi(0, hearts - 1)
		held_item = ""
		burger_stack.clear()
		_update_burger_stack_visual()
		_update_held_visual()
		_update_hud()
		return
	burger_stack.append(held_item)
	held_item = ""
	_update_burger_stack_visual(true)
	_update_held_visual()
	if burger_stack.size() == BURGER_RECIPE.size():
		tray.append("burger")
		burger_stack.clear()
		_update_burger_stack_visual()
		_update_tray_visual()
	_update_hud()


func _start_fryer() -> void:
	if fryer_busy or "fries" in tray:
		return
	fryer_busy = true
	fryer_timer = 0.0
	_fryer_progress.visible = true
	_fryer_progress.value = 0
	var tween := create_tween()
	tween.tween_property(_fryer_basket, "position:y", _fryer_basket_origin.y + 28, 0.2)


func _start_soda() -> void:
	if soda_busy or "soda" in tray:
		return
	soda_busy = true
	soda_timer = 0.0
	_soda_progress.visible = true
	_soda_progress.value = 0
	_soda_cup.visible = true


func _process_cooking(delta: float) -> void:
	if grill_busy and not grill_cooked:
		grill_timer += delta
		_grill_progress.value = clampf(grill_timer / 2.5, 0.0, 1.0) * 100.0
		if grill_timer >= 2.5:
			grill_cooked = true
			_grill_patty_visual.texture = load(FOOD_PATHS["cooked_patty"])
	if fryer_busy:
		fryer_timer += delta
		_fryer_progress.value = clampf(fryer_timer / 2.0, 0.0, 1.0) * 100.0
		if fryer_timer >= 2.0:
			fryer_busy = false
			_fryer_progress.visible = false
			tray.append("fries")
			_update_tray_visual()
			var tween := create_tween()
			tween.tween_property(_fryer_basket, "position:y", _fryer_basket_origin.y, 0.2)
	if soda_busy:
		soda_timer += delta
		_soda_progress.value = clampf(soda_timer / 1.5, 0.0, 1.0) * 100.0
		if soda_timer >= 1.5:
			soda_busy = false
			_soda_progress.visible = false
			_soda_cup.visible = false
			tray.append("soda")
			_update_tray_visual()


func _process_steam(delta: float) -> void:
	if not _grill_steam or not _grill_steam.visible:
		return
	for i in _grill_steam.get_child_count():
		var puff := _grill_steam.get_child(i)
		puff.position.y -= delta * 18.0
		if puff.position.y < -30.0:
			puff.position.y = 0.0


func _serve_customer() -> void:
	var order_sorted := current_order.duplicate()
	order_sorted.sort()
	var tray_sorted := tray.duplicate()
	tray_sorted.sort()
	if order_sorted != tray_sorted:
		hearts = maxi(0, hearts - 1)
		_update_hud()
		return
	coins += 5 + current_order.size() * 2
	served_today += 1
	tray.clear()
	_update_tray_visual()
	_customer_happy_and_next()
	_update_hud()


func _spawn_customer() -> void:
	current_order.assign(ORDER_POOL.pick_random())
	customer_name = ["Фунтик", "Мурка", "Лисёнок", "Зайка"].pick_random()
	_update_customer_sprite()
	_update_order_bubble()
	if _customer_sprite:
		_customer_sprite.modulate.a = 1.0
		_customer_sprite.position.x = 520


func _update_customer_sprite() -> void:
	if _customer_sprite == null:
		return
	var path: String = CUSTOMER_PATHS.get(customer_name, CUSTOMER_PATHS["Фунтик"])
	_customer_sprite.texture = load(path)
	var tex_size := _customer_sprite.texture.get_size()
	var scale := 300.0 / tex_size.y
	_customer_sprite.custom_minimum_size = tex_size * scale
	_customer_sprite.size = _customer_sprite.custom_minimum_size


func _customer_happy_and_next() -> void:
	if _customer_sprite == null:
		_spawn_customer()
		return
	var base_y := _customer_sprite.position.y
	var tween := create_tween()
	tween.tween_property(_customer_sprite, "position:y", base_y - 20, 0.15)
	tween.tween_property(_customer_sprite, "position:y", base_y, 0.15)
	tween.tween_callback(func():
		var heart := _make_label("♥", 24, true)
		heart.modulate = Color("#E98FA9")
		heart.position = Vector2(640, 140)
		character_layer.add_child(heart)
		var fade := create_tween()
		fade.tween_property(_customer_sprite, "modulate:a", 0.0, 0.25)
		fade.tween_property(_customer_sprite, "position:x", 900, 0.25)
		fade.finished.connect(func():
			heart.queue_free()
			_spawn_customer()
			_customer_sprite.modulate.a = 0.0
			_customer_sprite.position.x = 380
			var slide := create_tween()
			slide.tween_property(_customer_sprite, "modulate:a", 1.0, 0.25)
			slide.tween_property(_customer_sprite, "position:x", 520, 0.25)
		)
	)


func _update_order_bubble() -> void:
	if _order_bubble:
		_order_bubble.queue_free()
	_order_bubble = Control.new()
	_order_bubble.position = Vector2(560, 60)

	var bubble_bg := _sprite("res://assets/2d/ui/speech_bubble.svg", Vector2.ZERO, 72.0)
	bubble_bg.modulate.a = 0.95
	_order_bubble.add_child(bubble_bg)

	var icons := HBoxContainer.new()
	icons.position = Vector2(18, 14)
	icons.add_theme_constant_override("separation", 6)
	for item in current_order:
		icons.add_child(_food_sprite(item, Vector2.ZERO, 34.0))
	_order_bubble.add_child(icons)

	_customer_name_label = _make_label(customer_name, 14, false, true)
	_customer_name_label.position = Vector2(10, -22)
	_order_bubble.add_child(_customer_name_label)

	character_layer.add_child(_order_bubble)


func _update_tray_visual() -> void:
	if _tray_items == null:
		return
	for child in _tray_items.get_children():
		child.queue_free()
	var x := 0.0
	for item in tray:
		var icon := _food_sprite(item, Vector2(x, 0), 52.0)
		_tray_items.add_child(icon)
		x += 58.0


func _update_burger_stack_visual(bounce := false) -> void:
	if _burger_stack_container == null:
		return
	for child in _burger_stack_container.get_children():
		if child.name != "Board":
			child.queue_free()
	var y := 88.0
	for i in burger_stack.size():
		var layer := _food_sprite(burger_stack[i], Vector2(90, y - i * 12), 52.0)
		layer.name = "Layer%d" % i
		_burger_stack_container.add_child(layer)
		if bounce:
			layer.scale = Vector2(0.6, 0.6)
			var tween := create_tween()
			tween.tween_property(layer, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _update_held_visual() -> void:
	for child in _held_visual.get_children():
		child.queue_free()
	if held_item == "":
		_held_visual.visible = false
		return
	_held_visual.visible = true
	_held_visual.add_child(_food_sprite(held_item, Vector2.ZERO, 52.0))


func _update_hud() -> void:
	_day_label.text = "День %d   %d/%d" % [day, served_today, target_today]
	_stats_label.text = "%d монет   ♥ %d" % [coins, hearts]
	_update_held_visual()


func _update_fps_label() -> void:
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS • v%s" % [int(fps), GAME_VERSION_2D]


func _show_prompt(text: String) -> void:
	if text == "":
		_clear_prompt()
		return
	_prompt_label.text = text
	_prompt_panel.visible = true


func _clear_prompt() -> void:
	if _hovered_hotspot:
		_show_prompt(_prompt_for(_hovered_hotspot))
	else:
		_prompt_panel.visible = false


func _paw_reach() -> void:
	for paw in [_paw_left, _paw_right]:
		var base_y: float = paw.position.y
		var tween := create_tween()
		tween.tween_property(paw, "position:y", base_y - 18, 0.08)
		tween.tween_property(paw, "position:y", base_y, 0.12)


func _register_parallax(node: Control, strength: float) -> void:
	_parallax_layers[node] = {"strength": strength, "origin": node.position}


func _update_parallax() -> void:
	var vp := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var offset := (mouse - vp * 0.5) / vp
	for node in _parallax_layers:
		var data: Dictionary = _parallax_layers[node]
		var strength: float = data["strength"]
		var origin: Vector2 = data["origin"]
		if is_instance_valid(node):
			node.position = origin + Vector2(offset.x * strength, offset.y * strength * 0.5)


func _item_name(item_id: String) -> String:
	return ITEM_NAMES.get(item_id, item_id)


func _make_layer(layer_name: String, pos: Vector2) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.position = pos
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


func _bg_sprite(path: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.custom_minimum_size = Vector2(1280, 720)
	node.size = Vector2(1280, 720)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _sprite(path: String, pos: Vector2, max_height: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node.texture:
		var tex_size: Vector2 = node.texture.get_size()
		var scale_factor := max_height / tex_size.y
		node.custom_minimum_size = tex_size * scale_factor
		node.size = node.custom_minimum_size
	node.position = pos
	return node


func _food_sprite(item_id: String, pos: Vector2, max_height: float) -> TextureRect:
	var path: String = FOOD_PATHS.get(item_id, FOOD_PATHS["burger"])
	return _sprite(path, pos, max_height)


func _make_progress_bar(pos: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size = Vector2(120, 14)
	bar.max_value = 100
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#FFF7ED", 0.5)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#E98FA9")
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_label(text: String, size: int, bold: bool, semi := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	var font := _font
	if bold:
		font = _font_bold
	elif semi:
		font = _font_semi
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", PALETTE.dark)
	return label


func _make_arrow_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.modulate = Color(1, 1, 1, 0.12)
	btn.mouse_entered.connect(func(): btn.modulate.a = 0.42)
	btn.mouse_exited.connect(func(): btn.modulate.a = 0.12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#FFF7ED", 0.28)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_font_size_override("font_size", 22)
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_color_override("font_color", PALETTE.dark)
	return btn
