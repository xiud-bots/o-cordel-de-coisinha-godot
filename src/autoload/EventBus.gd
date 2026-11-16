extends Node

signal scene_change_requested(scene_id: String)
signal scene_changed(scene_id: String)

signal item_unlocked(item_id: String)
signal bush_item_unlocked(item_id: String)

signal player_hp_changed(current_hp: int, max_hp: int)
signal player_died()
signal player_name_changed(new_name: String)

signal npc_first_contact(npc_id: String)
signal dialogue_requested(dialogue_data: Dictionary)
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)

signal stage_reset_requested()
signal game_paused_changed(is_paused: bool)

signal juice_shake_requested(trauma: float)
signal juice_hitstop_requested(duration: float)
signal narrative_leaflet_requested(title: String, verses: PackedStringArray)
