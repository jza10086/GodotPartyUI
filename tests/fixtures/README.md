# Test-only video

`minigame_preview.ogv` is a one-second, silent, locally generated FFmpeg test pattern. No external footage or game artwork. It is used only by `tests/test_minigame_video.gd`, not by the default UI/demo.

Recreate with:

```sh
ffmpeg -f lavfi -i 'testsrc2=size=160x90:rate=12:duration=1' -an -c:v libtheora -q:v 2 -y tests/fixtures/minigame_preview.ogv
```
