# Melody Grove

A four-stage musical forest game made with Blender and Godot. Move a character
between note platforms, listen, sing along, and build musical memory.

## Play

GitHub Pages serves the `docs` folder on `main`:
https://rijju-das.github.io/melody-grove/

Touch controls work in portrait and landscape. On a computer, use arrow keys or
WASD to hop in stage 1, 1–8 to jump to notes in stages 2 and 3, Space to hear the
current note, L to hear the melody, R to retry, and P to pause. In stage 1, C
switches between follow and wide views. Stages 1–3 need no microphone. Stage 4 uses live, on-device pitch feedback; audio is never recorded or uploaded.

In stage 1, tap any visible note platform to jump directly to it, hear the note,
and collect its gem. Tapping a collected platform plays its note again without
adding duplicate points. Keyboard movement remains available; Back/Next and Play note are under Settings.

All stages use the same compact bottom bar. Settings reveals retry, volume, and
sound check; stage 1 also offers movement buttons there.

In stages 2 and 3, click/tap any note platform or press **1–8** to jump directly to it.
Landing chooses that note automatically. The camera keeps the whole circle in view.

The camera smoothly follows the player between platforms and pulls back during
melody demonstrations. Use **Wide view** for a view of the whole forest. Golden
gems spin above uncollected notes; each pickup flies to the top points counter
with a **+10** reward. The gem count and points show the current stage attempt.
Completed melodies also animate their points into the counter. Retrying resets
the attempt counter while preserving saved best scores. The web interface
respects the device’s reduced-motion preference for collection effects.

## Stage celebrations and connected paths

Completing a stage opens a gold-and-green success card with earned stars and a
large Next stage button. An original 3.2-second victory jingle with synthesized
applause plays once per attempt and respects the game volume (including mute).
The sound is bundled with the game for offline play; it does not require a
network voice service. The celebration text says which stage you completed.

Next stage opens two trees and walks the character along the remaining note
platforms and a wooden footbridge into the next forest section. The follow
camera travels with the player; pause also pauses the crossing. The sections
reuse the Blender forest meshes, with only the current section rendered after
arrival to limit load. Choosing a stage from the menu starts directly in that
section. After stage four, the success card returns to the journey menu.

## Stages and points

1. **Find the notes:** collect all eight golden gems. Each different note earns
   10 points once. All eight unlock stage 2 and award three stars.
2. **Echo meadow:** start in the centre of eight circular note platforms. Listen
   to three melodies of three notes each, watch their platforms glow, and jump
   to repeat each sequence. Low Do (C4) and high Do (C5) are labelled separately.
3. **Canopy concert:** cross three treetop clearings, each with a four-note melody.
   Tap the musical lantern to listen, then tap platforms to jump and answer.
   The first clearing lights every note, the second lights only the first note,
   and the third plays by ear. Four markers track each answer.
4. **Singing stairway:** listen and sing Do → Re → Mi → Re → Do, one note at a time,
   to climb five platforms around a tree. Each step earns 20 points once.

In stage 2, tap the **Listening Glade** in the centre (follow the arrow), then
jump to the notes in order. Tap the glade again to replay, or press L. The compact
bottom bar shows progress and pause; the settings button reveals retry and volume. You can jump from any
platform to any other, including jumping in place to repeat the same note.
Three markers show your progress. A wrong note gives a gentle wobble and returns
you to the centre; only the current sequence resets. Completed melodies and
their points remain. Listen again is free and returns you to the centre before
replaying. Finish a melody to earn 30 points, then listen to the next one.

In stage 3, **Show hint** replays the full glowing sequence for free, from any
clearing. Ordinary replay returns to that clearing's normal clue level. During
sound-only notes, neither the platforms nor the status text reveals the answer.
A wrong choice gently returns the player to the centre and resets only the
current sequence. Previously earned points remain.

Each completed Stage 3 melody earns 40 points and grows a wooden branch bridge.
The character walks continuously to the next clearing while the camera follows;
pause freezes both bridge growth and movement. The final melody lights the
canopy, brings out a little bird audience, and opens the applause celebration.
There is no timer or microphone requirement. Retry starts at the first clearing
and closes the bridges while retaining saved best scores.

In stages 2 and 3, each completed melody earns 10 points per note. The stage bonus is 30 points,
minus 5 per mistake, with a minimum of zero. Zero mistakes earns three stars;
one to three mistakes earns two; four or more earns one. Completing all three
melodies unlocks the next stage regardless of mistakes. Stages 1–3 total 350 points; Stage 4 adds 100. Maximum total: 450 points and 12 stars.

Completed stages, best scores and best stars are saved on this device. Replays
improve a best score rather than repeatedly adding points. An unfinished attempt
restarts when leaving/reloading the game; completed progress stays saved.

## Stage 4 microphone singing

Complete stage 3, then choose Next stage to walk into the stairway, or select it
from the journey menu. Existing three-stage saves automatically unlock it.

Tap **Enable microphone**, allow access, and stay quiet for the 1.5-second room
check. Tap **Listen** to hear the next target. After playback and a short quiet
gap, sing or hum a steady note. The indicator suggests higher or lower; holding
within 65 cents for 0.55 seconds of voiced input lights the platform and triggers a jump. Wrong
or unvoiced input never removes points or counts as a mistake. All five steps
earn 100 points and three stars. The same note one octave below or above also counts;
brief detection gaps up to 0.16 seconds preserve the hold without adding progress. There is no timer, loudness bonus or replay farming.

Microphone level, detected note and hold meters distinguish missing input from
pitch mismatch. Calibration uses a quieter percentile rather than the loudest
setup noise, and native input stalls report a permission/device check.

**Voice settings** offers C3–E3 (lower) and C4–E4 (higher). Changing range cancels
the current demo/answer and requires listening again. **Listening-only practice**
lets the player listen, sing along and manually advance, without points, stars or
saved completion. Retry stage switches back to the scored microphone lesson.

The website uses getUserMedia plus local Web Audio pitch detection. No recording,
upload, speech recognition, API key or backend is involved. Microphone permission
is requested only by the enable button. Tracks stop on pause, Home, stage change,
retry, completion, page hide, device disconnection or audio interruption. Re-enable
explicitly after a pause. Input is disabled during the reference note and only
fresh pitch samples can fill the hold meter. Sound check is disabled in stage 4
to avoid treating that tone as a sung answer. Replay is free.

GitHub Pages HTTPS or localhost is required for microphone access. Denial, missing
hardware, noise and interruptions show guidance; practice remains available. The
browser may keep its microphone indicator on while waiting between sung notes,
because the permitted track is allocated but disabled during playback. Headphones
reduce room echo. Permission, speaker echo, quiet voices and interruptions must
still be checked on a real iPhone/Android phone; browser automation uses synthetic
microphone audio and does not prove physical-device behaviour.

The native Godot source includes a muted AudioEffectCapture adapter and local
pitch detection. Native input is enabled in project settings, with the web override
disabled because the browser owns microphone access. Future iOS exports need the
microphone usage description and a play-and-record audio session; Android exports
need RECORD_AUDIO permission. No signed native mobile package is included here.

## Phone installation

Open the site online and wait for **Ready offline**. On iPhone, use Safari's
Share > Add to Home Screen. On Android, use Chrome's Install app / Add to Home
screen. Open the installed icon once online and confirm Ready offline.
Device storage clearing can remove the saved game and progress.

Use Sound check if needed. Raise phone volume and disable Silent Mode if the
browser still silences notes. Supported iPhone browsers use a playback audio
session. Physical phone testing remains necessary.

## Source and updates

- `game-source/`: editable Godot 4.7 game; open `project.godot`.
- `docs/`: ready-to-host web export, touch interface and offline support.
- `tools/package_web.py`: compresses a fresh export and versions the offline cache.
- `game-source/test_lessons.gd`: deterministic scoring/progression tests.
- `game-source/test_follow_camera.gd`: scene-level camera, pickup and reset checks.
- `game-source/test_success_path.gd`: celebrations, volume and connected-stage checks.
- `game-source/memory_arena.gd`: shared note platforms, labels, glow and paths.
- `game-source/canopy_concert.gd`: three treetop clearings, bridges, lanterns and birds.
- `game-source/singing_stairway.gd`: rising platforms, branches and note lighting.
- `game-source/singing_lesson.gd`: voice holds, playback gate, practice and rewards.
- `game-source/voice_capture.gd`: native microphone capture and pitch detection.
- `docs/voice-input.js`: browser microphone lifecycle and pitch detection.
- `game-source/test_singing_stairway.gd`: singing rules, progression and entry path.
- `tools/test_pitch.cjs`: detector tests with harmonics, noise and two sample rates.
- `tools/test_singing_stairway.cjs`: permission, synthetic voice, phone UI and offline checks.
- `game-source/test_canopy_concert.gd`: clue levels, hints, movement and scoring.
- `tools/test_canopy_concert.cjs`: phone play-through, hints, finale and offline saving.
- `game-source/test_memory_arena.gd`: direct jumps, playback, recovery and scoring.
- `tools/test_memory_arena.cjs`: phone targets, keyboard/touch, markers and stage 2 journey.
- `tools/make_success_sound.py`: generates the original bundled victory sound.
- `tools/test_rewards.cjs`: web collection effects, resets and phone layouts.
- `tools/test_journey.cjs`: browser play-through; adjust Playwright/runtime paths
  for your environment before running it.

To rebuild, create a single-threaded Godot Web export preset with desktop and
mobile texture support, export to `docs/game.html`, then run
`python3 tools/package_web.py`. A matching Godot Web export template is required.
The generated game.html is an intermediate file; visitors use index.html.

To publish, commit the updated docs files to main. In Settings > Pages, select
Deploy from a branch, main, /docs. Existing installations may need a refresh
after the new offline copy finishes downloading. The OpenAI-hosted copy is
separate and remains private.

Stage 4 shows two parallel vertical meters on the right: microphone pitch and
hold-to-jump progress. Pitch uses a fixed musical scale (C3 at 8%, C4 at 50%, C5
at 92%): the entire Mic pitch bar becomes shorter or taller with the note,
anchored at its bottom. There is no full-height empty track or centre line.
During Listen the solid blue bar shows the reference pitch. While singing the
whole solid bar follows the detected pitch. In quiet gaps it shows a muted bar
at the target note's height. Hold to jump keeps its fixed height. During singing it follows the detected frequency; green means a
match. Octave-equivalent notes still score, but their actual heights differ.
Loudness does not control this meter. Microphone enable, Listen and voice settings
remain in the bottom panel. Hold a match for 0.55 seconds to jump.

The in-game Stages button on web and phone opens a stage picker. It pauses the
game and stops microphone capture. Players can replay any unlocked stage; locked
stages show their prerequisite, and the current stage is marked. Closing the
menu restores the previous pause state. Switching starts a fresh attempt while
preserving saved best scores and unlocks on that device.
