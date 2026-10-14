class_name PaintLayer
extends Node2D
## A drawing layer: its _draw hands itself to a painter (the main node points its drawing helpers at it).

var painter: Callable


func _draw() -> void:
	painter.call(self)
