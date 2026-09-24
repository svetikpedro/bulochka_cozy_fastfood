extends StaticBody3D

var station_type = ""
var display_name = ""
var item_id = ""

func interact() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.use_station(station_type, display_name, item_id)

func get_interaction_text() -> String:
	match station_type:
		"ingredient":
			return "Взять " + display_name.to_lower()
		"grill":
			return "Гриль"
		"assemble":
			return "Сборка бургера"
		"fries":
			return "Сделать картошку"
		"soda":
			return "Налить напиток"
		"serve":
			return "Выдать заказ"
		"trash":
			return "Выбросить"
		_:
			return display_name
