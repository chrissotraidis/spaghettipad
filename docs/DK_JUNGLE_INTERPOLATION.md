# Jungle Parkway tree interpolation

[Issue #7](https://github.com/chrissotraidis/spaghettipad/issues/7) reports trees
jumping into the foreground. The supplied report has no confirmed frame-rate,
texture-pack, or 30-FPS comparison result. The following fix addresses a
reproduced source defect; reporter/device confirmation remains open.

`render_palm_trees()` previously keyed interpolation by a count of rendered
trees. Hidden or culled spawn entries did not increment that count. When an
earlier tree became invisible, later trees inherited different IDs, allowing
interpolation to associate transforms from different trees across frames.

The patch derives the ID from the entry's position in the spawn array while
retaining the camera bits. Geometry, visibility, textures, drawing order and
matrix-stack handling stay the same. This is a focused fix at the existing
engine revision, without an upstream upgrade.

Run after source preparation:

```sh
python3 scripts/test-palm-tree-interpolation.py
```

The test compiles the actual function from the prepared `actors.c` with mocked
visibility and draw capture. The unmodified function fails when an earlier
tree is culled. The changed function passes culling, hidden-tree, restored-tree,
four-camera separation, culling-disabled and matrix-pool exhaustion cases.
The fixture does not emulate Metal or run a race. CI runs it against the same
prepared source used by the device build.

Before closing the reported visual problem, compare the same Jungle Parkway
section at 30 FPS and 60/120 FPS with the same game data and texture settings,
then compare baseline and candidate builds. Record exact build identities and
whether the foreground-tree artifact disappears. No physical device was
installed or tested for this change.
