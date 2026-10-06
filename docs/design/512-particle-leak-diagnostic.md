# Particle shader teardown diagnostic

Isolated branch `issue/512-worker-leak-probe`, base `35992223`. No production
source or canonical route changes. The original worker route has 965 steps.
Its assertion result passes while renderer teardown reports a leaked shader;
that is a failed authoritative gate, irrespective of exit zero.

## Observations

| Probe | Assertion/marker | Full stderr |
|---|---|---|
| Unchanged worker965, native Metal, private asset overlay | PASS, 965 steps | ParticlesShaderRD + RendererRD Shader leak |
| Earned final checkpoint, fresh headless load through WORLD_READY | PASS, 9 steps | Clean |
| Unchanged worker prefixes732 /786 /792 | PASS | Clean |
| Unchanged worker prefixes798 /801 /826 /830 /838 | PASS | DummyShader leak |
| Fresh final checkpoint plus deep→sewers→deep diagnostic transitions | PASS | Clean |
| Fresh final checkpoint plus all36 observed map rebuilds | PASS | Clean |
| Earned retry save plus actual return segment | PASS | Clean |
| Earned training save plus first descent/defeat/return segment | PASS | Clean |
| Isolated WIAmbience pond/dust replacement across60 cycles | Completion marker | Clean |

The first narrowed interval is the second sewers→deep door interaction:
worker792 is at the returned sewer landing; worker798 interacts with the
fissure after walking to it. The leak appears before the meal use and scout
retry combat. Persisted state and observed map order alone do not reproduce it.
The native renderer independently identifies the retained object as a particle
shader, so this is not merely a Dummy-renderer warning. No concrete ownership
cause is proven yet; do not suppress stderr or disable ambience as a fix.

All five native captures were read: Helper and Diplomat gains, Hot Meal receipt,
and Pisces lesson options are visible and readable. The final ActIII-named
capture shows only the bed toast, so it does not independently prove a new
class or arc transition. Native run uses unchanged canonical timing and mouse/
keyboard automation, not production-delay, browser-touch or device evidence.

## Reproduction and next action

Evidence and scratch probes: `/private/tmp/wi-512-leak-evidence/`. The native
route remains untouched under `qa/scripts/journey_worker.json`. Run it with
`qa/run_qa.sh journey_worker windowed --seed=9 --fail-fast`; preserve the entire
log, including stderr after QA_RESULT. Scratch JSON probes use absolute
`--qa-script` and `--qa-out` arguments. Each run has a distinct process HOME.
Diagnostic teleports appear only in explicitly isolated map-cycle probes; they
are not gameplay route evidence. Assets were copied from the private overlay
into ignored paths; their hashes are preserved separately and are not tracked.

Next isolate the earlier process history missing from the training-save replay,
then reduce a reproducing resource lifecycle before proposing a reviewed fix.
Godot debugging supplied the reproduce/isolate sequence; Godot testing supplied
the small scene lifecycle harness. The alternative, changing renderer or
ambient behavior to silence teardown, would discard the failure evidence.

Matching engine source confirms a shared particle shader cache whose user counts
are adjusted on material updates/destruction; this motivates lifecycle tracing
but does not prove the game or engine cause. Source: [Godot5b4e0cb0f particle
material](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/resources/particle_process_material.cpp).
