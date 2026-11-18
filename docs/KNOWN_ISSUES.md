# Known issues

## Guest focus-loss RPC during return to the main menu

**Status:** Fix implemented; retained focused source/package lifecycle verification. Full current acceptance remains scoped below. Originally recorded 2026-11-12; reconciled 2026-11-18.

When a connected guest leaves the session or the host disconnects, the title transition can log `RPC 'submit_combat' on yourself is not allowed by selected mode.` Headless source runs `ac02-source-leave-session` and `ac02-host-disconnect` each produced three instances. Packaged run `ac02-title-control-02` reproduced the same error.

[`game.gd::return_to_main_menu()`](../game.gd) replaces ENet with an offline peer and adds the menu while the outgoing world still has its `Guest` session state. Adding the menu dispatches a focus-loss notification to the old world. The pre-fix [`mouse_combat.gd::release()`](../mouse_combat.gd) then tried to send `submit_combat` to the host ID, which is now the local peer ID.

The current release handler requires a live host transport, a local ID different from the host and a connected host peer before sending the release RPC. The [Group 3C lifecycle report](AC06_B0_WRITER_GROUP_3C.md) records the reproduction, fix, and successful real-title source/package leave/reconnect and host shutdown runs; exact retained verdicts are in its linked evidence index. This is a fixed path with retained evidence, not an unexplained open defect.

The broader AC-02 acceptance still requires current growth receipt/reconnect coverage and confirmation that ordinary rendered focus loss releases held input while connected. No fresh manual, separate-PC or internet result is claimed here. Historical failed logs remain preserved.
