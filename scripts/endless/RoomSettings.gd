class_name RoomSettings
extends Resource

const LEVEL_SETTINGS_PATH = "res://resources/endless_settings.txt"
const LOOKUP_COLUMNS := ["start_level", "end_level"]

enum RoomTheme {
	Desert,
	Jungle,
	Castle,
	Snow,
	Cave
}

@export var theme: RoomTheme = RoomTheme.Desert

@export_group("Room")
@export var min_room_size: int = 5
@export var max_room_size: int = 20
@export var max_room_height: int = 10
@export var chamber_placement_attempts: int = 10

@export_group("Chambers")
@export var min_chamber_count: int = 2
@export var max_chamber_count: int = 4
@export var min_chamber_size: int = 3
@export var max_chamber_size: int = 7

@export_group("Exits")
@export var min_exit_count: int = 1
@export var max_exit_count: int = 3


func load_setting(level_id: int) -> RoomSettings:
	for row in load_csv(LEVEL_SETTINGS_PATH):
		if level_id >= int(row["start_level"]) and level_id <= int(row["end_level"]):
			return _build_from_row(row)

	push_warning("No settings found for level %d, using defaults" % level_id)
	return RoomSettings.new()


func _build_from_row(row: Dictionary) -> RoomSettings:
	var settings := RoomSettings.new()

	for column in row:
		if column in LOOKUP_COLUMNS:
			continue

		if not column in settings:
			push_warning("CSV column has no matching property: " + column)
			continue

		if column == "theme":
			var theme_name: String = row[column].capitalize()
			if RoomTheme.has(theme_name):
				settings.theme = RoomTheme[theme_name]
			else:
				push_warning("Unknown theme: " + theme_name)
		else:
			settings.set(column, int(row[column]))

	return settings


func load_csv(file_path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("Failed to open CSV: " + file_path)
		return rows

	var headers := PackedStringArray()

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue

		if headers.is_empty():
			for h in line:
				headers.append(h.strip_edges())
			continue

		var row := {}
		for i in range(min(headers.size(), line.size())):
			row[headers[i]] = line[i].strip_edges()
		rows.append(row)

	file.close()
	return rows
