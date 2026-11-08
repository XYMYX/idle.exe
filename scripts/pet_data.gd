class_name PetData
extends RefCounted
## Pets: pure decoration, adopted once in the terminal («Pets»), kept when the company is sold.
##
## kind:   walker = walks around like the cat (cat.gd with its own sprite set)
##         desk   = sits on the desk (drawn by desk.gd)
##         corner = stands in the pet corner on the floor, left of the room (drawn by desk.gd)
##         toy    = the wind-up robot toy (robo_toy.gd)
## The cat is stored in Game.cat (older saves), all others in Game.pets.

const PETS := [
	{"id": "duck", "name": "Rubber duck", "cost": 500.0, "kind": "desk",
		"desc": "Sits on the desk and listens to every bug. Click: squeak."},
	{"id": "cat", "name": "Cat", "cost": 1000.0, "kind": "walker",
		"desc": "Walks around, sleeps, joins XYMYX on his walks."},
	{"id": "robo_toy", "name": "Robot toy", "cost": 5000.0, "kind": "toy",
		"desc": "A wind-up robot. When the battery is empty it falls over. Click: wind it up."},
	{"id": "hamster", "name": "Hamster", "cost": 25000.0, "kind": "corner",
		"desc": "Runs in its wheel, eats and sleeps in its cage."},
	{"id": "dog", "name": "Dog", "cost": 250000.0, "kind": "walker",
		"desc": "Wags its tail, barks at the mouse, follows XYMYX."},
	{"id": "aquarium", "name": "Aquarium", "cost": 2.5e6, "kind": "corner",
		"desc": "Fish and bubbles under a purple LED."},
	{"id": "elephant", "name": "Baby elephant", "cost": 50.0e6, "kind": "walker",
		"desc": "Small, curious, trumpets at the mouse."},
]


static func get_pet(id: String) -> Dictionary:
	for p: Dictionary in PETS:
		if p["id"] == id:
			return p
	return {}
