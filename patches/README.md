# Historical wrapper patches

These ten files record the pre-migration SpaghettiPad changes at
`2f7a54ee16a55c5c394c5907e83ab0ad7d3c66e3`. They are retained for comparison and
rollback. Ordinary builds do not replay them; `scripts/apply-patches.sh` is a
compatibility entry point that verifies maintained source pins.

The seven `spaghettikart-*` patches map to engine commit
`67bb88c07c4c7c0b769286bc93dc0e39c9caec5c`. The three `libultraship-*` patches map
to libultraship commit `bd9c2dde3f92bb260f49350048c261a02050023f`.
Both preserve their recorded upstream ancestry. See
[the maintenance guide](../docs/SOURCE_MAINTENANCE.md) for the selected graph,
update procedure and remaining boundaries. New fixes belong in ordinary
source commits, rather than additional wrapper patches.
