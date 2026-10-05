## Ray and box maths for shots: does a ray from the eye hit a sphere (head), a capsule
## (body), and which face of a box did it land on.


static func ray_hits_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> bool:
	var to_center := center - origin
	var along := to_center.dot(dir)
	if along < 0.0:
		return false
	return to_center.length_squared() - along * along <= radius * radius


## Capsule given by its two end points (any direction, so it follows a falling body).
static func ray_hits_capsule(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, radius: float) -> bool:
	return segment_distance_sq(origin, origin + dir * 100.0, a, b) <= radius * radius


## The outward normal of the box face nearest to `at`.
static func box_face(box: AABB, at: Vector3) -> Vector3:
	var faces := [
		[absf(at.x - box.position.x), Vector3.LEFT], [absf(at.x - box.end.x), Vector3.RIGHT],
		[absf(at.y - box.position.y), Vector3.DOWN], [absf(at.y - box.end.y), Vector3.UP],
		[absf(at.z - box.position.z), Vector3.FORWARD], [absf(at.z - box.end.z), Vector3.BACK]]
	faces.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	return faces[0][1]


## Squared distance between segments p1-q1 and p2-q2 (Ericson, Real-Time Collision Detection 5.1.9).
static func segment_distance_sq(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var c := d1.dot(r)
	var b := d1.dot(d2)
	var denom := a * e - b * b
	var s := clampf((b * f - c * e) / denom, 0.0, 1.0) if denom != 0.0 else 0.0
	var t := (b * s + f) / e
	if t < 0.0:
		t = 0.0
		s = clampf(-c / a, 0.0, 1.0)
	elif t > 1.0:
		t = 1.0
		s = clampf((b - c) / a, 0.0, 1.0)
	return ((p1 + d1 * s) - (p2 + d2 * t)).length_squared()
