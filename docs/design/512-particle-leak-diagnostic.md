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

Next instrument the reduced engine case below to distinguish shader-cache
accounting from key comparison/storage, then validate any engine correction
against both this reduction and the unchanged long game routes.
Godot debugging supplied the reproduce/isolate sequence; Godot testing supplied
the small scene lifecycle harness. The alternative, changing renderer or
ambient behavior to silence teardown, would discard the failure evidence.

Matching engine source confirms a shared particle shader cache whose user counts
are adjusted on material updates/destruction; this motivates lifecycle tracing
but does not prove the game or engine cause. Source: [Godot5b4e0cb0f particle
material](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/resources/particle_process_material.cpp).


## Main-thread engine reduction

Official Godot `4.7.stable.5b4e0cb0f`, macOS ARM64. A bare project with only
`config_version=5` and the compatibility renderer reproduces the headless
DummyShader leak with this script:

```gdscript
extends SceneTree
var material: ParticleProcessMaterial
var COUNT := 2
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    OS.get_cmdline_user_args()
    for iteration in COUNT:
        material = ParticleProcessMaterial.new()
        material.get_rid()
        material = null
    print("PARTICLE_SERIAL_COMPLETE")
    quit()
    return
```

The exact tab-indented script, bare project, complete logs, commands, and hashes
are in `/private/tmp/wi-512-leak-evidence/serial-repro-bundle/`. Execute each case
in a fresh process with an isolated HOME:

```sh
env HOME=/private/tmp/wi-512-leak-runtime-serial-bundle /usr/local/bin/godot --headless --path /private/tmp/wi-512-leak-evidence/serial-repro-bundle --script /private/tmp/wi-512-leak-evidence/serial-repro-bundle/repro.gd
```

| Script, otherwise identical | Trials | Completion / exit | Full stderr |
|---|---:|---|---|
| `repro.gd` | 3 | Marker / zero | DummyShader leak each time |
| `control_without_args.gd`: omit argument read | 1 | Marker / zero | Clean |
| `control_one_material.gd`: count1 | 1 | Marker / zero | Clean |
| `control_without_rid.gd`: omit get_rid | 1 | Marker / zero | Clean |

There are no nodes, scenes, assets, autoloads, game code, or threads in this
reproduction. Empty user arguments also reproduce the earlier equivalent case.
The argument-read sensitivity suggests an allocation-sensitive engine defect;
it does not establish that the argument API itself is faulty. This bare
reduction has not been run natively; the unchanged full worker route supplied
the independent native particle-shader failure above.

A weak-reference observer on the full798-step prefix retained the leak while
reporting all52 particle nodes and all52 process materials freed before exit.
Replaying their exact creation/free order, frame spacing, and phase gating in
isolation remained clean. A more intrusive per-frame observer also made one
full prefix run clean, so instrumentation can perturb this failure. Node
ownership is not supported as the cause by these observations.

The exact engine's `MaterialKey` constructor clears its whole storage. Its
hash and equality inspect the whole structure, including unused bits, and
`_compute_key` returns a locally initialized key. Source alone therefore does
not demonstrate uninitialized padding. The cache decrements users during
updates/destruction and frees at zero. Compiler handling of key storage/copies
and cache accounting remain hypotheses requiring direct instrumentation.
[Exact header](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/resources/particle_process_material.h)
and [implementation](https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/resources/particle_process_material.cpp).

An earlier same-resource parallel get_rid experiment is not evidence of a game
race: lazy material mutation makes that concurrent API use an invalid control,
and the serial reduction needs no threads. Strict Variant-inference parse
failures in early weak-reference scripts are preserved under
`rejected-weakref-typing/`; they are not clean controls. The earlier
`trace798-framed.log` typing failure is likewise rejected; its corrected
`trace798-framed2.log` reproduces the leak.

No production workaround is justified yet. Eager get_rid already occurs in the
failing reduction. Manually freeing a Resource-owned RID risks invalidating its
owner; retaining resources merely postpones lifecycle work. Keep particle
quality and strict stderr gates intact. The preferred path is an instrumented
engine correction or independently verified engine version, followed by the
minimal red/control cases, repeated unchanged worker/rogue routes, and native
visual checks. No engine upgrade, external report, or waiver is authorized by
this diagnostic checkpoint.


## Lifetime and installed-version controls

Keeping two or200 minimal materials alive together, then explicitly clearing
the array before quit, completes cleanly. Adding frames around that clear also
stays clean. However, an external wrapper retaining all52 actual materials
through the unchanged worker798 prefix still leaks after explicit release:
`PARTICLE_RETAINED_RELEASE: 52`, `PARTICLE_ALIVE: []`, then DummyShader error.
The assertion result passes but the run is rejected. See `retain798.log`, its
`result.json`, and `probe-particle-retain.gd` in the evidence directory. This
refutes simple retained lifetime as a reliable game workaround; an immutable
template cache has not been implemented or validated.

The already installed Godot `4.6.2.stable.71f334935` also leaks on the bare serial
reproducer (`engine46-repro.log`). This is only a diagnostic version comparison,
not a game downgrade or acceptance run. The project's configured engine is
unchanged. Selected game observer/log hashes are recorded separately in
`diagnostic-checkpoint-sha256.json`; the standalone bundle retains its own
`sha256.json` and exact command matrix.
