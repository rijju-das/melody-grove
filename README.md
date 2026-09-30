# Melody Grove

A three-stage musical forest game made with Blender and Godot. Move a character
between note platforms, listen, sing along, and build musical memory.

## Play

GitHub Pages serves the `docs` folder on `main`:
https://rijju-das.github.io/melody-grove/

Touch controls work in portrait and landscape. On a computer, use arrow keys or
WASD to hop, Space to hear a note, Enter to choose it, L to hear the melody, R to
retry the stage, and P to pause. Singing is optional; no microphone is recorded.

## Stages and points

1. **Find the notes:** collect all eight golden notes. Each different note earns
   10 points once. All eight unlock stage 2 and award three stars.
2. **Echo meadow:** hear and reproduce three melodies of three notes each.
3. **Canopy concert:** reproduce three melodies of four notes each.

For melody stages, tap Listen, move to the first note and tap Choose note.
Repeat for each note in the sequence. Movement previews notes without submitting
an answer. A wrong choice resets the current sequence; previously completed
melodies remain complete. Listen again as often as needed, without a penalty.

Each completed melody earns 10 points per note. The stage bonus is 30 points,
minus 5 per mistake, with a minimum of zero. Zero mistakes earns three stars;
one to three mistakes earns two; four or more earns one. Completing all three
melodies unlocks the next stage regardless of mistakes. Maximum total: 350.

Completed stages, best scores and best stars are saved on this device. Replays
improve a best score rather than repeatedly adding points. An unfinished attempt
restarts when leaving/reloading the game; completed progress stays saved.

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
