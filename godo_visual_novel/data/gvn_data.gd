extends Node

var characters_color: Dictionary = {
	GvnEnums.characters.Нет: Color.WHITE,
	GvnEnums.characters.Вы: Color.WHITE,
	GvnEnums.characters.Ты: Color.WHITE,
	GvnEnums.characters.ГлавныйГерой: Color.WHITE,
	GvnEnums.characters.Алиса: Color.ORANGE,
	GvnEnums.characters.Катя: Color.BURLYWOOD,
	GvnEnums.characters.Валя: Color.DARK_SLATE_GRAY,
	GvnEnums.characters.Гальхя: Color.CHOCOLATE,
	GvnEnums.characters.Фейхья: Color.PEACH_PUFF,
	GvnEnums.characters.Калия: Color.WHITE,
	GvnEnums.characters.Лира: Color.ALICE_BLUE,
	GvnEnums.characters.Дорман: Color.ROSY_BROWN,
	GvnEnums.characters.Сигурд: Color.DARK_RED,
	GvnEnums.characters.ЗверьГнева: Color.RED,
	GvnEnums.characters.ЗверьСмерти: Color.BLACK,
}

var bookmarks_scenes: Dictionary = {}

var name_protection: Dictionary = {
	GvnEnums.characters.Нет: ''
}

var name_ru_protection: Dictionary = {
	GvnEnums.characters.ГлавныйГерой: 'Главный герой',
	GvnEnums.characters.Нет: ''
	}

var name_en_protection: Dictionary = {
	GvnEnums.characters.ГлавныйГерой: 'The main character',
	GvnEnums.characters.Нет: '',
	GvnEnums.characters.Вы: 'You',
	GvnEnums.characters.Ты: 'You',
	GvnEnums.characters.Алиса: 'Alisa',
	GvnEnums.characters.Катя: 'Katya',
	GvnEnums.characters.Валя: 'Valia',
	GvnEnums.characters.Гальхя: 'Galkhya',
	GvnEnums.characters.Фейхья: 'Feihya',
	GvnEnums.characters.Калия: 'Kalia',
	GvnEnums.characters.Лира: 'Lira',
	GvnEnums.characters.Дорман: 'Dorman',
	GvnEnums.characters.Фея: 'Feya',
	GvnEnums.characters.ЗверьГнева: 'The beast of wrath',
	GvnEnums.characters.ЗверьСмерти: 'The Beast of Death',
	GvnEnums.characters.Незнакомец: 'Stranger',
	GvnEnums.characters.Незнакомка: 'Stranger',
	GvnEnums.characters.Прохожий: 'Passerby',
	GvnEnums.characters.Мужчина: 'Man',
	GvnEnums.characters.Женщина: 'Woman',
	GvnEnums.characters.Девушка: 'Girl',
	GvnEnums.characters.Подросток: 'Teenager',
	GvnEnums.characters.Мальчик: 'Boy',
	GvnEnums.characters.Девочка: 'Girl',
	}
	
var emotion_protection: Dictionary = {
	GvnEnums.emotions.Без_эмоции: ''
}

var emotion_ru_protection: Dictionary = {
	GvnEnums.emotions.Без_эмоции: '',
	GvnEnums.emotions.В_мыслях: 'В мыслях',
	GvnEnums.emotions.Не_доверчиво: 'Не доверчиво',
}

var emotion_en_protection: Dictionary = {
	GvnEnums.emotions.Без_эмоции: '',
	GvnEnums.emotions.В_мыслях: 'In your mind',
	GvnEnums.emotions.Радостно: 'Joyfully',
	GvnEnums.emotions.Счастливо: 'Happily',
	GvnEnums.emotions.Смеясь: 'Laughing',
	GvnEnums.emotions.Веселясь: 'Having fun',
	GvnEnums.emotions.Хихикая: 'Laughing',
	GvnEnums.emotions.Грустно: 'Sadly',
	GvnEnums.emotions.Печально: 'Sadly',
	GvnEnums.emotions.Огорчённо: 'Disappointed',
	GvnEnums.emotions.Недовольно: 'Unsatisfied',
	GvnEnums.emotions.Истеря: 'Hysteria',
	GvnEnums.emotions.Плача: 'Crying',
	GvnEnums.emotions.Злясь: 'Angry',
	GvnEnums.emotions.Злостно: 'Maliciously',
	GvnEnums.emotions.Яростно: 'Violently',
	GvnEnums.emotions.Безумно: 'Madly',
	GvnEnums.emotions.Неистово: 'Violently',
	GvnEnums.emotions.Подозрительно: 'Suspiciously',
	GvnEnums.emotions.Раздосадованно: 'Annoyed',
	GvnEnums.emotions.Задумчиво: 'Thoughtfully',
	GvnEnums.emotions.Не_доверчиво: 'Not trusting',
	GvnEnums.emotions.Прищурившись: 'Taking a closer look',
	GvnEnums.emotions.Присмотревшись: 'Taking a closer look',
	GvnEnums.emotions.Страсно: 'Passionately',
	GvnEnums.emotions.Возбуждённо: 'Excited',
	GvnEnums.emotions.Влюблённо: 'Lovingly',
	GvnEnums.emotions.Стыдливо: 'Shamefully',
	GvnEnums.emotions.Смущённо: 'Embarrassed'
}

var character_emotion_protection: Dictionary = {
	GvnEnums.emotions.Без_эмоции: 'default',
	GvnEnums.emotions.Злясь: 'evil'
}
var video: bool = true

var text_speed: float = 0.03
var automatic_text_switching: bool = true
var automatic_text_switching_speed: float = 3.0
var current_language: GvnEnums.languages = GvnEnums.languages.En
