# Filter Rules

Turns out there is a better way to do this. We can use restrictive approach instead of trying to account for all the cases.
The settings are as follows:

* Enable Auto-Eject
* Set default to Dark Green
* Define following restrictive rules (this list might expand in the future)

Restricted items:

* dirt (item stack)
* gravel
* blockMarble
* blockGranite
* blockDiorite
* blockLimestone
* sandstone
* stone*
* blockAndesite
* crop*
* shard*
* cobblestone
* gemAmber

---

Logistical pipes chose the shortest path available so the first empty `bin` will be the one chosen. Only if the non-empty bin with the corresponding material inside is the closest will it be used. Thus it makes sense to design a system where path to each bin is more or less equal, so an empty bin is never chosen over a partially filled one for a given mat.