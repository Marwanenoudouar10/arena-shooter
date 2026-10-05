extends RefCounted
## One character blueprint. Every character is the same realistic man (made with MakeHuman,
## see assets/characters/human/) wearing one part per slot: head, top, legs, feet. BASE is
## the blueprint; each class starts from it and overrides only what is different; anything
## you wear on top (an outfit) overrides again. New clothing = one more entry in PARTS.
##
## The skeleton and its animations come from human_anims.glb; every part file is exported
## from the same rig, so any part fits any body.

const SKELETON_FILE := "res://assets/characters/human/human_anims.glb"
const PARTS_DIR := "res://assets/characters/human/parts/"
const SLOTS: Array[String] = ["Head", "Top", "Legs", "Feet"]
# part id -> {slot, label}; the file is PARTS_DIR + id + ".glb"
const PARTS := {
	"head_short": {"slot": "Head", "label": "Short hair"},
	"head_slick": {"slot": "Head", "label": "Slicked hair"},
	"top_tshirt": {"slot": "Top", "label": "T-shirt"},
	"top_polo": {"slot": "Top", "label": "Polo"},
	"top_sweater": {"slot": "Top", "label": "Sweater"},
	"top_jacket": {"slot": "Top", "label": "Jacket"},
	"legs_jeans": {"slot": "Legs", "label": "Jeans"},
	"legs_cargo": {"slot": "Legs", "label": "Cargo pants"},
	"feet_sneakers": {"slot": "Feet", "label": "Sneakers"},
	"feet_boots": {"slot": "Feet", "label": "Boots"},
	"feet_shoes": {"slot": "Feet", "label": "Shoes"},
}
const NODE_PREFIX := "Wear_"  # slot holders are Wear_Head etc. under the skeleton

const BASE := {"Head": "head_short", "Top": "top_tshirt", "Legs": "legs_jeans", "Feet": "feet_sneakers"}
const CLASS_LOOKS := {  # only what differs from BASE
	"Light": {},
	"Medium": {"Head": "head_slick", "Top": "top_polo", "Feet": "feet_boots"},
	"Heavy": {"Top": "top_jacket", "Legs": "legs_cargo", "Feet": "feet_shoes"},
}

static var _sources := {}  # file -> loaded scene (only read from, never shown)


## BASE, then the class, then whatever you chose to wear (e.g. {"Top": "top_jacket"}).
## Unknown parts (old saved settings) are ignored.
static func look_for(cls: String, wearing := {}) -> Dictionary:
	var look := BASE.duplicate()
	look.merge(CLASS_LOOKS.get(cls, {}), true)
	for slot in wearing:
		if fits(wearing[slot], slot):
			look[slot] = wearing[slot]
	return look


## True when `part` is a known part for `slot`.
static func fits(part: Variant, slot: String) -> bool:
	return part is String and PARTS.has(part) and PARTS[part]["slot"] == slot


## Build a character: the blueprint's skeleton (and its animations) wearing the look.
static func build(look: Dictionary, load_glb: Callable) -> Node3D:
	var root: Node3D = _source(SKELETON_FILE, load_glb).duplicate()
	dress(root, look, load_glb)
	return root


## Change clothes on a character that already exists. Each slot is a holder node under the
## skeleton (Wear_Head, ...) that keeps anything set on it, like hidden; only the meshes
## inside are swapped. Meshes get no shadows when the root has the meta "no_shadows".
static func dress(root: Node3D, look: Dictionary, load_glb: Callable) -> void:
	var skeleton := skeleton_of(root)
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if root.has_meta("no_shadows") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for slot in SLOTS:
		var part_id: String = look.get(slot, BASE[slot]) if fits(look.get(slot), slot) else BASE[slot]
		var holder := skeleton.get_node_or_null(NodePath(NODE_PREFIX + slot)) as Node3D
		if holder == null:
			holder = Node3D.new()
			holder.name = NODE_PREFIX + slot
			skeleton.add_child(holder)
		for old in holder.get_children():
			holder.remove_child(old)
			old.free()
		for source in _source(PARTS_DIR + part_id + ".glb", load_glb).find_children("*", "MeshInstance3D", true, false):
			var mesh := source as MeshInstance3D
			var part := MeshInstance3D.new()
			part.name = mesh.name
			part.mesh = mesh.mesh
			part.skin = mesh.skin
			part.skeleton = NodePath("../..")  # bend with the skeleton above the holder
			part.cast_shadow = shadows
			for i in mesh.get_surface_override_material_count():
				part.set_surface_override_material(i, mesh.get_surface_override_material(i))
			holder.add_child(part)
		holder.set_meta("outfit", part_id)


## What each slot currently wears (for tests and saving).
static func worn(root: Node3D) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var holder := skeleton_of(root).get_node_or_null(NodePath(NODE_PREFIX + slot))
		if holder and holder.has_meta("outfit"):
			out[slot] = holder.get_meta("outfit")
	return out


static func skeleton_of(root: Node) -> Skeleton3D:
	return root.find_children("*", "Skeleton3D", true, false)[0]


static func _source(file: String, load_glb: Callable) -> Node:
	if not _sources.has(file):
		_sources[file] = load_glb.call(file)
	return _sources[file]
