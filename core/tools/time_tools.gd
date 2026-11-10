class_name TimeTools extends Node


func get_date() -> String:
	var date = Time.get_datetime_dict_from_system()
	return "%02d.%02d.%04d" % [date.day, date.month, date.year]


func get_time() -> String:
	var time = Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
