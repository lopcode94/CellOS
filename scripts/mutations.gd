extends RefCounted
## Mutation cards offered at every MITOSIS. Every card is a trade-off; mtDNA banked
## across runs unlocks more of them.

const CARDS := {
	"cilia": {
		"name": "Turbo-Cilia Exhaust", "type": "PASSIVE", "unlock": 0, "color": "ff8a2b",
		"pro": "35% more top speed and thrust.",
		"con": "Cruising fast farts Free Radicals into your engine room.",
	},
	"lysosome": {
		"name": "Crying Lysosome Cannon", "type": "ACTIVE", "unlock": 0, "color": "3fc6ff",
		"pro": "Press CRY (or E) to fire acid tears that pop viruses and rivals.",
		"con": "Every sob leaks an acid puddle into the cytoplasm.",
	},
	"spicy": {
		"name": "Spicy Cytoplasm Membrane", "type": "PASSIVE", "unlock": 0, "color": "ff4a3d",
		"pro": "Viruses that touch you get fried on contact.",
		"con": "Host is 20% hungrier and the membrane gets EXTRA bouncy.",
	},
	"vacuole": {
		"name": "Gluttonous Vacuole", "type": "PASSIVE", "unlock": 0, "color": "c77dff",
		"pro": "Every snack is worth double fuel.",
		"con": "Host gets lazy: -20% speed, and the conveyor clogs twice as often.",
	},
	"antiox": {
		"name": "Antioxidant Sprinkles", "type": "PASSIVE", "unlock": 60, "color": "5cd65c",
		"pro": "40% fewer Free Radicals.",
		"con": "ATP canisters hold 15% less charge.",
	},
	"magnet": {
		"name": "Magnetic Membrane", "type": "PASSIVE", "unlock": 0, "color": "2fd8ff",
		"pro": "ATP canisters that drift near the nucleus get sucked straight in.",
		"con": "Viruses can smell you from much farther away.",
	},
	"vacuum": {
		"name": "Hoover Pseudopods", "type": "PASSIVE", "unlock": 80, "color": "9dff2e",
		"pro": "Nearby snacks get slurped toward you.",
		"con": "So do nearby viruses.",
	},
	"volatile": {
		"name": "Volatile ATP", "type": "PASSIVE", "unlock": 200, "color": "ff3fb4",
		"pro": "ATP bombs blast twice as wide and refund half a canister of ATP.",
		"con": "Every bomb you launch adds +4 Mutation.",
	},
	"rubbernuc": {
		"name": "Rubber Nucleus", "type": "PASSIVE", "unlock": 150, "color": "a24fd6",
		"pro": "The nucleus catches canisters from much farther away.",
		"con": "It burps 1 in 6 canisters right back at you.",
	},
}

const FILLERS := {
	"snack": {
		"name": "Emergency Snack Pack", "type": "INSTANT", "color": "ffc93d",
		"pro": "Refill the mitochondrion's fuel tank.",
		"con": "Tastes like pond.",
	},
	"patch": {
		"name": "Membrane Patch Kit", "type": "INSTANT", "color": "6fc8ff",
		"pro": "-30 Digestion and -30 Mutation, right now.",
		"con": "It's literally a band-aid.",
	},
}


static func info(id: String) -> Dictionary:
	if CARDS.has(id):
		return CARDS[id]
	return FILLERS.get(id, {})


static func unlocked(mtdna: int) -> Array:
	var out := []
	for id in CARDS:
		if int(CARDS[id]["unlock"]) <= mtdna:
			out.append(id)
	return out


static func roll(owned: Array, mtdna: int, n: int = 3) -> Array:
	var avail := unlocked(mtdna).filter(func(id): return not owned.has(id))
	avail.shuffle()
	var out := avail.slice(0, n)
	var fill := FILLERS.keys()
	fill.shuffle()
	while out.size() < n and not fill.is_empty():
		out.append(fill.pop_back())
	return out


static func newly_unlocked(before: int, after: int) -> Array:
	var out := []
	for id in CARDS:
		var u := int(CARDS[id]["unlock"])
		if u > before and u <= after:
			out.append(CARDS[id]["name"])
	return out
