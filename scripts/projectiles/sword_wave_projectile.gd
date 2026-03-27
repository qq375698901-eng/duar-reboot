extends Projectile2D


func _ready() -> void:
	super._ready()
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")
