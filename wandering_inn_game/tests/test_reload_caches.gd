extends SceneTree

## GH#278: the live-reload cache seams. Proves (1) each static-cache
## reset() actually clears (internal-state asserts), (2) THE STALENESS
## FIX end-to-end for the sim-side catalog: a map file written AFTER a
## compose() is invisible until reset() (the exact bug class reload_data
## exists to fix), via a TEMP region dir that is created and deleted
## INSIDE this run. TRAP: if this test ever crashes between write and
## cleanup, an untracked data/maps/zz_qa_tmp/ dir is left behind --
## delete it by hand. The leak is caught by THIS test's own next run
## (the "temp map must not pre-exist" assert) and by git status
## (untracked, not gitignored); a bare extra map keeps test_content /
## test_shipped_ids / test_fixture_coherence green (verified), so do
## not expect the content gates to flag it.

const TMP_DIR := "res://data/maps/zz_qa_tmp"
const TMP_MAP := TMP_DIR + "/zz_qa_tmp_map.json"


func _init() -> void:
	WITestWatchdog.arm(self)

	# --- WISceneCatalog: reset clears, recompose byte-equal on same disk.
	WISceneCatalog.reset()
	var before: Dictionary = WISceneCatalog.compose()
	WISceneCatalog.reset()
	assert(WISceneCatalog.compose() == before, "recompose after reset must equal on unchanged disk")

	# --- Staleness proof: new map file invisible until reset().
	assert(not before["maps"].has("zz_qa_tmp_map"), "temp map must not pre-exist")
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var f := FileAccess.open(TMP_MAP, FileAccess.WRITE)
	assert(f != null, "could not write temp map")
	f.store_string(JSON.stringify({"grid": {"width": 2, "height": 2}, "blocked": [], "entities": []}))
	f.close()
	var stale: Dictionary = WISceneCatalog.compose()
	assert(not stale["maps"].has("zz_qa_tmp_map"),
		"cached compose must NOT see the new file (this failing means the cache is gone and reload_data's reset is redundant -- re-read GH#278)")
	WISceneCatalog.reset()
	var fresh: Dictionary = WISceneCatalog.compose()
	assert(fresh["maps"].has("zz_qa_tmp_map"), "post-reset compose must see the new file")
	# Cleanup IMMEDIATELY, then leave the catalog fresh for anyone after us.
	DirAccess.remove_absolute(TMP_MAP)
	DirAccess.remove_absolute(TMP_DIR)
	WISceneCatalog.reset()
	assert(not WISceneCatalog.compose()["maps"].has("zz_qa_tmp_map"), "cleanup must restore the catalog")

	# --- View-side caches: populate, reset, empty, repopulate.
	assert(WISpriteRegistry.has_sprite("body_a"), "catalog lookup must populate")
	assert(not WISpriteRegistry._catalog.is_empty(), "sprite catalog populated")
	WISpriteRegistry.reset()
	assert(WISpriteRegistry._catalog.is_empty(), "sprite reset must clear _catalog")
	assert(WISpriteRegistry._cache.is_empty(), "sprite reset must clear _cache")
	assert(WISpriteRegistry._tile_sources.is_empty(), "sprite reset must clear _tile_sources")
	assert(WISpriteRegistry.has_sprite("body_a"), "lookup must repopulate after reset")

	# WIAtmosphere / WICombatBoardRenderer reference the ObservableBus
	# autoload, so they CANNOT compile in --script mode (no autoloads) --
	# their reset() correctness is a one-line cache clear whose wiring is
	# exercised by reload_loop's real-game GAME_LOADED path and whose
	# compile is covered by load_gate.

	print("PASS test_reload_caches")
	quit(0)
