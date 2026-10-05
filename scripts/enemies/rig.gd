## Bone names of the character skeleton (MakeHuman's "game_engine" rig, Unreal style), kept
## in one place so a new rig only changes this file. Sides are "L" / "R" in the game code.

const HEAD := "head"
const NECK := "neck_01"
# Finger joints that bend when gripping, knuckle to tip.
const FINGERS := [["index_01", "index_02", "index_03"], ["middle_01", "middle_02", "middle_03"],
		["ring_01", "ring_02", "ring_03"], ["pinky_01", "pinky_02", "pinky_03"], ["thumb_02", "thumb_03"]]
const THUMB := 4  # index of the thumb in FINGERS


static func upper_arm(side: String) -> String:
	return "upperarm_" + side.to_lower()


static func lower_arm(side: String) -> String:
	return "lowerarm_" + side.to_lower()


static func hand(side: String) -> String:
	return "hand_" + side.to_lower()


## First knuckle of a finger (the joint the finger bends from).
static func knuckle(finger: int, side: String) -> String:
	return finger_bone(FINGERS[finger][0], side)


static func finger_bone(joint: String, side: String) -> String:
	return joint + "_" + side.to_lower()
