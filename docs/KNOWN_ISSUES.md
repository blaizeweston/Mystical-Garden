# Known issues

## Guest focus-loss RPC during return to the main menu

**Status:** Open. Recorded 2026-11-12.

When a connected guest leaves the session or the host disconnects, the title transition can log `RPC 'submit_combat' on yourself is not allowed by selected mode.` Headless source runs `ac02-source-leave-session` and `ac02-host-disconnect` each produced three instances. Packaged run `ac02-title-control-02` reproduced the same error.

[`game.gd::return_to_main_menu()`](../game.gd#L3260) replaces ENet with an offline peer and adds the menu while the outgoing world still has its `Guest` session state. Adding the menu dispatches a focus-loss notification to the old world. [`mouse_combat.gd::release()`](../mouse_combat.gd#L29) then tries to send `submit_combat` to the host ID, which is now the local peer ID.

Regression acceptance requires that a guest can leave or return to the menu after a host disconnect with zero unexpected engine errors. Verify that normal focus loss still releases held attack input while the guest remains connected.
