## The emotes: name shown in the game, the animation clip in emotes.glb, and whether it
## loops (loops keep going until you move or fire).

const FILE := "res://assets/characters/human/emotes.glb"
const FALLBACK := "CharacterArmature|Wave"  # used while a clip is missing
const LIST := [
	{"id": "wave", "name": "Wave", "clip": "Emote_Wave", "loop": false},
	{"id": "salute", "name": "Salute", "clip": "Emote_Salute", "loop": false},
	{"id": "clap", "name": "Clap", "clip": "Emote_Clap", "loop": true},
	{"id": "thumbs_up", "name": "Thumbs up", "clip": "Emote_ThumbsUp", "loop": false},
	{"id": "cheer", "name": "Cheer", "clip": "Emote_Cheer", "loop": false},
	{"id": "flex", "name": "Flex", "clip": "Emote_Flex", "loop": false},
	{"id": "shrug", "name": "Shrug", "clip": "Emote_Shrug", "loop": false},
	{"id": "bow", "name": "Bow", "clip": "Emote_Bow", "loop": false},
	{"id": "dance", "name": "Dance", "clip": "Emote_Dance", "loop": true},
	{"id": "laugh", "name": "Laugh", "clip": "Emote_Laugh", "loop": false},
]
