"""Bake the project's periodic moss, silt and shale relief into a single RGB tile."""
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 512


def make_tile():
    rng = np.random.default_rng(7301)
    y, x = np.mgrid[:SIZE, :SIZE] / SIZE

    def field(cells):
        lattice = rng.uniform(-1, 1, (cells, cells))
        u, v = x * cells, y * cells
        i, j = u.astype(int), v.astype(int)
        a, b = u - i, v - j
        a, b = a*a*(3-2*a), b*b*(3-2*b)
        return ((1-b)*((1-a)*lattice[j, i]+a*lattice[j, (i+1)%cells])
                + b*((1-a)*lattice[(j+1)%cells, i]+a*lattice[(j+1)%cells, (i+1)%cells]))

    patches, clumps, grain = field(5), field(16), field(67)
    moss = .45 + .27*patches + .18*clumps + .07*grain
    silt = .53 + .15*patches + .08*clumps + .035*grain
    # Slip faces and long sediment layers share a warped, periodic bedding plane.
    strata = np.cos(2*np.pi*(3*x + 6*y + .5*patches + .20*clumps))
    shale = .48 + .22*strata + .12*patches - .18*np.maximum(0, -strata)**8
    # Paired relief on leaflets and flat river stones survives at overhead scale.
    for layer, count, radius in [(moss, 410, .011), (silt, 160, .008), (shale, 50, .018)]:
        for _ in range(count):
            cx, cy, turn = rng.uniform(0, 1, 3)
            size = radius*rng.uniform(.45, 1.9)
            reach = int(np.ceil(size*SIZE)) + 2
            ix = np.arange(int(cx*SIZE)-reach, int(cx*SIZE)+reach+1)
            iy = np.arange(int(cy*SIZE)-reach, int(cy*SIZE)+reach+1)
            dx, dy = np.meshgrid(ix/SIZE-cx, iy/SIZE-cy)
            ca, sa = np.cos(turn*2*np.pi), np.sin(turn*2*np.pi)
            u, v = (dx*ca + dy*sa)/size, (-dx*sa + dy*ca)/(size*.4)
            body = np.clip(1-u*u-np.abs(v)**1.4, 0, 1)
            layer[np.ix_(iy%SIZE,ix%SIZE)] += body*(.09 + .24*v)
    return Image.fromarray((np.clip(np.stack([moss,silt,shale],axis=2),0,1)*255).round().astype('uint8'))


if __name__ == "__main__":
    make_tile().save(Path(__file__).resolve().parents[2] / "assets/terrain_m02/wilds_relief.png")
