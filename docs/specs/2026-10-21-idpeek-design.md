# IDPeek: in-game candidate viewer for the Legion 7.3.5 client

Date: 2026-10-21. Status: design approved in chat, spec under review.

## Why

Legion scripting often ends with several candidate IDs for one visual: which of ~30 "Shadowform" auras,
which WorldEffect glows under the blade (735, 3079, LootFX02 kits 55752 / 80801), which Velen display.
`SpellVisualEffectName` has no names in 7.3.5, so the data alone cannot decide, and today the only way to
look is to rebuild the server or roll back scripted state. IDPeek shows candidates in the client itself,
with no server involvement, so a candidate list can be flipped through in seconds.

## Scope

In: a client-only addon on `E:\Legion` (7.3.5.26972), plus a one-off generated lookup table.
Not in: server commands, playing visuals on world NPCs, a file written by Claude for the addon to read
(candidates are typed into the panel), sync through any launcher.

## What the client can do (tested in game 2026-10-21 with /run lines)

| Need | API | Result |
|---|---|---|
| Play a kit | `PlayerModel:ApplySpellVisualKit(kit, oneShot)` | works (gold glow from kit 55752). `SetSpellVisualKit` does not exist |
| Creature display | `PlayerModel:SetDisplayInfo(display)` | method exists, not yet seen on screen |
| Model file by id | `ModelScene` actor `:SetModelByFileID(fdid)` | works (LootFX02, 1381346) |
| Model file on a PlayerModel | `PlayerModel:SetModel(fdid)` | does NOT work (placeholder cube); a path string does |
| Texture by id | `Texture:SetTexture(fdid)` | works (136207) |

## Components

Two addon folders under `E:\Legion\Interface\AddOns\`, plus a generator script.

### 1. `IDPeek` (the panel, always loaded)

- `/idp` toggles a movable panel (about 420 x 480), closable with Escape (`UISpecialFrames`), position kept
  in SavedVariables `IDPeekDB`.
- Top row: a type dropdown (`kit`, `spell`, `display`, `model`, `texture`, `worldeffect`) and an edit box.
  Enter parses the box: integers separated by commas, spaces or both; anything else is ignored with a chat
  line naming the bad token.
- The parsed list becomes a flat list of entries. `kit`, `display`, `model`, `texture` give one entry per
  id. `spell` and `worldeffect` are expanded through the lookup table (component 2) into one entry per kit
  or model file they lead to, each remembering its chain.
- Navigation: Prev / Next buttons, and the Left / Right arrow keys while the edit box does not have focus
  (other keys propagate, so movement is not blocked). The list wraps around.
- Label under the preview: `3 / 7 · kit 55752`; for expanded entries the chain, e.g.
  `2 / 5 · spell 205128 → visual 12345 → kit 67890`. That index is what the user reports back.
- Preview area, one of three views visible at a time, chosen by the entry's kind:
  - **Model frame** (`PlayerModel`) for kits and displays. Kits play on a stand-in: the player by default,
    or a display id typed in a small "stand-in display" box. A Replay button re-sets the stand-in and
    applies the kit again (many kits are one-shots).
  - **ModelScene** with one actor, for model files (from `model` or `worldeffect`).
  - **Texture** view for `texture`, drawn at the texture's own aspect inside the preview area.
- Mouse: drag rotates (model frame `SetFacing`, actor `SetYaw`); wheel zooms (model frame
  `SetCamDistanceScale`, scene camera distance). The scene camera's start position is tuned in game;
  `-8,0,1` from the test put the model off-centre, so expect one round of adjustment.
- Unknown ids: the client shows nothing or a placeholder cube; the panel does not try to detect that.
  A `spell` or `worldeffect` id that is not in the table gives one entry labelled `not in table`.

### 2. `IDPeek_Data` (the lookup table, load on demand)

- `## LoadOnDemand: 1`; IDPeek calls `LoadAddOn("IDPeek_Data")` the first time a `spell` or `worldeffect`
  list is entered, so normal logins do not carry the table.
- One generated file `Data.lua` defining global `IDPeek_Data`:
  - `spell[spellID] = { {visual, kit, kit, ...}, ... }`: every SpellVisual the spell uses
    (SpellXSpellVisual rows, all difficulties / conditions), with the kits that visual's events play.
  - `worldeffect[id] = { fdid, attachPoint }` (WorldEffect → QuestFeedbackEffect → model file).
- Spells with no visual are left out.

### 3. Generator `IDPeek/tools/build_data.py` (runs on the host, not read by the client)

- Reads the server's extracted 7.3.5 db2s (`~/arguscore-server/data/dbc/enUS/`) with the existing
  `/tmp/stage1/wdc1.py` and `rel.py`, the same way `/tmp/priest/vfx.py` walks spell → visual → events →
  kits.
- `vfx.py` finds kits by checking every event field against the kit table; the generator instead pins the
  SpellVisualEvent field that holds the kit id and the WorldEffect / QuestFeedbackEffect fields, and prints
  them once for review.
- Writes `Data.lua`, copied to the PC with `scp`. Rerun only if the client build changes.

## Testing

No Lua interpreter on the PC, so the addon is checked in game by the user.

Generator, before shipping the table, against chains already known from the priest work:
- WorldEffect 735 → QuestFeedbackEffect 42 → `NightElfCTFFlagPlaceGlow`, attach point 19.
- WorldEffect 3079 → QuestFeedbackEffect 162 → `AuraBlueShort`.
- Spell 205128's entry matches what `vfx.py 205128` prints.

In game:
1. `/idp`, type `kit`, enter `55752, 80801`: gold glow on the player, label `1 / 2`, Next and the right
   arrow move to the second, Replay replays it.
2. `display`, `71701`: Krosus appears in the model frame.
3. `model`, `1381346`: LootFX02 in the scene view, centred after camera tuning.
4. `texture`, `136207`: the icon.
5. `worldeffect`, `735, 3079`: two model entries with their chains in the label.
6. `spell`, `205128`: one entry per kit with the chain label; a spell with no visual says `not in table`.
7. `/reload`: panel position kept, nothing else loaded until a spell or worldeffect list is entered.

## Possible later additions (not part of this build)

- NPC entry → display ids, generated from the world DB, for comparing creature templates such as the
  Velen candidates.
- Kit → effect model files, to look at a kit's parts one by one.
