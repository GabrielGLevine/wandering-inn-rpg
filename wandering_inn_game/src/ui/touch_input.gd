extends Node

var _web_cancel_callback: JavaScriptObject


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_web_cancel_callback = JavaScriptBridge.create_callback(_on_web_cancel)
	JavaScriptBridge.get_interface("window").__wi_touch_cancel = _web_cancel_callback
	# Godot 4.7's web adapter maps touchcancel to touchend and loses canceled.
	# Replace only cancellation; Input still owns touch-to-mouse translation.
	JavaScriptBridge.eval("""
		(() => {
		 const canvas = document.querySelector('canvas');
		 canvas.addEventListener('touchcancel', event => {
		  const rect = canvas.getBoundingClientRect();
		  const contacts = Array.from(event.changedTouches, touch => ({
		   index: touch.identifier,
		   x: (touch.clientX - rect.left) * canvas.width / rect.width,
		   y: (touch.clientY - rect.top) * canvas.height / rect.height,
		  }));
		  event.stopImmediatePropagation();
		  if (event.cancelable) event.preventDefault();
		  window.__wi_touch_cancel(JSON.stringify(contacts));
		 }, {capture: true, passive: false});
		})();
	""", true)


func _on_web_cancel(args: Array) -> void:
	var contacts: Array = JSON.parse_string(String(args[0]))
	for contact: Dictionary in contacts:
		var event := InputEventScreenTouch.new()
		event.index = int(contact.index)
		event.position = Vector2(float(contact.x), float(contact.y))
		event.pressed = false
		event.canceled = true
		Input.parse_input_event(event)
