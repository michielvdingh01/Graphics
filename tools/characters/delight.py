"""Takes the light of the room out of a scan's colour.

A scan's texture is a photograph: the top of the shoulders is bright because
the lamp hung there, the underside of the arms is dark, the folds are darker
still. Put in a level, the character would carry that light around with it.

What the camera saw is, texel for texel, the colour of the surface times the
light that fell on it. The light is assumed to change slowly with the way the
surface faces (a second order spherical harmonic of the normal) and to be
dimmed where the surface is enclosed (ambient occlusion, measured on the
mesh). The colour is assumed to come in a handful of kinds, skin, a shirt,
trousers, each with its own brightness. Fitting all of that to the brightness
of the texels at once separates the two: dark hair on top of a head is then
not mistaken for a shadow, because hair is a kind of its own. What the fit
calls light is divided out again.

It cannot undo a hard shadow that one limb casts on another, or a highlight.
Scan in even light.
"""

import numpy as np

KINDS = 10
SAMPLES = 150000
# How far a texel may be brightened or darkened.
GAIN = (0.7, 3.0)


def linear(srgb: np.ndarray) -> np.ndarray:
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def encoded(value: np.ndarray) -> np.ndarray:
    value = np.clip(value, 0.0, 1.0)
    return np.where(value <= 0.0031308, value * 12.92, 1.055 * value ** (1 / 2.4) - 0.055)


def harmonics(normal: np.ndarray) -> np.ndarray:
    """The eight second order terms of a direction, without the constant one."""
    x, y, z = normal[:, 0], normal[:, 1], normal[:, 2]
    return np.stack([y, z, x, x * y, y * z, 3 * z * z - 1, x * z, x * x - y * y], axis=1)


def kinds(colour: np.ndarray, random: np.random.Generator) -> np.ndarray:
    """Sorts texels into kinds of surface by their hue and saturation, which
    light changes far less than it changes brightness."""
    total = colour.sum(axis=1, keepdims=True) + 1e-4
    chroma = colour[:, :2] / total
    centres = chroma[random.choice(len(chroma), KINDS, replace=False)]
    for _ in range(12):
        nearest = np.argmin(((chroma[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2), axis=1)
        for index in range(KINDS):
            own = chroma[nearest == index]
            if len(own):
                centres[index] = own.mean(axis=0)
    return centres


def remove(colour: np.ndarray, normal: np.ndarray, occlusion: np.ndarray, strength: float = 1.0) -> tuple:
    """colour: (n, 3) sRGB of the texels; normal: (n, 3) unit vectors;
    occlusion: (n,) 1 in the open, towards 0 where enclosed. Returns the colour
    without the light and a note on what was found."""
    random = np.random.default_rng(7)
    lit = linear(colour.astype(np.float64))
    brightness = lit @ np.array([0.2126, 0.7152, 0.0722])
    usable = np.nonzero((brightness > 0.004) & (brightness < 0.9))[0]
    if len(usable) < 2000:
        return colour, {"removed": False}
    pick = random.choice(usable, min(SAMPLES, len(usable)), replace=False)
    centres = kinds(lit[pick], random)

    def kind_of(values: np.ndarray) -> np.ndarray:
        total = values.sum(axis=1, keepdims=True) + 1e-4
        chroma = values[:, :2] / total
        return np.argmin(((chroma[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2), axis=1)

    shade = np.log(np.clip(occlusion, 0.05, 1.0))
    design = np.concatenate([np.eye(KINDS)[kind_of(lit[pick])], harmonics(normal[pick]), shade[pick, None]], axis=1)
    target = np.log(brightness[pick])
    weight = np.ones(len(pick))
    for _ in range(6):
        # Least squares that listens less to what does not fit: a print on a
        # shirt, a highlight.
        scaled = design * weight[:, None]
        solution = np.linalg.lstsq(scaled.T @ design + 1e-6 * np.eye(design.shape[1]), scaled.T @ target, rcond=None)[0]
        residual = np.abs(target - design @ solution)
        weight = 1.0 / np.maximum(residual / (1.5 * np.median(residual) + 1e-6), 1.0)
    light = solution[KINDS:KINDS + 8]
    enclosed = float(np.clip(solution[-1], 0.0, 2.0))

    shading = harmonics(normal) @ light + enclosed * shade
    # A photograph is exposed for what stands in the light. So what is well lit
    # stays as it is and the rest is brought up to it.
    shading -= np.percentile(shading[pick], 85)
    gain = np.clip(np.exp(-strength * shading), GAIN[0], GAIN[1])
    result = encoded(lit * gain[:, None]).astype(np.float32)
    spread = np.exp(np.percentile(shading[pick], [5, 95]))
    return result, {"removed": True, "light_from_dark_to_bright": [round(float(spread[0]), 2), round(float(spread[1]), 2)], "occlusion_power": round(enclosed, 2)}
