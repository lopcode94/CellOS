extends RefCounted
## The Tension Dial. ATP output vs. the host's demand drives two opposing meters:
##   starve the host  -> Host_Digestion_Meter climbs (acid floods the engine room)
##   overfeed it      -> Mutation_Instability_Index climbs (wild limbs sprout)
## Free radicals (ROS) leak instability no matter which way the needle points.
##
##   atp_rate  : exponentially-windowed ATP delivered per second (tau = 6 s)
##   demand    : (base(gen) + 0.22 * speed_frac) * mutation multiplier
##   ratio     : atp_rate / demand    sweet spot = [1.0, 1.35]
##   dDigest/dt = K_DIGEST * max(0, demand - atp)  - K_RELIEF * min(surplus, demand) - drain
##   dInstab/dt = K_MUTATE * max(0, atp - 1.35 * demand) + K_ROS * radicals - K_HEAL

const TAU_ATP := 6.0
const K_DIGEST := 12.0
const K_RELIEF := 10.0
const K_DRAIN := 0.5
const SWEET_LOW := 1.0
const SWEET_HIGH := 1.35
const K_MUTATE := 14.0
const K_ROS := 1.1
const K_HEAL := 1.5

var atp_rate := 0.0
var demand := 0.5
var digestion := 0.0
var instability := 0.0
var ros := 0.0


func prime(d: float) -> void:
	demand = d
	atp_rate = d * 1.1


## One ATP canister of `amount` charge arrived at the nucleus.
func deliver(amount: float) -> void:
	atp_rate += amount / TAU_ATP


func ratio() -> float:
	return atp_rate / maxf(demand, 0.01)


## Speed multiplier for the host: sluggish when starving, a little turbo when overfed.
func energy_factor() -> float:
	return clampf(0.55 + 0.45 * ratio(), 0.55, 1.3)


func step(dt: float, base_demand: float, speed_frac: float, radicals: int, demand_mult: float) -> void:
	atp_rate *= exp(-dt / TAU_ATP)
	demand = (base_demand + 0.22 * speed_frac) * demand_mult
	var deficit := demand * SWEET_LOW - atp_rate
	if deficit > 0.0:
		digestion += K_DIGEST * deficit * dt
	else:
		digestion -= (K_RELIEF * minf(-deficit, demand) + K_DRAIN) * dt
	ros = float(radicals)
	var surplus := maxf(0.0, atp_rate - demand * SWEET_HIGH)
	instability += (K_MUTATE * surplus + K_ROS * ros - K_HEAL) * dt
	digestion = clampf(digestion, 0.0, 100.0)
	instability = clampf(instability, 0.0, 100.0)
