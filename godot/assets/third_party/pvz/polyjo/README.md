# Optional PVZ-style model replacements

This folder is intentionally empty in the repository. The current game keeps
the procedural art as a safe fallback and loads a converted GLB only when the
matching file exists:

```text
sunflower.glb
peashooter.glb
wallnut.glb
snowpea.glb
repeater.glb
```

Candidate source: [Peashooter (Polyjo)](https://blockbenchworkshop.com/zh-Hans/model/polyjo/peashooter-polyjo). The related Polyjo PVZ list also includes sunflower, wall-nut, snow pea, repeater and other plants. The creator page currently states CC BY-NC 4.0: personal, non-commercial use only, with attribution and a note about changes. Re-check the live page before redistribution.

The source files are `.bbmodel`, so open them in Blockbench and export each one
as glTF 2.0 `.glb`. Keep the original `.bbmodel` outside the shipped game or in
an ignored source archive, and place the author/license text beside the final
GLB before using it in a release build.

The importer rotates the asset from Blockbench's usual `+Z` facing to the
game's `+X` plant facing. The imported root is used as the animation pivot;
gameplay behavior remains in `PlantUnit`.
