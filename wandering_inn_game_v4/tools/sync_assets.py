#!/usr/bin/env python3
"""Copy curated Pixel Crawler assets into the Godot project."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = Path(__file__).resolve().parents[1]

MANIFEST: list[tuple[str, str]] = [
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Terms.txt",
		"assets/LICENSES/pixel-crawler-free-pack-2.1-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Cave/Pixel Crawler - Cave/Terms.txt",
		"assets/LICENSES/pixel-crawler-cave-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Down-Sheet.png",
		"assets/sprites/body_a/Idle_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Side-Sheet.png",
		"assets/sprites/body_a/Idle_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Up-Sheet.png",
		"assets/sprites/body_a/Idle_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Walk_Base/Walk_Down-Sheet.png",
		"assets/sprites/body_a/Walk_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Walk_Base/Walk_Side-Sheet.png",
		"assets/sprites/body_a/Walk_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Walk_Base/Walk_Up-Sheet.png",
		"assets/sprites/body_a/Walk_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Slice_Base/Slice_Down-Sheet.png",
		"assets/sprites/body_a/Slice_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Slice_Base/Slice_Side-Sheet.png",
		"assets/sprites/body_a/Slice_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Slice_Base/Slice_Up-Sheet.png",
		"assets/sprites/body_a/Slice_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Hit_Base/Hit_Down-Sheet.png",
		"assets/sprites/body_a/Hit_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Hit_Base/Hit_Side-Sheet.png",
		"assets/sprites/body_a/Hit_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Hit_Base/Hit_Up-Sheet.png",
		"assets/sprites/body_a/Hit_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Death_Base/Death_Down-Sheet.png",
		"assets/sprites/body_a/Death_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Death_Base/Death_Side-Sheet.png",
		"assets/sprites/body_a/Death_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Death_Base/Death_Up-Sheet.png",
		"assets/sprites/body_a/Death_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Idle/Idle_Down-Sheet.png",
		"assets/sprites/citizen_f/Idle_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Idle/Idle_Side-Sheet.png",
		"assets/sprites/citizen_f/Idle_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Idle/Idle_Up-Sheet.png",
		"assets/sprites/citizen_f/Idle_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Walk/Walk_Down-Sheet.png",
		"assets/sprites/citizen_f/Walk_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Walk/Walk_Side-Sheet.png",
		"assets/sprites/citizen_f/Walk_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Walk/Walk_Up-Sheet.png",
		"assets/sprites/citizen_f/Walk_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png",
		"assets/tiles/free_pack/Floors_Tiles.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Tilesets/Wall_Tiles.png",
		"assets/tiles/free_pack/Wall_Tiles.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png",
		"assets/props/free_pack/Interior_Props_01.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png",
		"assets/props/free_pack/Esoteric.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png",
		"assets/props/free_pack/Furniture.png",
	),
	(
		"potential_assets/Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png",
		"assets/tiles/cave/Tiles.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/goblin-spritesheet.png",
		"assets/sprites/goblin_base/goblin-spritesheet.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_00.png",
		"assets/sprites/goblin_base/frames/down/down_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_01.png",
		"assets/sprites/goblin_base/frames/down/down_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_02.png",
		"assets/sprites/goblin_base/frames/down/down_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_03.png",
		"assets/sprites/goblin_base/frames/down/down_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_04.png",
		"assets/sprites/goblin_base/frames/down/down_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/down/down_05.png",
		"assets/sprites/goblin_base/frames/down/down_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_00.png",
		"assets/sprites/goblin_base/frames/left/left_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_01.png",
		"assets/sprites/goblin_base/frames/left/left_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_02.png",
		"assets/sprites/goblin_base/frames/left/left_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_03.png",
		"assets/sprites/goblin_base/frames/left/left_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_04.png",
		"assets/sprites/goblin_base/frames/left/left_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/left/left_05.png",
		"assets/sprites/goblin_base/frames/left/left_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_00.png",
		"assets/sprites/goblin_base/frames/right/right_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_01.png",
		"assets/sprites/goblin_base/frames/right/right_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_02.png",
		"assets/sprites/goblin_base/frames/right/right_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_03.png",
		"assets/sprites/goblin_base/frames/right/right_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_04.png",
		"assets/sprites/goblin_base/frames/right/right_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/right/right_05.png",
		"assets/sprites/goblin_base/frames/right/right_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_00.png",
		"assets/sprites/goblin_base/frames/up/up_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_01.png",
		"assets/sprites/goblin_base/frames/up/up_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_02.png",
		"assets/sprites/goblin_base/frames/up/up_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_03.png",
		"assets/sprites/goblin_base/frames/up/up_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_04.png",
		"assets/sprites/goblin_base/frames/up/up_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-pack/frames/up/up_05.png",
		"assets/sprites/goblin_base/frames/up/up_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/goblin-female-spritesheet.png",
		"assets/sprites/goblin_female/goblin-female-spritesheet.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_00.png",
		"assets/sprites/goblin_female/frames/down/down_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_01.png",
		"assets/sprites/goblin_female/frames/down/down_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_02.png",
		"assets/sprites/goblin_female/frames/down/down_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_03.png",
		"assets/sprites/goblin_female/frames/down/down_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_04.png",
		"assets/sprites/goblin_female/frames/down/down_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/down/down_05.png",
		"assets/sprites/goblin_female/frames/down/down_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_00.png",
		"assets/sprites/goblin_female/frames/left/left_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_01.png",
		"assets/sprites/goblin_female/frames/left/left_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_02.png",
		"assets/sprites/goblin_female/frames/left/left_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_03.png",
		"assets/sprites/goblin_female/frames/left/left_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_04.png",
		"assets/sprites/goblin_female/frames/left/left_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/left/left_05.png",
		"assets/sprites/goblin_female/frames/left/left_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_00.png",
		"assets/sprites/goblin_female/frames/right/right_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_01.png",
		"assets/sprites/goblin_female/frames/right/right_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_02.png",
		"assets/sprites/goblin_female/frames/right/right_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_03.png",
		"assets/sprites/goblin_female/frames/right/right_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_04.png",
		"assets/sprites/goblin_female/frames/right/right_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/right/right_05.png",
		"assets/sprites/goblin_female/frames/right/right_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_00.png",
		"assets/sprites/goblin_female/frames/up/up_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_01.png",
		"assets/sprites/goblin_female/frames/up/up_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_02.png",
		"assets/sprites/goblin_female/frames/up/up_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_03.png",
		"assets/sprites/goblin_female/frames/up/up_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_04.png",
		"assets/sprites/goblin_female/frames/up/up_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-female-pack/frames/up/up_05.png",
		"assets/sprites/goblin_female/frames/up/up_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/goblin-sword-spritesheet.png",
		"assets/sprites/goblin_sword/goblin-sword-spritesheet.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_00.png",
		"assets/sprites/goblin_sword/frames/down/down_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_01.png",
		"assets/sprites/goblin_sword/frames/down/down_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_02.png",
		"assets/sprites/goblin_sword/frames/down/down_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_03.png",
		"assets/sprites/goblin_sword/frames/down/down_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_04.png",
		"assets/sprites/goblin_sword/frames/down/down_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/down/down_05.png",
		"assets/sprites/goblin_sword/frames/down/down_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_00.png",
		"assets/sprites/goblin_sword/frames/left/left_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_01.png",
		"assets/sprites/goblin_sword/frames/left/left_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_02.png",
		"assets/sprites/goblin_sword/frames/left/left_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_03.png",
		"assets/sprites/goblin_sword/frames/left/left_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_04.png",
		"assets/sprites/goblin_sword/frames/left/left_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/left/left_05.png",
		"assets/sprites/goblin_sword/frames/left/left_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_00.png",
		"assets/sprites/goblin_sword/frames/right/right_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_01.png",
		"assets/sprites/goblin_sword/frames/right/right_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_02.png",
		"assets/sprites/goblin_sword/frames/right/right_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_03.png",
		"assets/sprites/goblin_sword/frames/right/right_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_04.png",
		"assets/sprites/goblin_sword/frames/right/right_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/right/right_05.png",
		"assets/sprites/goblin_sword/frames/right/right_05.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_00.png",
		"assets/sprites/goblin_sword/frames/up/up_00.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_01.png",
		"assets/sprites/goblin_sword/frames/up/up_01.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_02.png",
		"assets/sprites/goblin_sword/frames/up/up_02.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_03.png",
		"assets/sprites/goblin_sword/frames/up/up_03.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_04.png",
		"assets/sprites/goblin_sword/frames/up/up_04.png",
	),
	(
		"potential_assets/goblin-pack/goblin-sword-pack/frames/up/up_05.png",
		"assets/sprites/goblin_sword/frames/up/up_05.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Idle/Idle_Down-Sheet.png",
		"assets/sprites/bat/Idle/Idle_Down-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Idle/Idle_Side-Sheet.png",
		"assets/sprites/bat/Idle/Idle_Side-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Idle/Idle_Up-Sheet.png",
		"assets/sprites/bat/Idle/Idle_Up-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Move/Move_Down-Sheet.png",
		"assets/sprites/bat/Move/Move_Down-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Move/Move_Side-Sheet.png",
		"assets/sprites/bat/Move/Move_Side-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Move/Move_Up-Sheet.png",
		"assets/sprites/bat/Move/Move_Up-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Hit/Hit_Down-Sheet.png",
		"assets/sprites/bat/Hit/Hit_Down-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Hit/Hit_Side-Sheet.png",
		"assets/sprites/bat/Hit/Hit_Side-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Hit/Hit_Up-Sheet.png",
		"assets/sprites/bat/Hit/Hit_Up-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Death/Death_Down-Sheet.png",
		"assets/sprites/bat/Death/Death_Down-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Death/Death_Side-Sheet.png",
		"assets/sprites/bat/Death/Death_Side-Sheet.png",
	),
	(
		"potential_assets/Bat_Fur/Bat_Fur/Death/Death_Up-Sheet.png",
		"assets/sprites/bat/Death/Death_Up-Sheet.png",
	),
	# M5 R4 immersion pass (environment-ui-immersion-design.md) -- wall bands,
	# skirt materials, animated sconce, cave/decor props.
	(
		"potential_assets/Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Terms.txt",
		"assets/LICENSES/pixel-crawler-castle-environment-0.3-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png",
		"assets/tiles/castle/Tiles.png",
	),
	(
		"potential_assets/topdown_floor_tiles_12/README.txt",
		"assets/LICENSES/topdown-floor-tiles-12-README.txt",
	),
	(
		"potential_assets/topdown_floor_tiles_12/dirt/dirt_01.png",
		"assets/tiles/floor_tiles_12/dirt_01.png",
	),
	(
		"potential_assets/topdown_floor_tiles_12/grass/grass_01.png",
		"assets/tiles/floor_tiles_12/grass_01.png",
	),
	(
		"potential_assets/topdown_floor_tiles_12/transition/transition_01.png",
		"assets/tiles/floor_tiles_12/transition_01.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Walls_01.png",
		"assets/props/free_pack/Interior_Walls_01.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_01-Sheet.png",
		"assets/props/free_pack/Bonfire_01-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png",
		"assets/props/cave/Props.png",
	),
	# M5 A2: xDeviruchi "16-bit Fantasy & Adventure (2025)" music contexts.
	# Verdict: assets/LICENSES/xdeviruchi-16-bit-fantasy-adventure-2025-verdict.md
	# (SHIP-OK, user-attested; attribution ships in credits per M10 checklist).
	# Sources are curated (loop-trimmed + re-encoded to a web-size-friendly OGG
	# Vorbis quality) from the pack's "Loopable + one shots/ogg" folder into a
	# `_curated/` staging dir under the gitignored potential_assets pack, NOT
	# copied verbatim -- see `.superpowers/sdd/m5-a2-report.md` for the exact
	# ffmpeg commands (trim to the pack's LOOPSTART+LOOPLENGTH sample range,
	# `-c:a vorbis -q:a 6`) used to produce them.
	(
		"potential_assets/xDeviruchi - 16 bit Fantasy & Adventure (2025)/_curated/title_theme.ogg",
		"assets/audio/music/title_theme.ogg",
	),
	(
		"potential_assets/xDeviruchi - 16 bit Fantasy & Adventure (2025)/_curated/definitely_our_town.ogg",
		"assets/audio/music/definitely_our_town.ogg",
	),
	(
		"potential_assets/xDeviruchi - 16 bit Fantasy & Adventure (2025)/_curated/port_town.ogg",
		"assets/audio/music/port_town.ogg",
	),
	(
		"potential_assets/xDeviruchi - 16 bit Fantasy & Adventure (2025)/_curated/battle_1.ogg",
		"assets/audio/music/battle_1.ogg",
	),
	(
		"potential_assets/xDeviruchi - 16 bit Fantasy & Adventure (2025)/_curated/victory.ogg",
		"assets/audio/music/victory.ogg",
	),
	# M5 A3: Minifantasy Dungeon SFX real sound swap (replaces A1's generated
	# placeholder WAVs at the same res:// paths -- audio.json event mapping is
	# UNCHANGED, only volume_db trims + these bytes moved).
	# Verdict: assets/LICENSES/minifantasy-dungeon-sfx-verdict.md (SHIP-OK,
	# user-attested). Curation pipeline (documented here, not run automatically
	# by this script): source WAV/MP3s in
	# `potential_assets/Minifantasy_Dungeon_SFX/` were downmixed to mono
	# 16-bit PCM @ 44.1kHz and peak-normalized to -1.0 dBFS with
	# `ffmpeg -i <src> -ac 1 -ar 44100 -sample_fmt s16 -af "volume=<gain>dB"
	# -c:a pcm_s16le <dst>`, where `<gain> = -1.0 - <measured max_volume via
	# ffmpeg -af volumedetect>` (per-file gain measured, not guessed -- see
	# `.superpowers/sdd/m5-a3-report.md` for the exact source file / gain
	# table). Two sources (door_open/door_close) were `.mp3` in the pack and
	# are converted to `.wav` here since `test_audio_data.gd` only whitelists
	# `.wav`/`.ogg` stream extensions. Output staged to a gitignored
	# `_curated/` dir under the pack (NOT the raw pack files copied verbatim),
	# matching the A2 xDeviruchi pipeline.
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/ui_tick.wav",
		"assets/audio/sfx/ui_tick.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/ui_confirm.wav",
		"assets/audio/sfx/ui_confirm.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/dialogue_open.wav",
		"assets/audio/sfx/dialogue_open.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/dialogue_choice.wav",
		"assets/audio/sfx/dialogue_choice.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/toast.wav",
		"assets/audio/sfx/toast.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/footstep.wav",
		"assets/audio/sfx/footstep.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/attack_hit.wav",
		"assets/audio/sfx/attack_hit.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/attack_miss.wav",
		"assets/audio/sfx/attack_miss.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/skill_physical.wav",
		"assets/audio/sfx/skill_physical.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/skill_fire.wav",
		"assets/audio/sfx/skill_fire.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/skill_frost.wav",
		"assets/audio/sfx/skill_frost.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/skill_arcane.wav",
		"assets/audio/sfx/skill_arcane.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/dash.wav",
		"assets/audio/sfx/dash.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/downed.wav",
		"assets/audio/sfx/downed.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/victory.wav",
		"assets/audio/sfx/victory.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/defeat.wav",
		"assets/audio/sfx/defeat.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/level_up.wav",
		"assets/audio/sfx/level_up.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/quest_chime.wav",
		"assets/audio/sfx/quest_chime.wav",
	),
	(
		"potential_assets/Minifantasy_Dungeon_SFX/_curated/save_chime.wav",
		"assets/audio/sfx/save_chime.wav",
	),
	# M5 H1: hotbar chrome (immersion-design.md sec.5) -- carved-wood slot
	# frame + a button-styled panel swapped in for the selected-slot highlight
	# (design doc: "pressed/hover button states from Buttons/ for the selected
	# slot"). Verdict: assets/LICENSES/tiny-swords-verdict.md (SHIP-OK,
	# user-attested). Copied whole (NinePatchRect margins tuned in
	# src/ui/hotbar.gd, not by cropping here).
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Banners/Carved_9Slides.png",
		"assets/ui/chrome/Carved_9Slides.png",
	),
	# M5 H3: UI-restyle parchment chrome (src/ui/ui_chrome.gd) -- vertical
	# banner (portrait scroll panel) + horizontal banner (landscape strip).
	# Same Tiny Swords verdict as above; copied whole -- the floating-art
	# bbox regions are applied at runtime in ui_chrome.gd, not by cropping.
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Banners/Banner_Vertical.png",
		"assets/ui/chrome/Banner_Vertical.png",
	),
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Banners/Banner_Horizontal.png",
		"assets/ui/chrome/Banner_Horizontal.png",
	),
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Buttons/Button_Blue_9Slides.png",
		"assets/ui/chrome/Button_Blue_9Slides.png",
	),
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Buttons/Button_Blue_9Slides_Pressed.png",
		"assets/ui/chrome/Button_Blue_9Slides_Pressed.png",
	),
	# M5 H3: blue ribbon header chrome (title banner, dialogue/journal
	# headers, combat banner) -- asymmetric 9-slice margins in ui_chrome.gd.
	(
		"potential_assets/Tiny Swords/Tiny Swords (Update 010)/UI/Ribbons/Ribbon_Blue_3Slides.png",
		"assets/ui/chrome/Ribbon_Blue_3Slides.png",
	),
	# --- M5 E3 environment art pass (scene-assembly-guide L1/L2 kit) ---
	# Free Pack 2.1 props/structures for inn dressing (food, kitchen station),
	# street facades (building walls/roofs/shadows), and exterior scatter
	# (vegetation/rocks/trees). Paths per docs/asset-index.md.
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png",
		"assets/props/free_pack/Meat.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png",
		"assets/props/free_pack/Vegetation.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png",
		"assets/props/free_pack/Rocks.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_04.png",
		"assets/props/free_pack/Tree_M1_S4.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_04.png",
		"assets/props/free_pack/Tree_M2_S4.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Buildings/Walls.png",
		"assets/props/free_pack/Building_Walls.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Buildings/Roofs.png",
		"assets/props/free_pack/Building_Roofs.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Buildings/Shadows.png",
		"assets/props/free_pack/Building_Shadows.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png",
		"assets/props/free_pack/Cooking_Estructure.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Grill/Grill_01-Sheet.png",
		"assets/props/free_pack/Grill_01-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png",
		"assets/props/free_pack/Furnace.png",
	),
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Tilesets/Wall_Variations.png",
		"assets/tiles/free_pack/Wall_Variations.png",
	),
	# --- Floodplains world map (consultant design 2026-07-03) ---
	(
		"potential_assets/Pixel Crawler - Free Pack 2.1/Pixel Crawler - Free Pack/Environment/Tilesets/Water_tiles.png",
		"assets/tiles/free_pack/Water_tiles.png",
	),
	(
		"potential_assets/topdown_floor_tiles_12/grass/grass_02.png",
		"assets/tiles/floor_tiles_12/grass_02.png",
	),
	(
		"potential_assets/topdown_floor_tiles_12/grass/grass_03.png",
		"assets/tiles/floor_tiles_12/grass_03.png",
	),
	# --- Liscor Gate District + Relc tutorial (2026-07-03 design, D1-2.2/D2-2) ---
	(
		"potential_assets/Pixel Crawler - Library/Pixel Crawler - Library/Terms.txt",
		"assets/LICENSES/pixel-crawler-library-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png",
		"assets/tiles/library/Tiles.png",
	),
	(
		"potential_assets/Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Enemies/Royal Crew/Soldier/Idle-Sheet.png",
		"assets/sprites/royal_soldier/Idle-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Sewer/Pixel Crawler - Sewer/Terms.txt",
		"assets/LICENSES/pixel-crawler-sewer-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png",
		"assets/props/sewer/Props.png",
	),
	# --- Admurin Animated Chests (Track B2 item 4: inn_chest open-lid swap) ---
	# ADMURIN is TIER-PRIVATE / no-standalone-redistribution (no-AI-training
	# clause; ship rendered OK per attestation). Chests.png therefore ships in
	# assets/ but is listed in assets_manifest.json as NEEDS-ATTESTATION /
	# bundle: true so a public checkout excludes it and falls back to the
	# placeholder chip.
	(
		"potential_assets/Admurins_Freebies-2/License.txt",
		"assets/LICENSES/admurins-freebies-License.txt",
	),
	(
		"potential_assets/Admurins_Freebies-2/Admurin's Freebies/Animated Chests/Chests.png",
		"assets/props/admurin/Chests.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Terms.txt",
		"assets/LICENSES/pixel-crawler-cemetery-0.4-Terms.txt",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Idle_Base/Idle_Down-Sheet.png",
		"assets/sprites/a_hunter/Idle_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Idle_Base/Idle_Side-Sheet.png",
		"assets/sprites/a_hunter/Idle_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Idle_Base/Idle_Up-Sheet.png",
		"assets/sprites/a_hunter/Idle_Up-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Run_Base/Run_Down-Sheet.png",
		"assets/sprites/a_hunter/Run_Down-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Run_Base/Run_Side-Sheet.png",
		"assets/sprites/a_hunter/Run_Side-Sheet.png",
	),
	(
		"potential_assets/Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Entities/Characters/A_Hunter/Run_Base/Run_Up-Sheet.png",
		"assets/sprites/a_hunter/Run_Up-Sheet.png",
	),
]

# M5 H1: hotbar slot icons -- (src, dst, size) resized (LANCZOS) down to a
# 16px icon, matching the game's CELL=16 pixel-art scale (M5 R3). Only two
# slots have a plausible Tiny Swords source crop (Attack's crossed-swords
# glyph, Dash's forward-motion arrow); see .superpowers/sdd/m5-h1-report.md
# icon-pick table for the full slot -> source rationale, including the
# skill slots that fall back to PLACEHOLDER_ICONS below instead (no
# fire/frost/burst glyph exists in either Tiny Swords pack).
ICON_MANIFEST: list[tuple[str, str, int]] = [
	(
		"potential_assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_05.png",
		"assets/ui/icons/icon_attack.png",
		16,
	),
	(
		"potential_assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_07.png",
		"assets/ui/icons/icon_dash.png",
		16,
	),
]


def _resize_icon(src_rel: str, dst_rel: str, size: int) -> None:
	src = REPO_ROOT / src_rel
	dst = PROJECT_ROOT / dst_rel
	if not src.is_file():
		raise FileNotFoundError(src)
	dst.parent.mkdir(parents=True, exist_ok=True)
	with Image.open(src) as img:
		img.convert("RGBA").resize((size, size), Image.LANCZOS).save(dst)
	print(f"{src_rel} -> {dst_rel} (resized {size}x{size})")


# M5 H1: CONTROLLER-ITERATION PLACEHOLDERS -- no Tiny Swords asset (either
# pack) has a fire/frost/burst-strike glyph, so these four combat-skill icons
# (data/skills.json "icon" ids) are code-drawn flat glyphs, not extracted
# art. Colors intentionally match the existing cast-flash constants in
# combat_screen.gd (FLAME_FLASH/FROST_FLASH) so the hotbar icon and the
# in-board cast flash read as the same spell. Flag: replace with real art at
# the next controller pass (see report).
PLACEHOLDER_ICONS: list[tuple[str, str, tuple[int, int, int], tuple[int, int, int]]] = [
	# power_strike: an upward gold chevron ("everything behind one blow").
	("chevron", "assets/ui/icons/icon_power_strike.png", (230, 180, 40), (120, 30, 10)),
	# flame_bolt: a single orange flame droplet.
	("flame", "assets/ui/icons/icon_flame_bolt.png", (255, 115, 38), (130, 40, 5)),
	# flame_jet: a double orange chevron ("roars down the line").
	("jet", "assets/ui/icons/icon_flame_jet.png", (255, 115, 38), (130, 40, 5)),
	# frost_bolt: a light-blue shard.
	("shard", "assets/ui/icons/icon_frost_bolt.png", (128, 204, 255), (20, 70, 110)),
	# --- M6 T6 class-kit icons (same placeholder policy as M5 H1; replace
	# with real art at a future controller pass). Families share a palette:
	# sword = steel silver, spear = bronze, ice = frost blue (matches
	# FROST_FLASH), fire = flame orange (matches FLAME_FLASH), heal = green.
	# second_wind: a green recovery cross.
	("plus", "assets/ui/icons/icon_second_wind.png", (110, 200, 120), (35, 100, 50)),
	# piercing_strikes: a narrow bronze spearhead.
	("spearhead", "assets/ui/icons/icon_piercing_strikes.png", (205, 160, 90), (95, 60, 20)),
	# quick_slash: a single thin diagonal slash.
	("slash", "assets/ui/icons/icon_quick_slash.png", (200, 205, 215), (70, 75, 90)),
	# flash_cut: a crossed pair of slashes.
	("cross_slash", "assets/ui/icons/icon_flash_cut.png", (200, 205, 215), (70, 75, 90)),
	# devastating_slash: a wide downward arc wedge.
	("arc_slash", "assets/ui/icons/icon_devastating_slash.png", (200, 205, 215), (70, 75, 90)),
	# triple_thrust: three stacked right-pointing thrusts.
	("trident", "assets/ui/icons/icon_triple_thrust.png", (205, 160, 90), (95, 60, 20)),
	# extended_sweep: one long horizontal reach with a point.
	("sweep", "assets/ui/icons/icon_extended_sweep.png", (205, 160, 90), (95, 60, 20)),
	# spear_flurry: a fan of points from the bottom corner.
	("fan", "assets/ui/icons/icon_spear_flurry.png", (205, 160, 90), (95, 60, 20)),
	# ice_shard: a paired shard cluster (distinct from frost_bolt's lone shard).
	("shards", "assets/ui/icons/icon_ice_shard.png", (128, 204, 255), (20, 70, 110)),
	# icy_floor: a flat glazed floor rhombus.
	("floor", "assets/ui/icons/icon_icy_floor.png", (170, 220, 245), (60, 110, 150)),
	# flame_scythe: an orange crescent arc.
	("crescent", "assets/ui/icons/icon_flame_scythe.png", (255, 115, 38), (130, 40, 5)),
	# flare_burst: a four-point orange star.
	("burst", "assets/ui/icons/icon_flare_burst.png", (255, 170, 60), (150, 60, 10)),
	# keener_edge: an upright blade with a pale mana sheen.
	("edge", "assets/ui/icons/icon_keener_edge.png", (170, 230, 230), (50, 100, 110)),
	# --- Three Pillars PF (VISUAL-LOG drain): FIELD-skill icons. Same code-drawn
	# glyph policy as every combat-skill icon above (this project's shipped skill-
	# icon fidelity bar); the field hotbar (field_hotbar.gd) reuses WIHotbar's
	# icon slot exactly like combat, so a `field: true` skill needed an `icon`
	# id + a sprite to stop falling back to the overflowing text label. A future
	# unified art pass can upgrade ALL skill icons (combat + field) to real
	# Admurin art in one sweep -- see docs/VISUAL-LOG.md. Palette is chosen to
	# read as UTILITY (not spell): each field skill gets a distinct semantic
	# glyph + hue so the bar reads at a glance.
	# basic_cleaning: a broom (handle + bristles), soap-teal.
	("broom", "assets/ui/icons/icon_basic_cleaning.png", (150, 200, 205), (50, 90, 100)),
	# light: a radiant sun, warm gold.
	("sun", "assets/ui/icons/icon_light.png", (255, 220, 90), (180, 130, 20)),
	# basic_cooking: a cooking pot, copper-brown.
	("pot", "assets/ui/icons/icon_basic_cooking.png", (175, 125, 80), (85, 55, 25)),
	# observe: an eye, pale blue.
	("eye", "assets/ui/icons/icon_observe.png", (205, 225, 245), (60, 90, 130)),
	# soothe_clientele: a heart, soft rose.
	("heart", "assets/ui/icons/icon_soothe_clientele.png", (230, 130, 150), (140, 50, 70)),
	# unerring_aim: a bullseye target, red.
	("target", "assets/ui/icons/icon_unerring_aim.png", (220, 80, 70), (110, 25, 20)),
	# sweep_the_tables: a clean-shine sparkle, green.
	("sparkle", "assets/ui/icons/icon_sweep_the_tables.png", (150, 205, 150), (50, 110, 60)),
	# servers_prescience: an hourglass (foresight/timing), violet.
	("hourglass", "assets/ui/icons/icon_servers_prescience.png", (195, 165, 225), (95, 60, 135)),
	# --- Social Pillar S3 ([Diplomat] kit): same code-drawn glyph policy. Canon
	# names carried into the game's [Diplomat] kit -- [Charming Smile] (Lyonette's,
	# advances to [Enthralling Glance]) and [Calming Touch] (a low-level [Carer]
	# skill "that calms the target"); [Friendly Face]/[Calming Words] failed the
	# wiki canon-check, these are the flagged closest-canon substitutions.
	# charming_smile (field): a warm smile-arc + two eyes, golden-amber.
	("smile", "assets/ui/icons/icon_charming_smile.png", (245, 205, 120), (170, 110, 40)),
	# calming_touch (combat): concentric calm ripples, soft desaturated teal.
	("ripple", "assets/ui/icons/icon_calming_touch.png", (150, 195, 205), (55, 95, 110)),
]


def _draw_placeholder(shape: str, dst_rel: str, fill: tuple[int, int, int], outline: tuple[int, int, int]) -> None:
	size = 16
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	if shape == "chevron":
		draw.polygon([(8, 2), (14, 12), (8, 9), (2, 12)], fill=fill, outline=outline)
	elif shape == "flame":
		draw.polygon([(8, 1), (12, 8), (10, 14), (6, 14), (4, 8)], fill=fill, outline=outline)
	elif shape == "jet":
		draw.polygon([(1, 8), (7, 3), (7, 7), (13, 3), (13, 8), (7, 13), (7, 9)], fill=fill, outline=outline)
	elif shape == "shard":
		draw.polygon([(8, 1), (13, 8), (8, 15), (3, 8)], fill=fill, outline=outline)
	elif shape == "plus":
		draw.polygon(
			[(6, 2), (10, 2), (10, 6), (14, 6), (14, 10), (10, 10), (10, 14), (6, 14), (6, 10), (2, 10), (2, 6), (6, 6)],
			fill=fill, outline=outline,
		)
	elif shape == "spearhead":
		draw.polygon([(8, 1), (11, 8), (9, 7), (9, 14), (7, 14), (7, 7), (5, 8)], fill=fill, outline=outline)
	elif shape == "slash":
		draw.polygon([(2, 13), (12, 2), (14, 4), (4, 15)], fill=fill, outline=outline)
	elif shape == "cross_slash":
		draw.polygon([(2, 12), (12, 1), (14, 3), (4, 14)], fill=fill, outline=outline)
		draw.polygon([(13, 12), (3, 1), (1, 3), (11, 14)], fill=fill, outline=outline)
	elif shape == "arc_slash":
		draw.polygon([(1, 3), (8, 12), (15, 3), (13, 12), (8, 15), (3, 12)], fill=fill, outline=outline)
	elif shape == "trident":
		for y in (3, 8, 13):
			draw.polygon([(2, y - 1), (10, y - 1), (10, y - 2), (14, y), (10, y + 2), (10, y + 1), (2, y + 1)], fill=fill, outline=outline)
	elif shape == "sweep":
		draw.polygon([(1, 7), (11, 7), (11, 5), (15, 8), (11, 11), (11, 9), (1, 9)], fill=fill, outline=outline)
	elif shape == "fan":
		draw.polygon([(2, 14), (3, 3), (6, 4), (4, 12)], fill=fill, outline=outline)
		draw.polygon([(2, 14), (9, 2), (12, 4), (5, 13)], fill=fill, outline=outline)
		draw.polygon([(2, 14), (13, 8), (14, 11), (4, 15)], fill=fill, outline=outline)
	elif shape == "shards":
		draw.polygon([(5, 1), (9, 7), (5, 13), (1, 7)], fill=fill, outline=outline)
		draw.polygon([(11, 5), (15, 10), (11, 15), (7, 10)], fill=fill, outline=outline)
	elif shape == "floor":
		draw.polygon([(8, 6), (15, 10), (8, 14), (1, 10)], fill=fill, outline=outline)
	elif shape == "crescent":
		draw.polygon(
			[(4, 2), (10, 3), (14, 8), (10, 13), (4, 14), (9, 12), (11, 8), (9, 4)],
			fill=fill, outline=outline,
		)
	elif shape == "burst":
		draw.polygon(
			[(8, 1), (10, 6), (15, 8), (10, 10), (8, 15), (6, 10), (1, 8), (6, 6)],
			fill=fill, outline=outline,
		)
	elif shape == "edge":
		draw.polygon([(8, 1), (11, 5), (11, 12), (8, 15), (5, 12), (5, 5)], fill=fill, outline=outline)
		draw.polygon([(7, 3), (8, 6), (7, 12), (6, 8)], fill=(240, 252, 252), outline=None)
	elif shape == "broom":
		# diagonal handle + a splayed bristle trapezoid at the foot.
		draw.polygon([(11, 1), (13, 3), (7, 10), (5, 8)], fill=fill, outline=outline)
		draw.polygon([(4, 8), (9, 8), (12, 15), (1, 15)], fill=fill, outline=outline)
	elif shape == "sun":
		# central disc + four cardinal rays.
		draw.ellipse([5, 5, 10, 10], fill=fill, outline=outline)
		draw.polygon([(7, 0), (9, 0), (8, 4)], fill=fill, outline=outline)
		draw.polygon([(7, 15), (9, 15), (8, 11)], fill=fill, outline=outline)
		draw.polygon([(0, 7), (0, 9), (4, 8)], fill=fill, outline=outline)
		draw.polygon([(15, 7), (15, 9), (11, 8)], fill=fill, outline=outline)
	elif shape == "pot":
		# rim + tapered body + a lid knob.
		draw.rectangle([2, 6, 13, 8], fill=fill, outline=outline)
		draw.polygon([(3, 8), (12, 8), (11, 14), (4, 14)], fill=fill, outline=outline)
		draw.rectangle([7, 3, 8, 5], fill=fill, outline=outline)
	elif shape == "eye":
		# almond outline + dark pupil.
		draw.polygon([(1, 8), (8, 3), (15, 8), (8, 13)], fill=fill, outline=outline)
		draw.ellipse([6, 6, 10, 10], fill=outline, outline=outline)
	elif shape == "heart":
		draw.polygon(
			[(8, 14), (1, 7), (1, 4), (4, 2), (8, 5), (12, 2), (15, 4), (15, 7)],
			fill=fill, outline=outline,
		)
	elif shape == "target":
		# concentric bullseye: outer disc, white ring, dark centre.
		draw.ellipse([1, 1, 14, 14], fill=fill, outline=outline)
		draw.ellipse([5, 5, 10, 10], fill=(250, 250, 250), outline=outline)
		draw.ellipse([7, 7, 8, 8], fill=outline, outline=outline)
	elif shape == "sparkle":
		# four-point clean-shine sparkle + two small twinkles.
		draw.polygon([(8, 1), (9, 7), (15, 8), (9, 9), (8, 15), (7, 9), (1, 8), (7, 7)], fill=fill, outline=outline)
		draw.ellipse([1, 2, 3, 4], fill=fill, outline=outline)
		draw.ellipse([12, 11, 14, 13], fill=fill, outline=outline)
	elif shape == "hourglass":
		draw.polygon([(3, 2), (13, 2), (8, 8)], fill=fill, outline=outline)
		draw.polygon([(8, 8), (3, 14), (13, 14)], fill=fill, outline=outline)
		draw.rectangle([2, 1, 13, 2], fill=fill, outline=outline)
		draw.rectangle([2, 14, 13, 15], fill=fill, outline=outline)
	elif shape == "smile":
		# two eyes + an upward smile arc (a warm, disarming face).
		draw.ellipse([4, 5, 6, 7], fill=outline, outline=outline)
		draw.ellipse([9, 5, 11, 7], fill=outline, outline=outline)
		draw.arc([3, 4, 12, 13], start=25, end=155, fill=outline, width=2)
		draw.arc([4, 5, 11, 12], start=30, end=150, fill=fill, width=1)
	elif shape == "ripple":
		# concentric calm ripples spreading from a still centre.
		draw.ellipse([1, 1, 14, 14], fill=None, outline=outline, width=1)
		draw.ellipse([4, 4, 11, 11], fill=None, outline=fill, width=1)
		draw.ellipse([6, 6, 9, 9], fill=fill, outline=outline)
	else:
		raise ValueError(f"unknown placeholder shape: {shape}")
	dst = PROJECT_ROOT / dst_rel
	dst.parent.mkdir(parents=True, exist_ok=True)
	img.save(dst)
	print(f"(generated) -> {dst_rel}")


def main() -> None:
	for src_rel, dst_rel in MANIFEST:
		src = REPO_ROOT / src_rel
		dst = PROJECT_ROOT / dst_rel
		if not src.is_file():
			raise FileNotFoundError(src)
		dst.parent.mkdir(parents=True, exist_ok=True)
		shutil.copy2(src, dst)
		print(f"{src_rel} -> {dst_rel}")
	for src_rel, dst_rel, size in ICON_MANIFEST:
		_resize_icon(src_rel, dst_rel, size)
	for shape, dst_rel, fill, outline in PLACEHOLDER_ICONS:
		_draw_placeholder(shape, dst_rel, fill, outline)


if __name__ == "__main__":
	main()
