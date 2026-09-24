extends StaticBody3D

var station_type = ""
var display_name = ""
var item_id = ""

func interact() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.use_station(station_type, display_name, item_id)
