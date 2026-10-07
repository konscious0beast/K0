extends Node
## Router test fixture (test_m0_router): a screen that only records the screen contract calls (02_TECH §9.2).
## Lets the Router tests run independently of the real screens of M3/M5/M6.

var params: Dictionary = {}
var calls: Array[String] = []
var payloads: Array[Dictionary] = []


func setup(p: Dictionary) -> void:
	params = p
	calls.append("setup")


func on_suspend() -> void:
	calls.append("suspend")


func on_resume(payload: Dictionary) -> void:
	payloads.append(payload)
	calls.append("resume")
