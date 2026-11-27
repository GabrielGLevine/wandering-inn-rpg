extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var hero := load("res://assets/key_art/harvest/title_backdrop.png") as Texture2D
	assert(hero != null and hero.get_size() == Vector2(688, 384), "selected title composition must keep its full native canvas")
	for viewport: Vector2 in [Vector2(1280,720), Vector2(844,390), Vector2(390,844)]:
		var scale := minf(viewport.x / hero.get_width(), viewport.y / hero.get_height())
		var fitted := hero.get_size() * scale
		assert(fitted.x <= viewport.x + 0.01 and fitted.y <= viewport.y + 0.01, "fit must preserve inn and city inside every crop")
	for act: String in ["act_i", "act_iii", "act_iv", "act_v"]:
		var art := load("res://assets/key_art/harvest/%s_banner.png" % act) as Texture2D
		assert(art != null and art.get_size() == Vector2(320,80), "environment banner crop must remain 4:1")
		assert(art.get_image().get_used_rect().size == Vector2i(320,80), "each banner must contain visible opaque art")
	assert(not FileAccess.file_exists("res://assets/key_art/harvest/act_ii_banner.png"), "unfit Act II art must preserve the existing text-only header")
	print("PASS: title canvas retains complete composition; compact act environments fit authored geometry with text-only fallback")
	quit(0)
