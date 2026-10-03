# Melody Grove — The Sleeping Forest

A four-stage musical adventure made with Blender and Godot. The forest has
forgotten its song. Follow a firefly, awaken musical flowers, help the forest
choir, and restore a great tree with your voice.

This is the **ground-walking experiment**, on branch `ground-walking-adventure`.
The original platform game is preserved on `main` at commit `ee7d892`, tagged
`platform-version-backup-2026-10-03`. Nothing in this branch has been published.
GitHub Pages continues to serve `docs` from `main` until that is deliberately updated.

## Play locally

Open `game-source/project.godot` in Godot 4.7.2 and press Play.
The native working copy is also synced to the sibling `melody-grove-godot` folder.
For the website, serve `docs` over HTTP; microphone access requires localhost
or HTTPS. The compressed WebAssembly is loaded by the custom welcome page.
Open `index.html` through the server, rather than the engine's `game.html`.

- **WASD / arrows:** walk in four directions relative to the camera.
- **Click or tap the ground:** walk there. The hollow tree blocks the route;
  destinations beyond the clearing are ignored.
- **Click/tap a flower or press 1–8:** walk to that note. In memory lessons,
  first listen to the melody.
- **Pause briefly on a flower:** hear/select its note. Walking past does not
  trigger it. Step away and return, or tap it again, to repeat the same note.
- **L / Listen:** hear the memory lesson. **Space:** repeat the current note.
- **P / Escape:** pause. **R:** restart the stage. **C:** stage-one wide view.

The camera follows exploration and stage passages; memory lessons use a wider
view that gently tracks movement while keeping the flower circle readable.
The compact bottom panel keeps retry, volume and other settings out of the way.
Touch targets, rewards, celebrations, Next stage and unlocked-stage replay remain.

## Four chapters

1. **Whispering Meadow:** follow the firefly to eight flower patches. Each new
   note blooms and gives one 10-point gem. Awaken the little bird at the exit.
2. **Echo Clearing:** a hollow tree remembers three three-note melodies.
   Listen to the glowing flowers, then walk to repeat the sequence. A wrong
   answer returns to the centre for another try; Listen is always available.
3. **Broken Brook:** help the robin, wren and finch through three four-note
   melodies. Each restored song brings water and birds back to a section of
   the brook and opens a root-and-wood crossing to the next clearing. The first
   round shows every note, the second shows the first, and the third is by ear.
   Show hint is always free.
4. **Singing Tree:** remain on the ground beneath the tree. Listen, then sing
   or hum Do → Re → Mi → Re → Do. Each sustained match opens another blossom,
   lights its branch and awards 20 points. There is no climbing or jumping.

Scores and unlock rules are unchanged: maxima 80, 120, 150 and 100 points;
450 total and 12 stars. Memory lessons give 10 points per note in a completed
melody, plus a 30-point stage bonus reduced by 5 per mistake (minimum zero).
Mistakes never lock a player out of progression. Replays improve best scores;
collecting the same flower repeatedly does not generate extra points.

## Progress and reverting

The experiment uses its own save location:
- Native: `user://grove-ground-progress.json`.
- Web: localStorage `melody-grove-ground-progress-v1`.

Platform-version progress remains in its original locations. The experiment
starts fresh. Completed stages and best scores persist; unfinished attempts
restart when leaving or reloading.

The complete original game is also saved outside this repository under
`../backups/platform-version-2026-10-03/`. Open
`playable-platform-version/game-source/project.godot` for the old playable game.
That folder includes a ZIP of the committed source, Blender art and web export,
and `RESTORE.txt`. To return the repository to the old version, first commit or
otherwise preserve experiment changes, then switch to `main` or the backup tag.
Do not use a destructive reset or discard changes to switch versions.

## Microphone lesson

Tap Enable microphone, grant permission, and stay quiet during calibration.
Tap Listen, wait for playback and the quiet gap to finish, then sing or hum.
A match within 65 cents, sustained for 0.55 seconds, opens a blossom. Octave
matches are accepted. Brief dropouts have a 0.16-second grace period. Wrong or
missing pitch gives guidance without removing points.

Two vertical bars appear on the right: absolute microphone/reference pitch,
and Hold to bloom. The whole pitch bar changes height with frequency, including
reference playback; loudness does not change its height. Green indicates a match.
Microphone enable, Listen and voice settings remain in the bottom panel.
Lower/higher ranges and listening-only practice remain available. Practice
never awards singing points or records completion.

Audio is processed locally, with no recording, upload, API key or backend.
Capture stops on pause, stage change, retry, completion and page hide. Re-enable
it explicitly after a pause. The browser asks for permission; if refused, the
help dialog explains device settings and offers retry or practice.
Physical iPhone/Android microphone and performance testing is still required;
automated browser checks use synthetic microphone audio.

## Phone installation

After publishing to HTTPS, open the site and wait for Ready offline. On iPhone,
use Safari → Share → Add to Home Screen. On Android, use Chrome → Install app /
Add to Home Screen. Open the installed icon once online and confirm Ready offline.
Clearing website storage can remove downloads and saves. This is an installable
web game; this branch does not contain a signed iOS or Android app.

## Source and visuals

- `art-source/`: editable Blender explorer, foliage and forest-valley kits.
- `game-source/ground_world.gd`: flower meadow, firefly, brook restoration and paths.
- `game-source/ground_walk.gd`: walking, tap routing, bounds, obstacles and note dwell.
- `game-source/ground_flower.gd`: flower patches with shared merged flower meshes.
- `game-source/memory_arena.gd`: flower-circle lessons and listening feedback.
- `game-source/canopy_concert.gd`: the three ground-level choir clearings.
- `game-source/singing_stairway.gd`: the Singing Tree (filename retained for compatibility).
- `game-source/lesson.gd`: scoring and progression rules.
- `game-source/singing_lesson.gd`, `voice_capture.gd`, `docs/voice-input.js`: singing.
- `docs/`: matching exported game, responsive interface and offline cache.

The Blender explorer remains a single scene node. Trees, distant mountains,
animated pond water, grass and flowers use the existing forest assets. Clearings
are level so walking remains grounded. Large distant terrain is scenery; the
playable area is bounded. This is a first playable walking adventure, not a
finished open-world game with unrestricted terrain navigation.

`editor_forest.scn` is generated from the runtime's stage-one scenery. It is
removed when Play starts to avoid duplicates. Regenerate it after scenery edits:

```sh
godot --headless --path game-source --script test_bake_editor_forest.gd
godot --headless --path game-source --export-release Web ../docs/game.html
python3 tools/package_web.py
```

The Web preset currently references a local no-threads export template; change
that path on another computer. Offline packaging updates the cache version.

## Validation

- `test_ground_adventure.gd`: full four-stage journey, real keyboard input,
  ground taps, tree obstacle, pause, unique rewards, error recovery, connected
  passages, brook restoration and simulated pitch without jumping.
- `test_singing_stairway.gd`: pitch detector, freshness, playback guard, octaves,
  hold grace, practice isolation, microphone pause and voice range.
- `test_lessons.gd`: score and save rules.
- `test_bake_editor_forest.gd` / `test_storybook_view.gd`: editor/runtime scenery.
- `test_valley_view.gd`: all-stage frame timings and portrait/wide framing.
- `tools/test_ground_web.cjs`: phone taps, keyboard movement, score and save isolation.
- `tools/test_stage_picker.cjs`, `tools/test_singing_stairway.cjs`: phone menus,
  synthetic microphone, UI sizing and offline progress.

The game is capped at 30 FPS. A short 1152×800 test on this M2 Air (8 GB) held
30 FPS in all four stages, with p95 frame time around 34 ms. This does not measure
sustained heating or prove performance on physical phones. Older platform-specific
movement tests are historical; use the ground-adventure checks for this branch.
