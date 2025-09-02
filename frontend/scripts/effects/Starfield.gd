extends Control

@export var star_count: int = 200
@export var star_speed: float = 100.0

var stars = []

func _ready():
	randomize()
	_generate_stars()

func _generate_stars():
	stars.clear()
	for i in range(star_count):
		stars.append({
			"position": Vector2(randf() * size.x, randf() * size.y),
			"brightness": randf_range(0.3, 1.0),
			"size": randf_range(1.0, 3.0),
			"twinkle_phase": randf() * PI * 2
		})
	queue_redraw()

func _process(delta):
	for star in stars:
		star.position.y += star_speed * delta
		if star.position.y > size.y:
			star.position.y = 0
			star.position.x = randf() * size.x
		star.twinkle_phase += delta * 2
	queue_redraw()

func _draw():
	for star in stars:
		var brightness = star.brightness * (0.8 + 0.2 * sin(star.twinkle_phase))
		var color = Color(brightness, brightness * 0.9, brightness * 1.1, brightness)
		draw_circle(star.position, star.size, color)
