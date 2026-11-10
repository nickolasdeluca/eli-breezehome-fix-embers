# Elianora's Breezehome Overhaul – Embers XD Firepit Fix

A tiny compatibility patch for people running **Elianora's Breezehome Overhaul (EBO)** together with
**Embers XD** and **Lux**.

## The problem

EBO removes Breezehome's central firepit, puts a coffee table there and reuses the fire for its new
wall fireplace. Two plugins put fire effects back in the old spot:

- `Lux - Embers XD patch.esp` (Lux Patch Hub) loads after `Eli_Breezehome.esp` and moves three of the
  vanilla firepit references (fire and embers) back to the middle of the room.
- `Embers XD.esp` adds one extra ember effect at the firepit that EBO does not know about, so it is
  never disabled.

In game you get sparks and smoke rising out of the coffee table, and EBO's fireplace has no fire.

## What the patch does

Inside the Breezehome interior cell (`WhiterunBreezehome`, `000165A8`) it overrides four references and
nothing else:

| Reference | Change |
|---|---|
| `Skyrim.esm:0CB48D` | Restored to EBO's version (fire in the wall fireplace) |
| `Skyrim.esm:0CB48E` | Restored to EBO's version (disabled) |
| `Skyrim.esm:10C063` | Restored to EBO's version (disabled) |
| `Embers XD.esp:0EE400` | Initially disabled |

No new records, no scripts. The plugin is ESL-flagged, so it does not use a full plugin slot.

## Requirements

- Elianora's Breezehome Overhaul, **EBO-3X** (`Eli_Breezehome.esp`)
- Embers XD (`Embers XD.esp`)

Lux is not a master. Without the Lux Patch Hub's Embers XD patch only the extra ember effect needs
fixing, and the patch still handles that.

## Load order

Load it **after** `Lux - Embers XD patch.esp` (and therefore after `Eli_Breezehome.esp` and
`Embers XD.esp`). EBO's own lighting patch, for example `Eli_Breezehome [PATCH - Lux].esp`, should
still load later than this one so it keeps winning the cell record.

## Tested with

Built against and tested in game with:

- Elianora's Breezehome Overhaul EBO-3X v3.4
- Embers XD v3.1.7
- Lux v7.0 and Lux Patch Hub v7.0
- Skyrim SE 1.5.97, on a Nolvus Awakening setup

Other versions are untested. The three restored references are copied from EBO-3X v3.4, so a later
EBO release that changes them would need a rebuild.

## Rebuilding

The plugin is generated from the two plugins it patches, so it can be rebuilt after an update:

```powershell
.\tools\build.ps1 -EliPlugin "<path>\Eli_Breezehome.esp" -EmbersPlugin "<path>\Embers XD.esp"
```

The script stops if either plugin has masters other than the five base game files, or if any of the
records it needs is missing.

## Credits

- Elianora and KhrysINXS for Elianora's Breezehome Overhaul
- mindflux for Embers XD
- GGUNIT for Lux
