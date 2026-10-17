class_name V3Fx
extends Node3D
## Effects in 3D (filled out in the effects pass): bullets, particles, flashes, kill effects.

const V3 = preload("res://scripts/view3d/view3d.gd")

var V
var sim: Sim
var m


func _init(view) -> void:
	V = view
	sim = view.sim
	m = view.m
	name = "Fx"


func clear() -> void:
	pass


func on_flash(_e: Dictionary) -> void:
	pass


func kill_effect(_x: float, _y: float, _id: String) -> void:
	pass


func frame(_dt: float) -> void:
	pass
