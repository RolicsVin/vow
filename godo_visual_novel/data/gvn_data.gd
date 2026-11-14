## Данные визуальной новеллы: имена, эмоции и настройки отображения

extends Node

## Цвета имён персонажей в диалоговом окне
var characters_color: Dictionary = {
	Character.CharacterType.Нет: Color.WHITE,
	Character.CharacterType.Подросток: Color.WHITE,
	Character.CharacterType.Асмунд: Color.CRIMSON,
	Character.CharacterType.Сосед: Color.LIGHT_GRAY,
	Character.CharacterType.ДругойСосед: Color.LIGHT_GRAY,
	Character.CharacterType.Отец: Color.BURLYWOOD,
	Character.CharacterType.Девушка: Color.PINK,
	Character.CharacterType.Мать: Color.PEACH_PUFF,
	Character.CharacterType.ЖительДеревни: Color.LIGHT_GRAY,
	Character.CharacterType.ЖительницаДеревни: Color.LIGHT_GRAY,
	Character.CharacterType.Старейшина: Color.TAN,
}

## Сохранённые закладки сцен
var bookmarks_scenes: Dictionary = {}

## Защищённые имена, общие для языков
var name_protection: Dictionary = {
	Character.CharacterType.Нет: '',
}

## Русские имена персонажей
var name_ru_protection: Dictionary = {
	Character.CharacterType.Нет: '',
	Character.CharacterType.Подросток: 'Подросток',
	Character.CharacterType.Асмунд: 'Асмунд',
	Character.CharacterType.Сосед: 'Сосед',
	Character.CharacterType.ДругойСосед: 'Другой сосед',
	Character.CharacterType.Отец: 'Отец',
	Character.CharacterType.Девушка: 'Девушка',
	Character.CharacterType.Мать: 'Мать',
	Character.CharacterType.ЖительДеревни: 'Житель деревни',
	Character.CharacterType.ЖительницаДеревни: 'Жительница деревни',
	Character.CharacterType.Старейшина: 'Старейшина',
}

## Английские имена персонажей
var name_en_protection: Dictionary = {
	Character.CharacterType.Нет: '',
	Character.CharacterType.Подросток: 'Teenager',
	Character.CharacterType.Асмунд: 'Asmund',
	Character.CharacterType.Сосед: 'Neighbor',
	Character.CharacterType.ДругойСосед: 'Another neighbor',
	Character.CharacterType.Отец: 'Father',
	Character.CharacterType.Девушка: 'Girl',
	Character.CharacterType.Мать: 'Mother',
	Character.CharacterType.ЖительДеревни: 'Villager',
	Character.CharacterType.ЖительницаДеревни: 'Villager',
	Character.CharacterType.Старейшина: 'Elder',
}

## Защищённые эмоции, общие для языков
var emotion_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: '',
}

## Русские названия эмоций
var emotion_ru_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: '',
	Replica.Emotion.В_мыслях: 'В мыслях',
	Replica.Emotion.Радостно: 'Радостно',
	Replica.Emotion.Счастливо: 'Счастливо',
	Replica.Emotion.Смеясь: 'Смеясь',
	Replica.Emotion.Веселясь: 'Веселясь',
	Replica.Emotion.Хихикая: 'Хихикая',
	Replica.Emotion.Грустно: 'Грустно',
	Replica.Emotion.Печально: 'Печально',
	Replica.Emotion.Огорчённо: 'Огорчённо',
	Replica.Emotion.Недовольно: 'Недовольно',
	Replica.Emotion.Шокированно: 'Шокированно',
	Replica.Emotion.Удивлённо: 'Удивлённо',
	Replica.Emotion.Пугливо: 'Пугливо',
	Replica.Emotion.Испуганно: 'Испуганно',
	Replica.Emotion.Боясь: 'Боясь',
	Replica.Emotion.Истеря: 'В истерике',
	Replica.Emotion.Плача: 'Плача',
	Replica.Emotion.Злясь: 'Злясь',
	Replica.Emotion.Злостно: 'Злобно',
	Replica.Emotion.Яростно: 'Яростно',
	Replica.Emotion.Безумно: 'Безумно',
	Replica.Emotion.Неистово: 'Неистово',
	Replica.Emotion.Подозрительно: 'Подозрительно',
	Replica.Emotion.Раздосадованно: 'Раздосадованно',
	Replica.Emotion.Задумчиво: 'Задумчиво',
	Replica.Emotion.Насмешливо: 'Насмешливо',
	Replica.Emotion.Издеваясь: 'Издеваясь',
	Replica.Emotion.Не_доверчиво: 'Недоверчиво',
	Replica.Emotion.Прищурившись: 'Прищурившись',
	Replica.Emotion.Присмотревшись: 'Присмотревшись',
	Replica.Emotion.Страсно: 'Страстно',
	Replica.Emotion.Возбуждённо: 'Возбуждённо',
	Replica.Emotion.Влюблённо: 'Влюблённо',
	Replica.Emotion.Стыдливо: 'Стыдливо',
	Replica.Emotion.Смущённо: 'Смущённо',
}

## Английские названия эмоций
var emotion_en_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: '',
	Replica.Emotion.В_мыслях: 'Thoughtful',
	Replica.Emotion.Радостно: 'Joyful',
	Replica.Emotion.Счастливо: 'Happy',
	Replica.Emotion.Смеясь: 'Laughing',
	Replica.Emotion.Веселясь: 'Having fun',
	Replica.Emotion.Хихикая: 'Giggling',
	Replica.Emotion.Грустно: 'Sad',
	Replica.Emotion.Печально: 'Sorrowful',
	Replica.Emotion.Огорчённо: 'Disappointed',
	Replica.Emotion.Недовольно: ' displeased',
	Replica.Emotion.Шокированно: 'Shocked',
	Replica.Emotion.Удивлённо: 'Surprised',
	Replica.Emotion.Пугливо: 'Fearfully',
	Replica.Emotion.Испуганно: 'Frightened',
	Replica.Emotion.Боясь: 'Afraid',
	Replica.Emotion.Истеря: 'Hysterical',
	Replica.Emotion.Плача: 'Crying',
	Replica.Emotion.Злясь: 'Angry',
	Replica.Emotion.Злостно: 'Malicious',
	Replica.Emotion.Яростно: 'Furious',
	Replica.Emotion.Безумно: 'Mad',
	Replica.Emotion.Неистово: 'Frenzied',
	Replica.Emotion.Подозрительно: 'Suspicious',
	Replica.Emotion.Раздосадованно: 'Annoyed',
	Replica.Emotion.Задумчиво: 'Pensive',
	Replica.Emotion.Насмешливо: 'Mocking',
	Replica.Emotion.Издеваясь: 'Taunting',
	Replica.Emotion.Не_доверчиво: 'Distrustful',
	Replica.Emotion.Прищурившись: 'Squinting',
	Replica.Emotion.Присмотревшись: 'Looking closely',
	Replica.Emotion.Страсно: 'Passionately',
	Replica.Emotion.Возбуждённо: 'Excited',
	Replica.Emotion.Влюблённо: 'Lovingly',
	Replica.Emotion.Стыдливо: 'Shyly',
	Replica.Emotion.Смущённо: 'Embarrassed',
}

## Эмоции спрайтов персонажей
var character_emotion_protection: Dictionary = {
	Replica.Emotion.Без_эмоции: 'default',
	Replica.Emotion.В_мыслях: 'lower_eyes',
	Replica.Emotion.Радостно: 'happy',
	Replica.Emotion.Счастливо: 'happy',
	Replica.Emotion.Смеясь: 'happy2',
	Replica.Emotion.Веселясь: 'happy2',
	Replica.Emotion.Хихикая: 'happy2',
	Replica.Emotion.Грустно: 'lower_eyes',
	Replica.Emotion.Печально: 'lower_eyes',
	Replica.Emotion.Огорчённо: 'lower_eyes',
	Replica.Emotion.Недовольно: 'avert_eyes',
	Replica.Emotion.Шокированно: 'shocked',
	Replica.Emotion.Удивлённо: 'shocked',
	Replica.Emotion.Пугливо: 'screaming',
	Replica.Emotion.Испуганно: 'screaming',
	Replica.Emotion.Боясь: 'screaming',
	Replica.Emotion.Истеря: 'crying',
	Replica.Emotion.Плача: 'crying',
	Replica.Emotion.Злясь: 'evil',
	Replica.Emotion.Злостно: 'evil',
	Replica.Emotion.Яростно: 'evil',
	Replica.Emotion.Безумно: 'evil',
	Replica.Emotion.Неистово: 'evil',
	Replica.Emotion.Подозрительно: 'avert_eyes',
	Replica.Emotion.Раздосадованно: 'avert_eyes',
	Replica.Emotion.Задумчиво: 'lower_eyes',
	Replica.Emotion.Насмешливо: 'happy2',
	Replica.Emotion.Издеваясь: 'evil',
	Replica.Emotion.Не_доверчиво: 'avert_eyes',
	Replica.Emotion.Прищурившись: 'avert_eyes',
	Replica.Emotion.Присмотревшись: 'avert_eyes',
	Replica.Emotion.Страсно: 'happy',
	Replica.Emotion.Возбуждённо: 'happy',
	Replica.Emotion.Влюблённо: 'happy',
	Replica.Emotion.Стыдливо: 'embarrassed',
	Replica.Emotion.Смущённо: 'embarrassed',
}

var video: bool = true

var text_speed: float = 0.03
var automatic_text_switching: bool = true
var automatic_text_switching_speed: float = 3.0
var current_language: Replica.Language = Replica.Language.En
