/*
 * Point Blank's own activation plugins (mods/preloaded/packages).
 *
 * Skip FMVs is mod-owned on PSX: game.toml cannot switch it on, an enabled
 * mod's activation plugin does. The skip itself is the framework's generic
 * one (hold START while MDEC + XA streaming is detected).
 */
#include "mod_plugins.h"

static void pointblank_skip_intro_activate(void) {
    (void)psx_mod_set_auto_skip_fmv(1);
}

PSX_MOD_CONSTRUCTOR(pointblank_register_mod_plugins) {
    (void)psx_mod_register_activation_plugin(
        "pointblank.skip-intro", pointblank_skip_intro_activate);
}
