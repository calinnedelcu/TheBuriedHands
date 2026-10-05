# Sources of the lightened models

The full-density jam models the game no longer loads live here when you need
to rebuild their lighter versions (this folder has a `.gdignore`, so Godot
never imports them). They are kept out of the working tree to keep checkouts
small; restore them from history first:

```bash
git checkout a5ef3b0~1 -- TripoModels/Testamente.glb && mv TripoModels/Testamente.glb TripoModels/source/
git checkout d1d5ed4~1 -- scenes/items/MapWithoutTreasure.glb && mv scenes/items/MapWithoutTreasure.glb TripoModels/source/
```

(the second line overwrites the lightened map: rebuild it right after.)

- `Testamente.glb` -> `tools/blender/build_archive_lod.py` -> `assets/models/level/archive_scrolls.glb`
- `MapWithoutTreasure.glb` -> `tools/blender/build_map_lod.py` -> `scenes/items/MapWithoutTreasure.glb`
