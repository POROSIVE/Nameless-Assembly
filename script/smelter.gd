extends Node

@export var activated : bool = false

@export_group("process duration")
@export var thinMetal : float = 1.0

@export_group("Debug")
@export var disable_process_time : bool = false
@export var total_output : int = 1

var isUnlocked = true
