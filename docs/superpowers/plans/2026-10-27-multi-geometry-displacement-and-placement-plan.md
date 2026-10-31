# Multi-geometry Displacement and Fluid Positioning Implementation Plan

> **For Copilot:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> If that skill is unavailable, execute the same test-first steps directly; do not
> claim to have invoked an unavailable skill.

**Goal:** Calculate displacement, fluid interfaces, and dependent job outputs from one validated, depth-varying pipe/annulus geometry.

**Architecture:** SimuUtils owns the reusable piecewise geometry, cumulative capacity maps, and stage-aware fluid-placement/displacement primitives in its oilfield layer. SimuHydraulics adapts its pump schedules to those primitives and owns job planning, hydraulics, forces, timelines, and rendering. Dependencies remain UomDefinitions -> SimuUtils -> SimuHydraulics, with no reverse dependency.

**Tech Stack:** Julia, Test, Pluto/PlutoUI, CairoMakie, SimuHydraulics, SimuUtils, UomDefinitions; existing project environments and test runners.

---

## 1. Source of truth, repository ownership, and scope

- Requirements: [multi-geometry specification](../specs/2026-10-27-multi-geometry-displacement-and-placement.md).
- This document is intentionally stored in `SimuUtils\docs\superpowers\plans`.
  SimuUtils owns the reusable geometry and fluid-transport core described below.
- All paths prefixed `SimuHydraulics\`, `SimuUtils\`, or `UomDefinitions\` below
  are relative to the common `Sims` workspace directory.
- Implement reusable geometry, cumulative-capacity integration/inversion,
  stage-aware displacement/placement, interval/state data, and conservation
  accounting in `SimuUtils\src\oilfield`, with tests in `SimuUtils\test`.
- Keep cement-job sizing, PumpStage/rate semantics, trajectory-based hydraulics,
  free-fall time integration, forces, timelines, and plotting in
  `SimuHydraulics\src`, with integration/regression tests in `SimuHydraulics\test`.
- SimuUtils must not import SimuHydraulics, PumpStage, Trajectory, UnitSet, or
  cement-job types. New core source must not load a plotting backend.
- UomDefinitions continues to own unit quantities and conversions; no change
  to its source or dependency graph is expected.
- Do not implement compressibility, losses, mixing, POOH redistribution,
  reverse circulation, shoulder-force mechanics, or torque-and-drag.
- Preserve current user edits, especially the notebook and unit-set definitions.
  This plan is not authorization to revert them or commit unrelated files.

## 2. Execution rules and shared validation commands

Before implementation, record the current branch, dirty files, Julia version,
and active dependency paths. Use a user-approved implementation branch/worktree;
do not automatically relocate uncommitted notebook work. Do not copy credentials
or unrelated environment configuration.

For each task:

1. Add the smallest focused failing test.
2. Run that selector and verify the failure concerns the intended missing behavior.
3. Implement only the behavior described.
4. Run the selector again and inspect all failures.
5. Commit the task's explicitly named source/test files when committing is
   authorized. Include the Copilot co-author trailer and never stage everything.

Each numbered task contains multiple small actions. Split its test cases into
separate red/green cycles rather than attempting an entire subsystem in one edit.

### Focused SimuUtils core test command

Run core tests without SimuHydraulics or CairoMakie loaded. New test files must
be self-contained, importing Test, SimuUtils, and needed unit symbols.

```powershell
Push-Location .\SimuUtils
try {
    @'
using Test, SimuUtils
for file in ("test_well_geometry.jl", "test_fluid_placement.jl")
    include(joinpath("test", file))
end
'@ | julia --startup-file=no --project=. -
    if ($LASTEXITCODE -ne 0) { throw "SimuUtils core validation failed." }
} finally {
    Pop-Location
}
```

### Focused SimuHydraulics integration test command

Run from the common workspace in PowerShell. Change only the selected test-file
list for each task. Include fixtures exactly once per process.

```powershell
Push-Location .\SimuHydraulics
try {
    @'
using Test, SimuHydraulics
include(joinpath("test", "fixtures.jl"))
for file in ("test_placement.jl", "test_plug.jl")
    include(joinpath("test", file))
end
'@ | julia --startup-file=no --project=. -
    if ($LASTEXITCODE -ne 0) { throw "Focused Julia validation failed." }
} finally {
    Pop-Location
}
```

Expected red result: a failed assertion or undefined new symbol identified by the
task. Expected green result: all selected testsets pass and the process exits 0.
Do not install dependencies unless an actual missing-dependency failure requires
restoration. A previous local run printed a SymbolServer precompile error even
while tests passed: distinguish environment diagnostics from test results and
resolve/report them rather than claim a clean run.

### Full regression commands

Run each package in a fresh process. Preserve the existing SimuUtils extension
test's first-in-suite position so backend-free core loading remains tested.

```powershell
Push-Location .\SimuUtils
try {
    julia --startup-file=no --project=. .\test\runtests.jl
    if ($LASTEXITCODE -ne 0) { throw "SimuUtils regression failed." }
} finally {
    Pop-Location
}
```

```powershell
Push-Location .\SimuHydraulics
try {
    julia --startup-file=no --project=. .\test\runtests.jl
    if ($LASTEXITCODE -ne 0) { throw "Full Julia validation failed." }
} finally {
    Pop-Location
}
```

Do not run the notebook by including its file during ordinary unit tests: its
initialization activates/develops packages and may write reports. Validate it
separately in Pluto using its existing notebook environment.

## 3. Proposed API contract

Confirm these names against current exports before adding them. Keep map
implementation helpers private unless callers genuinely need them.

| Concept | Proposed responsibility |
|---|---|
| `OuterSection` | Typed MD bounds, kind, physical OD when applicable, gauge/effective ID, excess convention, source identity. |
| `InnerSection` | Typed MD bounds, OD/ID, nominal weight or explicit derived-weight provenance, optional metadata, source identity. |
| `WellGeometry` | Validated contiguous flow domain, normalized spans, source sections, cached pipe/annulus/combined cumulative maps. |
| `DisplacementStage` (SimuUtils) | Fluid, typed volume, and stable stage identity; no pump rate or job type. |
| `FluidInterval` / `WellState` (SimuUtils) | Shared geometry-aware transport result types; no hydraulic/timeline fields. |
| `SimuUtils.fluid_positions(geometry, stages, mud; pumped, void)` | Shared profile-aware transport implementation over rate-free stages. |
| Existing `SimuHydraulics.fluid_positions(outer, inner, schedule, ...)` | Validates/adapts the legacy pair and PumpStage schedule, then delegates to SimuUtils. |
| `balanced_plug_volumes(..., geometry)` | Exact geometry-aware plan; existing capacity overload remains supported. |
| Profile-aware `PrimaryJob`/`BalancedPlugJob` construction | Uses the same profile for planning, running, and final placement. |

Keep existing function names and keyword conventions where practical. In Task 4,
decide and document the smallest type-safe state migration before editing all
consumers. Do not invent fake average capacities or duplicate a transport engine.

SimuHydraulics shall explicitly import the shared function before adding
PumpStage-specific adapter methods and re-export the shared interval/state
types as needed for compatibility. Avoid parallel same-named public types.
Core callers must be able to calculate placement using SimuUtils alone.

For new public APIs, provide concise docstrings with quantity units, returned
shape, errors, and a short usage example. Metadata must never imply unsupported
physics is active.

## Task 1: Capture the legacy baseline and consumer inventory

**Depends on:** none.

**Files:**
- Read: `SimuHydraulics\src\models\{placement,pressures,ecd,forces,timeline}.jl`.
- Read: `SimuHydraulics\src\jobs\{primary,plug}.jl`.
- Read: `SimuHydraulics\src\plots\cementing.jl`.
- Read: `SimuUtils\src\oilfield\oilfield.jl`, `SimuUtils\src\SimuUtils.jl`,
  `SimuUtils\test\test_structure.jl`, `SimuUtils\test\test_extension.jl`.
- Test: existing placement, primary, plug, pressure, ECD, force, timeline, plot tests.

**Steps:**
1. Search for direct state construction, scalar capacities, interval construction,
   Casing field access, fluid-keyed reports, and positional job constructors.
2. Run existing placement/plug tests first; expand to the other affected selectors.
3. Record pre-existing failures without fixing unrelated issues. Changed unit-set
   expectations must be reconciled with the user's active definitions, not an old
   specification table.
4. Record uniform-case interfaces, planned volumes, void behavior, pressure, and
   force baselines in focused regression assertions where coverage is missing.
5. Save benchmark baseline measurements in session output for Task 14.
6. Confirm the SimuHydraulics environment resolves the active sibling SimuUtils
   checkout before cross-package tests; check dependency paths, not just versions.

**Done when:** existing behavior and compatibility surfaces are known. No new
feature types or runtime dependency changes are introduced in this task.

## Task 2: Add normalized serial geometry and validation

**Depends on:** Task 1.

**Files:**
- Create: `SimuUtils\src\oilfield\well_geometry.jl`.
- Modify: `SimuUtils\src\oilfield\oilfield.jl` (include after Casing/Fluid dependencies).
- Modify: `SimuUtils\src\SimuUtils.jl` (only required public exports).
- Create: `SimuUtils\test\test_well_geometry.jl`.
- Modify: `SimuUtils\test\runtests.jl`, `SimuUtils\test\test_structure.jl`,
  `SimuUtils\test\test_extension.jl` (preserve backend-free core contract).

**Steps:**
1. Add failing tests for unsorted but contiguous sections, misaligned boundaries,
   inactive zero rows, physical gaps, overlaps, interference, NaN/Inf, missing
   coverage, missing physical OD, and valid open hole without OD.
2. Run SimuUtils selector: `test_well_geometry.jl`.
3. Implement typed input constructors and canonical normalization; use the union
   of inner/outer section bounds, clipped to [0, shoe].
4. Keep original input identity for errors. Permit a real shorter span without
   treating it as conversion noise; define and test boundary tolerance separately.
5. Preserve hole-area excess as gauge_ID * sqrt(1 + excess/100), without
   computation rounding or synthetic open-hole OD.
6. Require valid complete geometry in the model. Let the notebook adapter omit
   recognized inactive rows, not arbitrary malformed rows.
7. Run `test_well_geometry.jl` and `test_structure.jl`; run the core/extension
   loading check in a separate clean process, then commit focused SimuUtils files.

**Expected:** normalized spans cover the domain exactly once, with valid local
capacities from existing SimuUtils helpers. Requirement coverage: G-01 to G-08,
T02, T07, T11, T18.

## Task 3: Implement cumulative maps and exact inversion

**Depends on:** Task 2.

**Files:** modify `SimuUtils\src\oilfield\well_geometry.jl`,
`SimuUtils\test\test_well_geometry.jl`. Keep synthetic fixtures local to
that test file unless actually shared by multiple core tests.

**Steps:**
1. Add a private synthetic-map fixture: bounds [0,100,300] ft,
   Cp [0.01,0.02], Ca [0.03,0.04] bbl/ft.
2. Add failing assertions P(L)=5, A(L)=11, P(150)=2,
   inverse_P(2)=150, exact-boundary round trips, and interval additivity.
3. Run SimuUtils selector `test_well_geometry.jl`.
4. Build prefix arrays once. Locate spans by ordered lookup and interpolate
   locally for P, A, and P+A inversion. Validate lookup domain explicitly.
5. Add physical-diameter fixtures with independent capacity arithmetic and
   equivalent-unit variants; do not expose an unchecked public synthetic geometry.
6. Run `test_well_geometry.jl`; commit focused SimuUtils files.

**Expected:** no uniform-grid approximation, repeated full integration, or display
rounding. Volume tolerance max(1e-8 bbl,1e-9 * relevant volume); MD tolerance
max(1e-6 ft,1e-9 * shoe MD). Covers T02, T06, T07, T11.

## Task 4: Migrate interval/state representation and preserve legacy calls

**Depends on:** Task 3.

**Files:**
- Create: `SimuUtils\src\oilfield\fluid_placement.jl`,
  `SimuUtils\test\test_fluid_placement.jl`.
- Modify: `SimuUtils\src\oilfield\oilfield.jl`, `SimuUtils\src\SimuUtils.jl`,
  `SimuUtils\test\runtests.jl`.
- Modify: `SimuHydraulics\src\models\placement.jl`,
  `SimuHydraulics\src\SimuHydraulics.jl`,
  `SimuHydraulics\test\test_placement.jl`, and identified direct constructors.

**Steps:**
1. Add failing compatibility tests for existing FluidInterval and WellState
   constructors and uniform-pair entry points.
2. Define stage identity independent of Fluid equality: initial mud and void
   need explicit non-pumped identities; stage IDs reference schedule indices.
   Define rate-free `DisplacementStage` and shared interval/state types in
   SimuUtils. Convert PumpStage entries in the SimuHydraulics adapter, preserving
   original stage indices; do not move PumpStage into SimuUtils.
3. Attach profile and per-stage pumped-return accounting to the state using the
   smallest concrete/parametric representation that preserves legacy use.
4. Preserve old scalar capacity fields only where genuinely uniform. For
   nonuniform states use an explicit absence/error with migration documentation,
   never a deepest-span or averaged value.
5. Preserve the existing meaning of `returns` as returned pumped fluid; add
   separately named total surface returns.
6. Add legacy constructor adapters and migrate internal consumers before they
   receive multi-geometry states.
7. Run `test_placement.jl` and constructor-dependent selectors; commit.
   Also run SimuUtils `test_fluid_placement.jl` without loading SimuHydraulics;
   verify exported type identity from both packages. Commit each repository's
   bounded changes separately, maintaining compatible revisions.

**Expected:** no type-unstable untyped bags, hidden capacity substitution, or
changed legacy numeric results. Covers T01, T14, T15.

## Task 5: Implement stage-aware profile transport without free-fall

**Depends on:** Tasks 3 and 4.

**Files:** modify `SimuUtils\src\oilfield\fluid_placement.jl`,
`SimuUtils\test\test_fluid_placement.jl`, and the delegating
`SimuHydraulics\src\models\placement.jl` /
`SimuHydraulics\test\test_placement.jl`.

**Steps:**
1. Add failing early-entry, shoe-arrival, annular-ascent, over-displacement,
   identical-fluid-stage, and boundary-crossing tests.
2. Run SimuUtils `test_well_geometry.jl` and `test_fluid_placement.jl`;
   run SimuHydraulics `test_placement.jl` separately.
3. Truncate each schedule stage to actual injected volume Q. For injected range
   [s0,s1], map [Q-s1,Q-s0] to the circulation coordinate.
4. Split at shoe and all geometry boundaries; map pipe x through inverse_P(x)
   and annular x through inverse_A(Vp+Va-x). Sort outputs by increasing MD.
5. Fill untouched volumes with original mud. Compute per-stage retained and
   returned volumes independently of fluid color/name.
6. Assert synthetic-map values: Q=2 gives pipe front 150 ft; Q=6 gives annular
   front 275 ft; Q=14 gives annular front 200/3 ft.
7. At multiple intermediate Q values assert both volume balances and total
   surface returns Q, including before any pumped fluid returns.
8. Run `test_placement.jl` plus legacy placement regressions; commit.
   Run core assertions in `test_fluid_placement.jl` against rate-free stages;
   the SimuHydraulics adapter must not contain a second transport implementation.

**Expected:** a stage never starts at the bottom of the pipe. Covers T03-T08,
T14-T15 and the no-void portions of T01.

## Task 6: Implement exact balanced-plug and primary planning

**Depends on:** Task 5.

**Files:** modify `SimuHydraulics\src\jobs\plug.jl`,
`SimuHydraulics\src\jobs\primary.jl`,
`SimuHydraulics\test\test_plug.jl`, `SimuHydraulics\test\test_primary.jl`.

Job-specific balanced-plug and primary sizing remain in SimuHydraulics.
Use SimuUtils's public cumulative-map/interval-volume operations; do not access
its private prefix-array layout or move cement-specific planners into SimuUtils.

**Steps:**
1. Add failing synthetic-map plan tests: Vc=6, Vsa=2 must give zc=200,
   zs=150, Vsb=1, Vdisp=2 in canonical units.
2. Add physical profile tests for interfaces crossing section boundaries and
   invalid volumes, zero spacer, zero cement, and zero remaining displacement.
3. Run `test_plug.jl` and `test_primary.jl`.
4. Solve zc=inverse_(P+A)(Vp+Va-Vc); solve zs=inverse_A(A(zc)-Vsa);
   compute Vsb=P(zc)-P(zs), Vdisp=P(zs).
5. Implement primary volumes A(L)-A(ztoc), P(L)-P(zfc), and P(zfc);
   validate 0 <= ztoc <= L and 0 <= zfc <= L.
6. Add profile-aware job constructors without silently changing old positional
   constructors. Route schedule/run/final-state methods through the profile.
7. Keep fixed displacement stages; reject their sum above the target and omit
   a zero remainder rather than force a positive-only stage constructor.
8. Test different ahead/behind density sequences as geometric plans with
   explicit residual pressure, not a claim of hydrostatic balance.
9. Run planning and placement selectors; commit.

**Expected:** final zero-void cement tops agree across paths when planned, and
all volumes match independently integrated values. Covers T09-T11.

## Task 7: Integrate local hydraulics and exact clipping

**Depends on:** Task 5.

**Files:** modify `SimuHydraulics\src\models\pressures.jl`,
`SimuHydraulics\src\models\ecd.jl`,
`SimuHydraulics\test\test_pressures.jl`, `SimuHydraulics\test\test_ecd.jl`.

**Steps:**
1. Add failing local-diameter friction and partial-depth clipping tests, including
   a check depth inside a span and equivalent vertical/deviated geometry.
2. Run `test_pressures.jl` and `test_ecd.jl`.
3. Intersect fluid/geometry spans; evaluate existing gradient helpers per local
   ID/OD and multiply by local MD length. No new minor-loss correlation.
4. Replace scalar-capacity clipping with profile interval volumes. Hydrostatics
   remain density times existing TVD-based pressure primitive.
5. Reuse the segmented calculation for pump pressure, free-fall rate, ECD,
   EMW, differential pressure, and formation checks.
6. Preserve pressure signs and surface-line-only pump-loss behavior.
7. Verify independent sums of existing gradient functions, not only agreement
   between two new profile functions; run selectors and commit.

**Expected:** no fallback to one Casing pair anywhere on a multi-geometry
hydraulics path. Covers T12, T16-T17 and uniform regressions.

## Task 8: Add profile-aware void transport and timeline

**Depends on:** Tasks 5 and 7.

**Files:** modify `SimuUtils\src\oilfield\fluid_placement.jl`,
`SimuUtils\test\test_fluid_placement.jl`,
`SimuHydraulics\src\models\placement.jl` (adapter only),
`SimuHydraulics\src\models\timeline.jl`,
`SimuHydraulics\test\test_placement.jl`,
`SimuHydraulics\test\test_timeline.jl`.

**Steps:**
1. Add failing void tests crossing inner geometry boundaries and reaching Vp;
   reject void < 0 or > Vp.
2. Place the void over [0,inverse_P(V0)]. For a pumped stage's transport
   coordinate x0=Q-s, use x=x0+V0 before pipe/annular inverse mapping.
   The initial-mud front uses Q+V0; void is not injected fluid.
3. Assert liquid+void=Vp+Va, retained pumped+returned pumped=Q,
   total surface returns=Q+V0, including column-limited states.
4. Run placement tests; then add failing implicit-timeline tests with the profile.
5. Pass cached profile maps into the existing backward-Euler residual; retain
   regular samples, stage boundaries, zero, final sample, and current rate rules.
   The residual and free-fall rate solver stay in SimuHydraulics. SimuUtils only
   maps the caller-supplied void volume to a conservative placement state.
6. Ensure `TimelinePoint` can hold the migrated state without Any fields and
   keep selected snapshot semantics independent of display units.
7. Run `test_placement.jl`, `test_timeline.jl`, `test_plug.jl`; commit.

**Expected:** the free-fall approximation is preserved, not replaced by an
unvalidated dynamic model. Covers T13, T14, T22.

## Task 9: Integrate profile-based existing force outputs

**Depends on:** Tasks 7 and 8.

**Files:** modify `SimuHydraulics\src\models\forces.jl`,
`SimuHydraulics\src\models\timeline.jl`,
`SimuHydraulics\src\plots\cementing.jl` (`forces_table` only),
`SimuHydraulics\test\test_forces.jl`.

**Steps:**
1. Add failing segmented steel-weight, fluid-weight, buoyancy, and hook-load
   tests, with differing weights and outside fluids across sections.
2. Run `test_forces.jl`.
3. Sum local existing force primitives over geometry/fluid/trajectory
   intersections. Label derived nominal weight versus entered nominal weight.
4. Use local shoe/collar bore/steel area for existing piston/bump products;
   document that shoulder forces and a full stepped-string equilibrium are absent.
5. Wire timeline piston values and force tables to the same selected state.
6. Reject unsupported/missing required inputs explicitly; never insert zero
   into positive-only CsgWeight or silently select the deepest section.
7. Run force and timeline selectors; commit.

**Expected:** T17 and legacy force regressions pass without introducing
contact-friction or shoulder mechanics.

## Task 10: Render actual inner/outer profiles and fluid interfaces

**Depends on:** Tasks 5, 8, and 9.

**Files:** modify `SimuHydraulics\src\plots\cementing.jl`,
`SimuHydraulics\test\test_plots.jl`.

**Steps:**
1. Add failing render-data tests for inner ID/OD transitions, outer transitions,
   open hole with no OD, exact interface MDs, and both plot entry points.
2. Run `test_plots.jl`.
3. Adapt vertical rectangles and deviated ribbons to local pipe and annular
   boundaries; include every profile boundary in shared ribbon vertices.
4. Remove fabricated open-hole OD requirements. Draw physical bore boundaries
   and use gauge/effective ID annotations.
5. Preserve reversed depth axis, width exaggeration, trajectory projection,
   section metadata, and display-unit conversion.
6. Add stage-aware annotations and distinct void/initial/pumped-return labels.
7. Run tests; visually inspect standalone and dashboard at early entry, shoe
   crossing, annular ascent, and final placement, vertical and deviated; commit.

**Expected:** all plotted interfaces correspond to state intervals; no rendering
code recalculates placement. Covers T20 and presentation portions of T15.

## Task 11: Integrate notebook geometry, planning, and stage reports

**Depends on:** Tasks 6, 8, 9, and 10.

**Files:** modify `SimuHydraulics\notebooks\plug_job.jl`;
review/update `SimuHydraulics\notebooks\cementing_job.jl` where shared behavior applies.

**Steps:**
1. Inspect current cells and Pluto bindings again; preserve unsaved/user edits
   and existing cell identifiers. Do not overwrite with an earlier transcript.
2. Build one profile from current r/c/h/i rows with explicit source labels.
   Replace `_active` filtering of malformed input with validated row adaptation.
3. Remove deepest-pair proxies from placement, capacities, job sizing,
   timeline, force reporting, and schematic calls.
4. Derive Length from Bottom-Top; rename migrated excess as hole-area excess.
   Keep gauge and effective ID separate without rounding computation.
5. Preserve `sl_len`, `sl_id`, manual/CSV controls, and survey coverage checks.
   Default survey coverage must reach the active shoe before running hydraulics.
6. Size stages from the profile planner. Use stage IDs for both pipe/annulus
   positions; remove the fluid-keyed minimum-top dictionary as sole reporting.
7. Sum section capacities/volumes using exact intersections, not midpoint lookup.
   Label total pipe volume separately from any local capacity; do not show a
   single capacity as representative of a nonuniform string.
8. Use the selected timeline state for state-dependent tables/forces/plots.
   Label a separate planned static end state explicitly and show residual void.
9. Mark unused material/A-L/friction/additional fields as metadata; do not imply
   new physics. Keep zero-volume plug markers as markers.
10. Run a clean Pluto session through manual and CSV surveys, both job modes,
    auto/manual sizing, API/SI/COMBINED, and pressure overrides; document results.

**Expected:** T19, T21, T22 pass. If any dependent output is not implemented,
show an explicit unsupported message and do not release the feature as complete.

## Task 12: Add cross-surface acceptance tests and migration coverage

**Depends on:** Tasks 6 through 11.

**Files:** extend `SimuUtils\test\test_well_geometry.jl`,
`SimuUtils\test\test_fluid_placement.jl`, `SimuUtils\test\test_structure.jl`,
`SimuUtils\test\test_extension.jl`, and existing
`SimuHydraulics\test\test_{placement,plug,primary,pressures,ecd,forces,timeline,plots,units,structure}.jl`
and `SimuHydraulics\test\fixtures.jl` as needed.

**Steps:**
1. Map every specification test T01-T22 to a named automated test or explicit
   notebook/visual verification record; identify missing assertions.
2. Add independent physical-diameter and synthetic-map expectations, including
   a long outer span crossing several inner sections.
3. Test identical fluid objects reused by multiple stages, partially returned
   stages, zero spacer, exact displacement remainder, and exact section boundaries.
4. Test equivalent units without altering current UnitSet constants.
5. Test legacy constructors and public calls, failure messages, input identity,
   missing trajectory coverage, and the absence of fake scalar capacities.
6. Prove SimuUtils loads and executes geometry/transport without SimuHydraulics
   or a plotting backend. Verify shared type/function identity in a separate
   SimuHydraulics process, then run both packages' full regression commands.
7. Commit only test and tightly coupled implementation corrections.

**Expected:** all 22 acceptance scenarios are accounted for; no pass claim rests
solely on two new helpers agreeing with one another.

## Task 13: Document APIs, migration, and actual physical limitations

**Depends on:** Tasks 11 and 12.

**Files:**
- Modify: `SimuUtils\README.md` and public docstrings under
  `SimuUtils\src\oilfield\{well_geometry,fluid_placement}.jl`.
- Modify: `SimuHydraulics\docs\src\index.md`.
- Modify: `SimuHydraulics\README.md` if its usage examples need profile entry points.
- Modify: directly changed public docstrings under `SimuHydraulics\src`.
- Modify links only: `SimuUtils\docs\superpowers\specs\2026-10-27-multi-geometry-displacement-and-placement.md`.

**Steps:**
1. Document geometry/transport APIs in SimuUtils and imported integration APIs
   in SimuHydraulics. Do not list new SimuUtils files as SimuHydraulics source.
2. Show one uniform backward-compatible example and one stepped geometry example.
3. Document state/constructor migration, stage IDs, total versus pumped-fluid
   returns, derived weight, hole-area excess, and the surface-line storage exclusion.
4. Explain geometric versus hydrostatic balance, residual void, no POOH
   redistribution, and limits of local piston/shoulder force treatment.
5. Repair relocated specification source links using relative paths to the
   sibling package; leave substantive requirements unchanged.
6. Validate documentation using existing Documenter tooling if available:

```powershell
Push-Location .\SimuHydraulics
try {
    julia --startup-file=no --project=docs .\docs\make.jl
    if ($LASTEXITCODE -ne 0) { throw "Documentation build failed." }
} finally {
    Pop-Location
}
```

7. Commit per repository with explicit paths; do not include unrelated edits
   or the entire untracked SimuUtils documentation tree.

## Task 14: Measure representative workloads and final release gate

**Depends on:** Tasks 12 and 13.

**Files:** no permanent benchmark framework required. Use existing tooling or a
bounded session-local script; change hot paths only if measurements justify it.

**Steps:**
1. Warm up on the same Julia version/environment used for the Task 1 baseline.
2. Measure 1/10/100 spans, 10 stages, approximately 1,000 timeline samples,
   free-fall both off and on. Record elapsed time, allocations, and sample count.
3. Verify cumulative maps are built once and not copied/rebuilt inside implicit
   residuals or per-interval plot calculations.
   Measure SimuUtils placement alone as well as end-to-end SimuHydraulics
   timelines so dependency-boundary conversion costs are visible.
4. If a meaningful regression is demonstrated, fix only the measured hot path;
   rerun focused correctness tests and compare measurements.
5. Rerun the full suite and the clean-session notebook checks after any fix.
6. Inspect diff/status, remove only named session scratch files, and summarize
   compatibility changes, validated cases, limitations, and unresolved blockers.

**Expected:** measured results, not speculative optimization or an invented
wall-clock target. Release only when every required output shares the profile
and no deepest-section approximation remains on multi-geometry execution paths.

## 4. Dependency summary

```text
1 -> 2 -> 3 -> 4 -> 5
                    |-> 6 (planning)
                    |-> 7 (hydraulics) -> 8 (void/timeline) -> 9 (forces)
                    |---------------------> 10 (plots; also needs 8 and 9)
6 + 8 + 9 + 10 -> 11 (notebooks)
6 through 11 -> 12 (acceptance) -> 13 (documentation) -> 14 (final gate)
```

Geometry and arithmetic are prerequisites, not optional parallel experiments.
Do not wire partial profile support into user-visible hydraulic outputs.
When independent branches are useful, planning can proceed independently of
hydraulics after Task 5, with a single agreed profile/state contract.

## 5. Handoff and completion checklist

- [ ] T01-T22 mapped and verified.
- [ ] SimuUtils owns reusable geometry/transport and passes standalone core tests.
- [ ] No SimuUtils dependency on SimuHydraulics or new core plotting-backend load.
- [ ] SimuHydraulics adapters preserve shared type identity and schedule ordering.
- [ ] Uniform-pair APIs retain intended behavior or have documented migrations.
- [ ] No invented open-hole OD, fake average capacity, or deepest-section fallback.
- [ ] Stage identity, volume conservation, and both return counters verified.
- [ ] Balanced/primary plans, hydraulics, forces, and plots use one geometry.
- [ ] Manual/CSV surveys and surface-line bindings work in a clean Pluto session.
- [ ] Geometric balance is not mislabeled as hydrostatic/dynamic equilibrium.
- [ ] Unit definitions and unrelated user changes preserved.
- [ ] Full tests and applicable documentation validation pass; diagnostics reported.
- [ ] Benchmarks recorded and supported limitations documented.

This deliverable is an implementation plan only. Implement in the current
session after explicit authorization, or use a separate execution session with
this plan and its linked specification. Do not start implementation or commit
the current working tree merely because the plan has been saved.
