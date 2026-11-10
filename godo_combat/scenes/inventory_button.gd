extends TextureButton

var gc_item: GCItem
var _call_back: Callable


func setup(item: GCItem, call_back: Callable):
	gc_item = item
	_call_back = call_back
	
	$Label.text = item.get_item_name()
	
	if item.get_item_icon():
		texture_normal = item.get_item_icon()
	if item.get_item_icon_hover():
		texture_hover = item.get_item_icon_hover()
	if item.get_item_icon_pressed():
		texture_pressed = item.get_item_icon_pressed()


func _pressed() -> void:
	GCombat._buffer['inventory'].remove_at(GCombat._buffer['inventory'].find(gc_item.get_item_name()))
	_call_back.call(gc_item.get_item_effects())
