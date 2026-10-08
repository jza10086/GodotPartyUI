# Kenney Input Prompts

- Author: Kenney (https://kenney.nl)
- Official asset page: https://kenney.nl/assets/input-prompts
- Release: **1.5A**, as identified in the archive's original License.txt (download filename says 1.5)
- Retrieved: 2026-10-07
- Official download: https://kenney.nl/media/pages/assets/input-prompts/8de120163f-1783763952/kenney_input-prompts_1.5.zip
- Archive SHA-256: `ac2fcf599080b0f3ba2d174c9474db6df1a0e96ff0662580e2da79a122ab78a1`
- License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/); original notice preserved in LICENSE.txt (only CRLF line endings and trailing whitespace normalized)

## Included subset

104 monochrome outline SVGs from `Keyboard & Mouse/Vector/`: letters, digits, F1–F12, common punctuation, navigation, modifiers and seven mouse inputs. The original paths, colors and SVG bytes are unchanged. We omit alternate sizes/styles, fonts, spritesheets, device packs, previews and the download ZIP.

The manifest's alpha bounds come from the corresponding official Double PNGs (divided by two to use the original 64px SVG coordinate system). Runtime AtlasTexture cropping removes only transparent outer padding. SVG import uses 4× rasterization for crisp large/DPI-scaled prompts.

All selected assets are single-color white with transparent geometry. The component multiplies their RGB by the current theme's text color while preserving source alpha, including transparent key lettering. It never converts luminance into transparency or recolors source files. This yields readable Godot-blue outlines on the project's light surfaces.

Controller packs can be added later using the resolver's registered-icon extension; currently unsupported devices remain readable text. Kenney attribution is voluntary under CC0; no endorsement is implied.
