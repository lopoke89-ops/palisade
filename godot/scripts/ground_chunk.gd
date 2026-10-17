class_name GroundChunk
extends Node2D
## A piece of the painted ground (and, in the city, its buildings), drawn once and kept: the camera only moves the
## parent. Redrawn when the terrain or the zoom changes. Godot culls the pieces that are off screen.

var m   # the main node: it paints into whichever chunk is drawing
var i0 := 0
var j0 := 0
var n := 0
var back := false   # the land outside the fence


func _draw() -> void:
	m.paint_chunk(self)
