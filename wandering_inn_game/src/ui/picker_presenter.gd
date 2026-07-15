class_name WIPickerPresenter
extends RefCounted


## CONTRACT: numbered body rows and visible options are lockstep; derive only, never rewrite sim payload/order.
static func derive(body: String, options: Array) -> Dictionary:
	var prompt := ""
	var details: Array[String] = []
	var detail_index := -1
	for raw_line: String in body.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var numbered := _numbered_detail(line)
		if not numbered.is_empty():
			detail_index = int(numbered["index"])
			while details.size() <= detail_index:
				details.append("")
			details[detail_index] = String(numbered["text"])
		elif prompt.is_empty():
			prompt = line
		elif detail_index >= 0:
			details[detail_index] = (details[detail_index] + " " + line).strip_edges()

	var rows: Array[Dictionary] = []
	for i in options.size():
		var option: Dictionary = options[i]
		var choice := _split_choice(String(option.get("text", "")))
		rows.append({
			"title": String(choice["title"]),
			"reward": String(choice["reward"]),
			"detail": details[i] if i < details.size() else "",
			"locked": bool(option.get("locked", false)),
			"requirement": String(option.get("requirement", "")),
			"cancel": bool(choice["cancel"]),
		})
	return {"prompt": prompt, "rows": rows}


static func is_picker_payload(body: String, options: Array) -> bool:
	if options.size() < 2:
		return false
	var payload := derive(body, options)
	var rows: Array = payload["rows"]
	if rows.is_empty() or not bool((rows[-1] as Dictionary).get("cancel", false)):
		return false
	for row: Dictionary in rows:
		if not String(row["detail"]).is_empty():
			return true
	return false


static func _numbered_detail(line: String) -> Dictionary:
	var separator := line.find(". ")
	if separator <= 0:
		return {}
	var ordinal := line.left(separator)
	if not ordinal.is_valid_int() or int(ordinal) < 1:
		return {}
	return {"index": int(ordinal) - 1, "text": line.substr(separator + 2).strip_edges()}


static func _split_choice(text: String) -> Dictionary:
	if not text.begins_with("Take: "):
		return {"title": text, "reward": "", "cancel": true}
	var title := text.trim_prefix("Take: ")
	var reward := ""
	var reward_start := title.rfind(". (")
	if reward_start >= 0 and title.ends_with(")"):
		reward = title.substr(reward_start + 3, title.length() - reward_start - 4)
		title = title.left(reward_start)
	return {"title": title, "reward": reward, "cancel": false}
