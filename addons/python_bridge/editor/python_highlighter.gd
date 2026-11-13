@tool
extends EditorSyntaxHighlighter
## Python syntax highlighter with its own tokenizer. It is a genuine
## EditorSyntaxHighlighter, so the script editor can manage it like its built-in ones.

const KEYWORDS_CONTROL := [
	"if", "elif", "else", "for", "while", "break", "continue", "return", "pass",
	"try", "except", "finally", "raise", "with", "yield", "assert", "del",
	"match", "case", "async", "await",
]
const KEYWORDS := [
	"def", "class", "lambda", "global", "nonlocal", "and", "or", "not", "in", "is",
	"import", "from", "as", "self", "cls",
]
const CONSTANTS := ["True", "False", "None"]
const BUILTIN_TYPES := [
	"int", "float", "str", "bool", "list", "dict", "set", "frozenset", "tuple", "bytes",
	"bytearray", "object", "type", "complex", "Exception", "ValueError", "TypeError",
	"KeyError", "IndexError", "RuntimeError", "OSError", "StopIteration",
]
const SYMBOLS := "+-*/%=<>!&|^~:;,.()[]{}@"

var _loaded := false
var _colorize := false
var _last := Color()
var _c_text := Color.WHITE
var _c_string := Color.WHITE
var _c_comment := Color.GRAY
var _c_number := Color.WHITE
var _c_symbol := Color.WHITE
var _c_function := Color.WHITE
var _c_member := Color.WHITE
var _c_type := Color.WHITE
var _word_colors: Dictionary = {}

# _states[i] = multi-line string state at the start of line i (0 none, 1 """, 2 ''')
# _texts[i]  = text of line i that _states[i + 1] was derived from
var _states := PackedInt32Array([0])
var _texts := PackedStringArray()
var _frame := -1


func _get_name() -> String:
	return "Python"


func _get_supported_languages() -> PackedStringArray:
	return PackedStringArray()


func _create() -> EditorSyntaxHighlighter:
	var script: GDScript = get_script()
	return script.new()


func _clear_highlighting_cache() -> void:
	_states = PackedInt32Array([0])
	_texts = PackedStringArray()
	_frame = -1


func _update_cache() -> void:
	_loaded = false
	_clear_highlighting_cache()


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var te := get_text_edit()
	if te == null or line < 0 or line >= te.get_line_count():
		return {}
	if not _loaded:
		_load_colors()
	_validate(te)
	while _texts.size() < line:
		var idx := _texts.size()
		var t := te.get_line(idx)
		_texts.append(t)
		_states.append(_end_state(t, _states[idx]))
	return _scan(te.get_line(line), _states[line], true)[1]


## Once per frame: drop cached states below the first line that changed.
func _validate(te: TextEdit) -> void:
	var frame := Engine.get_frames_drawn()
	if frame == _frame:
		return
	_frame = frame
	var limit := mini(_texts.size(), te.get_line_count())
	var keep := 0
	while keep < limit and _texts[keep] == te.get_line(keep):
		keep += 1
	_texts.resize(keep)
	_states.resize(keep + 1)


func _end_state(text: String, state: int) -> int:
	if state == 0 and text.find('"""') == -1 and text.find("'''") == -1:
		return 0
	return _scan(text, state, false)[0]


## Returns [state_at_end_of_line, {column: {"color": Color}}].
func _scan(text: String, state: int, colorize: bool) -> Array:
	_colorize = colorize
	var out := {}
	if colorize:
		out[0] = {"color": _c_text}
		_last = _c_text
	var n := text.length()
	var i := 0

	if state != 0:
		var closing := '"""' if state == 1 else "'''"
		_mark(out, 0, _c_string)
		var end := text.find(closing)
		if end == -1:
			return [state, out]
		i = end + 3
		state = 0
		if i < n:
			_mark(out, i, _c_text)

	while i < n:
		var c := text[i]

		if c == "#":
			_mark(out, i, _c_comment)
			break

		if c == '"' or c == "'":
			_mark(out, i, _c_string)
			var triple := c + c + c
			if text.substr(i, 3) == triple:
				var end := text.find(triple, i + 3)
				if end == -1:
					return [1 if c == '"' else 2, out]
				i = end + 3
			else:
				var j := i + 1
				while j < n:
					var d := text[j]
					if d == "\\":
						j += 2
						continue
					j += 1
					if d == c:
						break
				i = j
			if i < n:
				_mark(out, i, _c_text)
			continue

		if c >= "0" and c <= "9" and (i == 0 or not _is_word_char(text[i - 1])):
			var j := i + 1
			while j < n and (_is_word_char(text[j]) or text[j] == "."):
				j += 1
			_mark(out, i, _c_number)
			i = j
			if i < n:
				_mark(out, i, _c_text)
			continue

		if c == "@" and text.substr(0, i).strip_edges().is_empty():
			var j := i + 1
			while j < n and (_is_word_char(text[j]) or text[j] == "."):
				j += 1
			_mark(out, i, _c_function)
			i = j
			if i < n:
				_mark(out, i, _c_text)
			continue

		if _is_word_char(c):
			var j := i + 1
			while j < n and _is_word_char(text[j]):
				j += 1
			_mark(out, i, _word_color(text, text.substr(i, j - i), i, j))
			i = j
			continue

		_mark(out, i, _c_symbol if SYMBOLS.contains(c) else _c_text)
		i += 1

	return [state, out]


func _word_color(text: String, word: String, start: int, end: int) -> Color:
	if _word_colors.has(word):
		return _word_colors[word]
	if start > 0 and text.substr(0, start).rstrip(" ").ends_with("class"):
		return _c_type
	var k := end
	while k < text.length() and text[k] == " ":
		k += 1
	if k < text.length() and text[k] == "(":
		return _c_function
	if start > 0 and text[start - 1] == ".":
		return _c_member
	return _c_text


func _mark(out: Dictionary, column: int, color: Color) -> void:
	if not _colorize:
		return
	if color != _last:
		out[column] = {"color": color}
		_last = color


func _is_word_char(c: String) -> bool:
	return c == "_" or (c >= "0" and c <= "9") or (c >= "a" and c <= "z") \
			or (c >= "A" and c <= "Z") or c.unicode_at(0) > 127


func _load_colors() -> void:
	_loaded = true
	_c_text = _color("text_color", Color(0.83, 0.87, 1.0))
	_c_string = _color("string_color", Color("ffeda1"))
	_c_comment = _color("comment_color", Color(0.8, 0.81, 0.82, 0.5))
	_c_number = _color("number_color", Color("a1ffe0"))
	_c_symbol = _color("symbol_color", Color("abc9ff"))
	_c_function = _color("function_color", Color("57b3ff"))
	_c_member = _color("member_variable_color", Color("bce0ff"))
	_c_type = _color("user_type_color", Color("c7ffed"))
	var c_control := _color("control_flow_keyword_color", Color("ff8ccc"))
	var c_keyword := _color("keyword_color", Color("ff7085"))
	var c_const := _color("base_type_color", Color("a4ffd4"))
	var c_builtin := _color("engine_type_color", Color("8fffdb"))
	_word_colors.clear()
	for w in KEYWORDS_CONTROL:
		_word_colors[w] = c_control
	for w in KEYWORDS:
		_word_colors[w] = c_keyword
	for w in CONSTANTS:
		_word_colors[w] = c_const
	for w in BUILTIN_TYPES:
		_word_colors[w] = c_builtin


static func _color(key: String, fallback: Color) -> Color:
	var settings := EditorInterface.get_editor_settings()
	var path := "text_editor/theme/highlighting/" + key
	if settings.has_setting(path):
		var value: Variant = settings.get_setting(path)
		if value is Color:
			return value
	return fallback
