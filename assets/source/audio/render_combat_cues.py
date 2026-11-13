"""Render original attack and feedback cues for Mystical Garden."""

import numpy as np

from render_cues import AUDIO, place, strike, write
from render_soundscape import RATE, TAU, envelope, periodic_noise, thud, timeline


def layer(length):
    return np.zeros(round(length * RATE), dtype=np.float32)


def glide(length, start, end, attack, release, overtone=0.0):
    t = timeline(length)
    phase = TAU * (start * t + (end - start) * t * t / (2 * length))
    return (np.sin(phase) + overtone * np.sin(2.03 * phase)) * envelope(t, length, attack, release)


def texture(length, low, high, attack, release):
    return periodic_noise(length, low, high) * envelope(timeline(length), length, attack, release)


def enemy_cues():
    call = glide(.64, 122, 236, .16, .17, .37)
    charge = layer(.59)
    for at, amount in [(0, .88), (.113, .74), (.22, .58)]:
        place(charge, thud(.32, 56), at, amount)
    charge += texture(.59, 230, 1600, .018, .35) * .15
    hook = layer(.84)
    place(hook, glide(.37, 127, 251, .075, .12, .32), 0, 1.0)
    place(hook, glide(.42, 178, 315, .075, .17, .34), .29, .91)
    hook_release = layer(.7)
    place(hook_release, charge, 0, 1.0)
    place(hook_release, thud(.32, 70), .39, .75)

    leap = glide(.43, 240, 420, .13, .12, .17) + texture(.43, 460, 2200, .15, .17) * .18
    leap_release = glide(.43, 515, 189, .025, .24, .11) * .37 + texture(.43, 450, 2570, .023, .24) * .63
    burrow = glide(.65, 60, 101, .28, .23, .2)
    burrow *= .73 + .27 * np.sin(TAU * 11 * timeline(.65))
    burrow += texture(.65, 115, 640, .15, .25) * .22
    burrow_release = thud(.51, 49) + texture(.51, 210, 1230, .022, .27) * .35

    heavy = glide(.63, 149, 79, .28, .23, .19) + texture(.63, 120, 390, .23, .26) * .14
    heavy_release = thud(.52, 45) + texture(.52, 180, 970, .012, .26) * .33
    ranged = glide(.48, 580, 945, .22, .17, .19) + texture(.48, 650, 1680, .18, .19) * .12
    ranged_release = glide(.36, 920, 337, .018, .22, .19) * .47 + texture(.36, 500, 2650, .012, .22) * .40

    support = layer(.72)
    place(support, glide(.64, 204, 222, .20, .20, .16), 0, .75)
    place(support, glide(.50, 299, 312, .19, .18, .15), .15, .62)
    support_release = layer(.56)
    place(support_release, strike(55, .55, .12), 0, .79)
    place(support_release, strike(62, .46, .10), .07, .67)

    return {
        "charge": (call, charge), "hook": (hook, hook_release), "leap": (leap, leap_release),
        "burrow": (burrow, burrow_release), "heavy": (heavy, heavy_release),
        "ranged": (ranged, ranged_release), "support": (support, support_release),
    }


def player_cues():
    blade = texture(.34, 420, 2950, .050, .205)
    blade_hit = thud(.30, 89) * .56 + texture(.30, 730, 2410, .012, .14) * .42
    thrust = glide(.32, 252, 467, .05, .16, .11) * .28 + texture(.32, 380, 1800, .035, .15) * .55
    thrust_hit = thud(.33, 118) + texture(.33, 355, 1660, .01, .17) * .39
    heavy = glide(.40, 146, 75, .09, .20, .18) * .46 + texture(.40, 160, 1150, .04, .24) * .54
    heavy_hit = thud(.45, 56) + texture(.45, 185, 1050, .012, .21) * .47
    bow = strike(58, .35, .32) * .58 + texture(.35, 760, 2690, .017, .20) * .24
    bow_hit = thud(.32, 108) * .52 + texture(.32, 1150, 2520, .012, .14) * .48
    chime = strike(67, .48, .11) + strike(74, .48, .17) * .46
    chime_hit = thud(.38, 130) * .71 + strike(69, .38, .22) * .36
    magic = glide(.42, 328, 485, .07, .21, .26) + texture(.42, 325, 1690, .09, .20) * .17
    magic_hit = strike(62, .35, .32) * .5 + texture(.35, 450, 2120, .016, .18) * .49

    cast = layer(.60)
    place(cast, glide(.45, 221, 355, .055, .21, .11), 0, .61)
    place(cast, strike(74, .48, .18), .085, .55)
    block = strike(57, .46, .43) * .72 + thud(.46, 94) * .52
    hurt = glide(.42, 195, 85, .015, .24, .13) * .38 + thud(.42, 62) * .68
    mark = layer(.51)
    place(mark, strike(69, .36, .20), 0, .73)
    place(mark, strike(76, .44, .23), .066, .68)
    shatter = texture(.43, 870, 2820, .012, .27)
    shatter *= .69 + .31 * np.sin(TAU * 19 * timeline(.43))
    shatter += strike(77, .43, .31) * .32
    interrupt = glide(.39, 333, 141, .018, .19, .33) * .66 + texture(.39, 425, 1280, .012, .2) * .31
    return {
        "blade": (blade, blade_hit), "thrust": (thrust, thrust_hit), "heavy": (heavy, heavy_hit),
        "bow": (bow, bow_hit), "chime": (chime, chime_hit), "magic": (magic, magic_hit),
    }, {
        "cast": cast, "block": block, "hurt": hurt, "mark": mark, "shatter": shatter, "interrupt": interrupt,
    }


def main():
    AUDIO.mkdir(parents=True, exist_ok=True)
    for family, (windup, release) in enemy_cues().items():
        write(f"enemy_{family}_windup", windup)
        write(f"enemy_{family}_release", release)
    weapons, combat = player_cues()
    for family, (release, contact) in weapons.items():
        write(f"weapon_{family}_release", release)
        write(f"weapon_{family}_hit", contact)
    for name, cue in combat.items():
        write(f"combat_{name}", cue)


if __name__ == "__main__":
    main()
