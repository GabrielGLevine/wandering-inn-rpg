# #513 Pallass art: wool trader, Garuda and Dullahan residents

Art brief and generation record for the approved #513 Pallass content
(`docs/design/513-pallass-income.md`). User ruling, 2026-10-08: generate new
owned PixelLab art for the Plains Gnoll wool trader and for on-screen Garuda
and Dullahan residents, under best art wins (`docs/CHOICE-LOG.md`,
"Presentation, art and mobile").

Scope: sprites, registry entries and an art proof. No map placement,
dialogue or quest data; the content lane places NPCs using the sprite ids
below.

## Shared rig contract

All three rigs match the Pallass harvest NPC family (`stallkeeper`,
`den_shop_keeper`, `forge_tier_smith`, `forge_hall_apprentice`):

- PixelLab `create-character-v3`, 64px, low top-down, 8 rotations, mannequin
  template; south must be the true front view (a 3/4 south mislabels every
  direction, as with the harvest's sergeant and lift attendant v1).
- Prompt suffix: "Full body, straight front-facing pose. top-down RPG game
  character sprite, hard black outline, 16-bit pixel art, muted earthy
  palette".
- Directional record: `sheet_down` / `sheet_side` (east, mirrored for west) /
  `sheet_up`. `idle` is 4 frames at 6 fps; `walk` is 6 frames at 8 fps.
- Each animation is packed onto one shared frame canvas per rig, with every
  frame re-centred so its feet plane (the lowest opaque row) sits on one row.
  `anchor.y` is that row divided by the frame height.
- `render_scale` puts the visible figure height at 27px (1.69 cells), the
  measured height of the Pallass harvest NPCs. Shadow on.

## Characters

### `wool_trader`: Plains Gnoll wool trader (the trader in "Room on the Row")

- **Canon.** Gnolls are furred hyena-folk ([Gnolls](https://wiki.wanderinginn.com/Gnolls)).
  Plains Gnolls live in tribes and travel. "City Gnoll" versus Plains Gnoll
  is canon within the bar (5.06, 6.09, 7.01). She is an original, unnamed
  role who came up through the Door with plains wool and her grandmother's
  brass weights (design §3).
- **Silhouette.** A large bound wool bale on her back, wider than her
  shoulders, in every facing. No other Gnoll rig has one: `gnoll_traveler`
  wears a cloak, Krshia a robe, Yelra and `gnoll_ranger` a quiver and bow, and
  Xif a bandolier and flask.
- **Palette.** Sandy-grey, dark-spotted fur (not the tan-brown of Yelra and
  `gnoll_ranger`), an undyed cream wool tunic, a red-and-ochre tribal sash,
  and a cloth bundle of weights at her hip.
- **Animations.** `idle` and `walk`.

### `dullahan_examiner`: Dullahan blade examiner (forge tier, `tempered_standards`)

- **Canon.** Dullahans have detachable heads, carried in the hands or under an
  arm, or set on the shoulders. Their armour is mandatory and shows their
  standing; metal plate reads as respectable
  ([Dullahans](https://wiki.wanderinginn.com/Dullahans)). Within the bar,
  Pallass has Maughin the [Armorer] and Lorent the [Sharpener] (6.09), and
  Giren at Grimalkin's gym (7.02). Pallass's Dullahans are "a growing
  minority" (6.31). The design's examiner climbs the stair "head under his
  arm the whole way up" and "holds his head out level with the edge and
  sights down it".
- **Silhouette.** Nothing sits above the gorget; the head is tucked under his
  left arm, and he carries a long thin test blade point-down. This
  flat-topped figure is unlike every other rig. He wears full plate with a
  smith's apron. The armour covers the body, so his transparent skin is
  never shown.
- **Palette.** Blued steel, brass rivets, a brown leather apron and a pale
  face.
- **Animations.** `idle` and `walk`.

### `garuda_runner`: Garuda street runner (Pallass resident; the runner in `ledger_eats_first`)

- **Canon.** Garuda are light, frail-boned bird-people with beaks and mixed
  feathers. Their wings are their arms, with small talons at the tips
  ([Garuda](https://wiki.wanderinginn.com/Garuda)). Within the bar there is a
  young male Garuda Street Runner (7.02); Garuda are "more common here than
  Humans" (6.31) and fly in Pallass (7.03).
- **Restrictions.** No white plumage, since white feathers are "royal" in
  Garuda culture. No all-black crow look, which belongs to the Loquea Dree, a
  separate people.
- **Silhouette.** Hooked beak, wing-arms folded at the sides, thin bird legs
  and a fan tail, with a sky-blue runner's vest and a satchel. He stands
  clearly apart from the human `city_runner` and from every Drake and Gnoll.
- **Palette.** Russet-brown and tan mottled feathers, a barred cream chest, a
  yellow beak and legs, and a sky-blue vest.
- **Animations.** `idle` and `walk`.

## Best art wins

`wool_trader` is A/B-tested at gameplay scale against `gnoll_traveler`, the
rig the design would otherwise reuse. If the new rig loses, the content lane
uses `gnoll_traveler`. The Garuda and Dullahan have no prior rig; their
alternative is staying off-screen.

## Generation record

**Billing.** The Tier 1 subscription lapsed on 2026-10-06, so the MCP
generation tools refuse. The PixelLab v2 REST API still accepts jobs paid from
the account's USD credit, one concurrent job at a time. The batch spent
$0.402 of $0.456, leaving $0.053:

| Job type | Cost |
|---|---|
| v3 create | $0.035–0.047 |
| v3 idle, per direction | $0.011–0.016 |
| v3 walk, per direction | $0.012–0.022 |
| Rejected standard-mode trial | $0.013 |

There was no headroom for re-rolls. A renewal is a purchase and needs the
user.

**Raw outputs.** Raw zips, contact sheets, prompts, the job ledger and
`MANIFEST.json` are in the gitignored
`potential_assets/pixellab_2026-10-08_pallass_513/`. Per-sheet character ids,
animation-group ids, job ids and SHA256 hashes are in
`wandering_inn_game/assets/LICENSES/v019-owned-art-provenance.txt`.

| Sprite id | PixelLab character | Create job | Prompt (full text in the batch `prompts.json`) |
|---|---|---|---|
| `wool_trader` | `5d0d247c-ddf0-4068-813b-7d8e8a790ab5` | `5ebf2515-f6ae-4563-bf39-2617bb16c390` | Plains Gnoll hyena-folk; sandy-grey spotted fur; cream wool tunic; red-and-ochre sash; big twine-bound wool bale high on her back; cloth bundle at the hip |
| `garuda_runner` | `7f970cc3-f375-4877-bcf4-94fb7dc0dd4e` | `51272464-d253-41f2-8c16-da54900959f1` | Slender Garuda with a hawk head and hooked yellow beak; russet-tan mottled feathers; wings for arms with wing-tip talons; bird legs; fan tail; sky-blue vest; satchel |
| `dullahan_examiner` | `57a4ba79-8eed-4983-a65a-b08885a7ab2e` | `589562c8-4d95-4d2f-b499-a1f2ba5c8f89` | Headless blued-steel plate with brass rivets; empty gorget; bearded head under his left arm; smith's apron; thin test blade point-down |

The animations are v3 `animate-character` jobs, one per direction (south,
east, north). Idle keeps the rotation as frame 0, plus four generated frames;
walk is six generated frames. The job ids are in the provenance file.

**Rejected.** A standard-mode trader trial (`75286047-…`) read as a grey wolf
or fox, not a hyena Gnoll, and was flatter than the harvest family.

**Frame picks.**

- `wool_trader` idle south ships frames 0, 1, 2, 1 (a ping-pong loop),
  because her hip bundle vanishes in frames 3–4.
- `garuda_runner` idle south ships frames 1–4, so the canon wing-tip talon
  stays visible rather than flickering in at frame 1.
- The north idle job hit a transient server 404 once and was re-run.

**Geometry.** Each rig packs onto one canvas with a shared feet row. Frames are
84×88 (Dullahan 84×87), with `anchor.y` set to feet row ÷ height.

- `wool_trader` and `garuda_runner` use `render_scale` 0.45, the Pallass
  harvest pixel density (stallkeeper 0.458), giving 27px and 26px visible.
- The generator drew the headless Dullahan body at the full 60px. Normalising
  it to 27px would put his gorget where everyone else's crown is. His 0.3833
  scale gives 23px to the gorget, which is shoulder height, and matches the
  forge-hall apprentice he stands beside (0.377).

## Registry and proof

All three are directional entries in `wandering_inn_game/data/sprites.json`:
`idle` is 4 frames at 6 fps, `walk` is 6 frames at 8 fps, and shadow is on.
None has a `fallback_sprite`, because the sheets are owned and public.
`test_sprite_registry` pins the frame counts.

The proof script `qa/scripts/pallass_resident_art_peek.json` (manifest tier
`full`, fixture `near_pallass_drake`) works as follows:

- The QA-only driver action `stage_sprite` draws each unplaced rig through
  World's own entity-visual path.
- Every stage pins no placeholder, no fallback, the frame count, and
  `feet_offset_px` 0.
- The idle-down stages also pin the visible figure height: 27, 26 and 23 px.

Windowed reads (1280×720):

1. `wool_trader` at (2,4) by the plinth, with Xif, Octavia and the Drake
   checkpoint clerk. The bale reads as a cream mass behind her head; the fur
   and sash render at the same density as Xif.
2. **A/B against `gnoll_traveler`** at (3,4), same row. `gnoll_traveler` is a
   flat, low-contrast beige figure, 30px tall, with no prop. The trader has a
   distinct silhouette and matches the harvest NPCs around her. **Verdict: the
   new rig wins**, so the content lane uses `wool_trader`.
3. `garuda_runner` at (8,5) beside the Drake checkpoint clerk. Beak, wing-arms,
   vest and yellow talons read at a glance, at the same figure height.
   Beside the stallkeeper the stall awning hid him, so the cell moved.
4. `dullahan_examiner` at (7,3) under the bend-jig notice, beside the Drake
   apprentice. He reads as a headless armoured figure with his face at the
   left hip and the blade down, the apprentice's height.
5. `garuda_runner` at (20,5) at the Grand Lift's west edge, with the forge
   smith in frame. The lift sprite hides anything east of x=21, including its
   own attendant.
6. Idle and walk lineups on the market's front row, one feet line for all
   nine poses. The side view mirrors correctly for "left". The Dullahan's
   east and west profile hides the head on the far side, which is physically
   correct; the empty gorget still identifies him.

**Content-lane notes.**

- Place `wool_trader` facing down. Her south walk is a modest shuffle; east
  and north are full strides.
- The `dullahan_examiner` side view shows no head, so give him a `down` or
  `up` facing where the head-under-arm read matters.
- Neither Garuda nor Dullahan cell should sit behind a stall awning or the
  Grand Lift sprite.
