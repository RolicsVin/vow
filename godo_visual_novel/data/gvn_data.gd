extends Node

var characters_color: Dictionary = {
	Character.CharacterType.Нет: Color.WHITE,
	Character.CharacterType.Вы: Color.WHITE,
	Character.CharacterType.Ты: Color.WHITE,
	Character.CharacterType.ГлавныйГерой: Color.WHITE,
	Character.CharacterType.Алиса: Color.ORANGE,
	Character.CharacterType.Катя: Color.BURLYWOOD,
	Character.CharacterType.Валя: Color.DARK_SLATE_GRAY,
	Character.CharacterType.Гальхя: Color.CHOCOLATE,
	Character.CharacterType.Фейхья: Color.PEACH_PUFF,
	Character.CharacterType.Калия: Color.WHITE,
	Character.CharacterType.Лира: Color.ALICE_BLUE,
	Character.CharacterType.Дорман: Color.ROSY_BROWN,
	Character.CharacterType.Сигурд: Color.DARK_RED,
	Character.CharacterType.ЗверьГнева: Color.RED,
	Character.CharacterType.ЗверьСмерти: Color.BLACK,
}

var bookmarks_scenes: Dictionary = {}

var name_protection: Dictionary = {
	Character.CharacterType.Нет: ''
}

var name_ru_protection: Dictionary = {
	Character.CharacterType.ГлавныйГерой: 'Главный герой',
	Character.CharacterType.Нет: ''
	}

var name_en_protection: Dictionary = {
	Character.CharacterType.ГлавныйГерой: 'The main character',
	Character.CharacterType.Нет: '',
	Character.CharacterType.Вы: 'You',
	Character.CharacterType.Ты: 'You',
	Character.CharacterType.Алиса: 'Alisa',
	Character.CharacterType.Катя: 'Katya',
	Character.CharacterType.Валя: 'Valia',
	Character.CharacterType.Гальхя: 'Galkhya',
	Character.CharacterType.Фейхья: 'Feihya',
	Character.CharacterType.Калия: 'Kalia',
	Character.CharacterType.Лира: 'Lira',
	Character.CharacterType.Дорман: 'Dorman',
	Character.CharacterType.Фея: 'Feya',
	Character.CharacterType.ЗверьГнева: 'The beast of wrath',
	Character.CharacterType.ЗверьСмерти: 'The Beast of Death',
	Character.CharacterType.Незнакомец: 'Stranger',
	Character.CharacterType.Незнакомка: 'Stranger',
	Character.CharacterType.Прохожий: 'Passerby',
	Character.CharacterType.Мужчина: 'Man',
	Character.CharacterType.Женщина: 'Woman',
	Character.CharacterType.Девушка: 'Girl',
	Character.CharacterType.Подросток: 'Teenager',
	Character.CharacterType.Мальчик: 'Boy',
	Character.CharacterType.Девочка: 'Girl',
	}
	
var emotion_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: ''
}

var emotion_ru_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: '',
	Replica.Emotion.В_мыслях: 'В мыслях',
	Replica.Emotion.Не_доверчиво: 'Не доверчиво',
}

var emotion_en_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: '',
	Replica.Emotion.В_мыслях: 'In your mind',
	Replica.Emotion.Радостно: 'Joyfully',
	Replica.Emotion.Счастливо: 'Happily',
	Replica.Emotion.Смеясь: 'Laughing',
	Replica.Emotion.Веселясь: 'Having fun',
	Replica.Emotion.Хихикая: 'Laughing',
	Replica.Emotion.Грустно: 'Sadly',
	Replica.Emotion.Печально: 'Sadly',
	Replica.Emotion.Огорчённо: 'Disappointed',
	Replica.Emotion.Недовольно: 'Unsatisfied',
	Replica.Emotion.Истеря: 'Hysteria',
	Replica.Emotion.Плача: 'Crying',
	Replica.Emotion.Злясь: 'Angry',
	Replica.Emotion.Злостно: 'Maliciously',
	Replica.Emotion.Яростно: 'Violently',
	Replica.Emotion.Безумно: 'Madly',
	Replica.Emotion.Неистово: 'Violently',
	Replica.Emotion.Подозрительно: 'Suspiciously',
	Replica.Emotion.Раздосадованно: 'Annoyed',
	Replica.Emotion.Задумчиво: 'Thoughtfully',
	Replica.Emotion.Не_доверчиво: 'Not trusting',
	Replica.Emotion.Прищурившись: 'Taking a closer look',
	Replica.Emotion.Присмотревшись: 'Taking a closer look',
	Replica.Emotion.Страсно: 'Passionately',
	Replica.Emotion.Возбуждённо: 'Excited',
	Replica.Emotion.Влюблённо: 'Lovingly',
	Replica.Emotion.Стыдливо: 'Shamefully',
	Replica.Emotion.Смущённо: 'Embarrassed'
}

var character_emotion_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: 'default',
	Replica.Emotion.Злясь: 'evil'
}
var video: bool = true

var text_speed: float = 0.03
var automatic_text_switching: bool = true
var automatic_text_switching_speed: float = 3.0
var current_language: Replica.Language = Replica.Language.En
