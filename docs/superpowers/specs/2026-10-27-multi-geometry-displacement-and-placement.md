# Multi-geometry displacement and fluid positioning

Date: 2026-10-27
Status: implementation specification; no implementation included.
Scope: end-to-end geometry consistency, selected in the requirements discussion.
Ownership revision: reusable geometry and placement/displacement primitives
belong to SimuUtils; job orchestration and hydraulics remain in SimuHydraulics.

## 1. Objective

Calculate fluid displacement through a depth-varying inner string and annulus,
using the same validated geometry for planning, transient placement, hydraulics,
forces, tables, and plots.

The flow path shall remain:

**Surface -> down the inner string -> through the shoe -> up the annulus -> surface.**

An expanding pumped-fluid column at the bottom of the annulus is expected.
New fluid must not be injected at the bottom of the pipe.

Primary cementing and balanced-plug jobs shall share the geometry and placement
kernel. Balanced-plug placement is the first notebook integration target.

### Package ownership

- **UomDefinitions:** unit quantities, constants, and conversions.
- **SimuUtils:** reusable serial-well geometry, capacity integration/inversion,
  rate-independent injected stages, fluid interval/state types, conservative
  displacement/placement, caller-supplied void mapping, and return accounting.
  Implement these in the oilfield layer using existing geometry primitives.
- **SimuHydraulics:** PumpStage/rates, cement-job sizing and schedules,
  trajectory-based hydraulics, free-fall time integration, ECD/EMW, forces,
  timelines, notebook input adaptation, and job schematics/reports.

The dependency direction is UomDefinitions -> SimuUtils -> SimuHydraulics.
SimuUtils must not depend on SimuHydraulics or its PumpStage, Trajectory, UnitSet,
or job types. Its new core must load without a plotting backend.

## 2. Current behavior and root cause

The current [plug notebook](../../../../SimuHydraulics/notebooks/plug_job.jl) selects the deepest
inner section and the outer section surrounding its shoe. It constructs one
`Casing` for each and treats their dimensions as constant from surface to shoe.
Its outer plotting profile can show multiple sections, but those drawn
dimensions do not determine the simulated interface depths.

The existing [placement model](../../../../SimuHydraulics/src/models/placement.jl) has the correct
flow direction for a constant-capacity pair. Its scalar `pipe_cap` and `ann_cap`
cannot represent changing capacity. The following consumers also assume a
constant pair:

- [Balanced-plug planning](../../../../SimuHydraulics/src/jobs/plug.jl).
- [Primary-job planning](../../../../SimuHydraulics/src/jobs/primary.jl).
- [Pressure and free-fall calculations](../../../../SimuHydraulics/src/models/pressures.jl).
- [ECD and interval clipping](../../../../SimuHydraulics/src/models/ecd.jl).
- [Forces](../../../../SimuHydraulics/src/models/forces.jl).
- [Timeline](../../../../SimuHydraulics/src/models/timeline.jl).
- [Schematic and dashboard](../../../../SimuHydraulics/src/plots/cementing.jl).

Replacing only the plot or only the total volume is insufficient: each
interface must cross geometry boundaries using the local capacity.

## 3. Design decision and alternatives

Use an immutable, validated, piecewise-constant geometry profile with cumulative
volume maps. This is the recommended design because it preserves exact volume
arithmetic, handles boundaries deterministically, and can reuse existing local
capacity and friction helpers.

Alternatives not selected:

1. A single effective capacity: simpler, but cannot locate interfaces correctly
   within individual sections.
2. A uniformly discretized transport grid: supports later transport physics,
   but introduces grid-dependent placement and unnecessary complexity for the
   present sharp-interface, incompressible model.

Public names below are proposed API concepts, not instructions to introduce
every named helper as a separate exported function.

## 4. Scope and physical assumptions

### Included

- Multiple serial riser, casing/liner, open-hole, and inner-string sections.
- Exact piecewise capacity integration and volume-to-MD inversion.
- Ordered pump schedules, initial well fluid, and tracked pumped-fluid returns.
- Balanced-plug spacer-behind and displacement planning.
- Primary-job cement, shoe-track, and displacement volumes.
- Existing free-fall approximation, using the full geometry profile.
- Geometry-consistent hydrostatics, friction, ECD/EMW, and existing force outputs.
- Vertical and deviated schematics using actual local inner and outer diameters.
- Existing API/SI/COMBINED units and pressure overrides.
- Manual and CSV survey inputs feeding the existing trajectory model.

### Excluded

- Pipe movement during pumping or evolving geometry.
- Cement redistribution after pulling out of hole, swab/surge, or curing.
- Compressibility, mixing, dispersion, losses to formation, or gas transport.
- Parallel annular paths, reverse circulation, or automatic resolution of nested
  casing strings. The caller must provide one effective outer boundary per MD.
- New contact-friction/torque-and-drag physics or material-catalog integration.
- New mechanical models for shoulder forces at diameter transitions.

## 5. Geometry inputs and validation requirements

**G-01.** Each section shall carry top/bottom MD, geometry kind, required
diameters, and source identity. Inner sections shall also retain entered nominal
weight and optional metadata needed for existing outputs.

**G-02.** Accept unit-aware `Length` and `Diameter` inputs. Normalize once at
the model boundary to canonical ft, in, bbl, and bbl/ft using `UomDefinitions`.
Use existing `SimuUtils` capacity primitives rather than duplicate constants.
Display units come from the current `UnitSet`; do not hard-code an old
COMBINED definition.

**G-03.** A row with equal top/bottom MD and all zero geometry is an inactive
placeholder. Invalid nonempty rows must raise an informative error, not be
silently removed by a positive-diameter filter. Active rows require finite,
nonnegative top MD, bottom > top, and positive flow bore.

**G-04.** Normalize each serial string by top MD. Reject gaps, overlapping
active sections, ambiguous outer coverage, invalid diameters, and missing
coverage over [0, shoe MD]. Outer coverage may extend below the inner shoe,
but that region is not part of this circulation path.

**G-05.** Split computational spans at the union of inner and outer boundaries.
Within each span require inner OD > inner ID > 0 and effective outer ID >
inner OD. Cased/riser sections additionally require outer OD > outer ID.
Open hole has no physical steel OD.

**G-06.** Define the shoe as the end of the contiguous active inner string.
Adjacent boundary ownership shall be deterministic, using half-open spans
internally and including the final shoe endpoint.

**G-07.** Use a documented scale-aware tolerance to reconcile unit-conversion
roundoff at shared boundaries. Do not bridge physical gaps, collapse short
valid sections, or round diameters/interface depths for computation.

**G-08.** Treat Bottom - Top as the authoritative length. Show Length as
derived/read-only in the notebook; if externally supplied, validate consistency.

### Open-hole excess convention

The existing `_osec` scales gauge-hole area:

`effective_ID = gauge_ID * sqrt(1 + excess_percent / 100)`.

Preserve this convention for migrated inputs and label it **hole-area excess**,
not annular excess. Display gauge and effective ID separately; never fabricate
a physical OD or steel weight for open hole.

If true annular-area excess is added later, make it an explicit separate
convention. It would instead satisfy:

`effective_ID^2 = inner_OD^2 + (gauge_ID^2 - inner_OD^2) * (1 + excess/100)`.

Do not silently reinterpret existing excess values. Require finite,
nonnegative excess.

## 6. Shared profile and cumulative volume maps

SimuUtils owns this profile and the reusable operations in Sections 6-7.
SimuHydraulics consumes their public API, not private prefix-array layout.

For each normalized span store its MD bounds, local inner ID/OD, effective
outer ID, geometry/source references, and capacities:

- `Cp(z)`: pipe internal capacity [bbl/ft].
- `Ca(z)`: annular capacity [bbl/ft].

For shoe MD `L`, define:

- `P(z) = integral(0, z, Cp(s) ds)`.
- `A(z) = integral(0, z, Ca(s) ds)`.
- `Vp = P(L)` and `Va = A(L)`.

Both maps are continuous, strictly increasing, and piecewise linear.
Implement interval volume and inverse cumulative-volume lookup on this shared
representation. Locate the containing span and interpolate locally; do not
search MD with a uniform grid or repeatedly integrate the entire profile.

The circulation-path volume coordinate is:

- Pipe at MD z: `x = P(z)`, increasing downhole from 0 to Vp.
- Annulus at MD z: `x = Vp + A(L) - A(z)`, increasing uphole to Vp + Va.

Map inverse results back to MD through the appropriate pipe/annular map.
Use MD for volumes and friction lengths; use trajectory TVD differences for
hydrostatics. Inclination must not change the geometric volume of an MD span.

## 7. Fluid placement and conservation

**P-01.** Preserve schedule order and stage identity, even when adjacent stages
use fluids of identical type, density, or color. Do not use a fluid-keyed
dictionary as the only source of per-stage position reporting.

Use rate-independent stages (fluid, typed volume, stable stage ID) in SimuUtils.
SimuHydraulics adapts its PumpStage schedule without moving job/rate semantics
into SimuUtils. Shared interval/state types are defined once in SimuUtils;
existing SimuHydraulics names shall import/re-export them where compatible.

**P-02.** With no void, a stage pumped over cumulative injection coordinates
[s0, s1] occupies circulation-path coordinates [Q - s1, Q - s0] at total
pumped volume Q, clipped to the actual injected part and retained flow path.
Coordinates beyond the return outlet represent returned pumped fluid.

**P-03.** Initially both paths contain the original well fluid. Fill all
remaining in-well regions with that fluid; do not create an empty pipe before
the first stage. Original mud begins returning as soon as pumping starts.

**P-04.** Pumped fluid first appears at the pipe top, moves toward increasing
MD, crosses the shoe, and then moves toward decreasing annular MD. Later
injected fluid pushes earlier fluid ahead; rendering order cannot alter this.

**P-05.** Split intervals at fluid interfaces and geometry boundaries. Each
interval volume must equal its exact local capacity integral. Both pipe and
annulus interval lists remain ordered by increasing MD.

**P-06.** State shall expose the geometry profile, stage-aware intervals, total
pumped volume, void volume, and pumped-fluid return accounting. Geometry-aware
states must not publish a scalar capacity that silently substitutes for the
profile. Retain legacy scalar behavior only for uniform legacy states.

**P-07.** Distinguish:

- Returned pumped fluids, preserving the existing `returns` meaning.
- Total surface returns, including displaced original well fluid.

For an incompressible, full well with no losses:

- `retained pumped fluid + returned pumped fluid = actual pumped volume`.
- `pipe liquid + annular liquid + pipe void = Vp + Va`.
- `total surface returns = actual pumped volume + current void volume`
  when the initial void is zero.

Report these quantities with unambiguous labels.

## 8. Free-fall and timeline consistency

SimuUtils maps a supplied void volume into placement. The free-fall rate solver,
implicit time integration, and timeline belong to SimuHydraulics.

Retain the current approximation: a void of volume V0 occupies the top of the
pipe, with `0 <= V0 <= Vp`. Locate its base with `inverse_P(V0)`, not
`V0 / constant_capacity`.

Liquid below the void occupies Vp - V0. Advancing the column due to free-fall
must preserve stage ordering, actual injected volume, and the balances above.
Do not count void growth as extra injected fluid. Retain the current physical
limitations explicitly; this is not a multiphase falling-jet model.

The implicit void solver and free-fall rate calculation shall use the same
profile as placement and friction. Cache geometry maps outside repeated
timeline residual evaluations.

Tables, schematics, forces, and selected-state reports shall consume the same
timeline state. A separate static, zero-void planned end state may be shown only
when labeled as such. Show residual void and pressure imbalance at pump stop;
do not claim a settled balanced plug while those conditions remain unresolved.

Timeline sampling shall include zero, stage boundaries, final volume, and the
existing regular pumped-volume samples. Changing display units must not change
the state selected by pumped fraction.

## 9. Displacement and job planning

### Balanced plug

The standard planner assumes a common cement-top MD zc and a common
spacer-top MD zs in both paths, with `0 <= zs <= zc <= L`.
For cement volume Vc and total spacer-ahead volume Vsa:

1. Solve `Vc = [P(L) - P(zc)] + [A(L) - A(zc)]`.
2. Solve `Vsa = A(zc) - A(zs)`.
3. Set spacer-behind volume `Vsb = P(zc) - P(zs)`.
4. Set displacement volume `Vdisp = P(zs)`.

Use inverse cumulative maps, including the combined pipe-plus-annulus map.
Reject infeasible volumes before schedule construction. Zero spacer is valid;
zero cement is not a meaningful balanced-plug plan.

The resulting schedule is spacer ahead -> cement -> spacer behind ->
displacement. Auto-sizing may adjust only explicitly designated stages.
Additional fixed displacement stages subtract from Vdisp; reject an excess,
and define zero remaining displacement as a valid omitted zero-volume stage.

Multiple fluids ahead require ordered allocation through the annular map,
not a density-blind claim of hydrostatic balance. Equal interface MDs imply
hydrostatic balance only when corresponding fluid columns and densities match
in both paths. For differing ahead/behind density sequences, label the result
as geometric placement and report the remaining differential pressure; a
general pressure-balanced optimization is outside this increment.

### Primary cementing

For top of cement ztoc and float-collar MD zfc:

- Annular cement = `A(L) - A(ztoc)`.
- Shoe-track cement = `P(L) - P(zfc)`.
- Total cement = annular cement + shoe-track cement.
- Displacement to collar = `P(zfc)`.

Validate depth ordering. Preserve existing assumptions about marker-only plugs;
do not add mechanical plug dynamics as part of geometry support.

## 10. Hydraulics and forces

**H-01.** Intersect fluid intervals, geometry spans, and required trajectory
segments. Evaluate existing pipe/annular friction correlations using local
diameters and MD length. Do not introduce contraction/expansion minor-loss
correlations without a separately documented model.

**H-02.** Hydrostatic pressure uses each fluid's density and trajectory TVD
difference. Geometry changes affect placement and therefore fluid heads,
not a new capacity multiplier on hydrostatic pressure.

**H-03.** Partial-depth clipping for differential pressure, ECD/EMW, and
formation checks must recompute retained volumes with the profile. Remove
constant-capacity assumptions in `_above` and equivalent paths.

**H-04.** Preserve pressure signs, free-fall conventions, surface-line behavior,
and equivalent-density definitions. The surface line adds pump friction only;
its storage volume is not part of this downhole transport model.

**H-05.** Calculate fluid weight from exact interval volumes and density.
Calculate steel weight, existing buoyancy, and frictionless hook-load outputs
span by span using local weight, geometry, fluid exposure, and trajectory.
Reject missing required weight inputs or use an explicitly labeled OD/ID-derived
steel-weight estimate. Never construct a positive-only `CsgWeight` from zero.

**H-06.** Evaluate existing shoe piston and plug-bump area products using the
local section at the applicable shoe/collar. Label these as the existing local
area-force model, not a complete stepped-string hydraulic-force solution.
Shoulder-pressure forces and a new mechanical equilibrium solver are excluded.

No end-to-end result may silently fall back to the deepest section's dimensions.
During development, unsupported outputs must be explicitly unavailable rather
than show plausible constant-geometry values.

## 11. Notebook, reports, and plotting

- Build one validated profile from all active outer and inner inputs.
- Replace deepest-section capacity proxies in the plug notebook.
- Wire shared primary-job paths and review the cementing notebook as applicable.
- Render local inner ID/OD as well as local outer dimensions; split fluid bands
  at boundaries and retain identical MD interfaces across schematic/table views.
- Both standalone and dashboard renderers shall use the same profile and state.
- Preserve depth-axis orientation, display-unit conversion, trajectory mapping,
  section labels, and explicit width-exaggeration labeling.
- Show per-section volume using exact intersections of all overlapping inner
  and outer spans, not the inner section sampled at the outer midpoint.
- Report each stage's pipe/annular intervals separately. A single minimum-MD
  "top" must not imply that a stage occupies only one side of the well.
- Clearly distinguish initial fluid, pumped stages, void, and surface returns.
  Reused colors must not erase stage identity from data or tabular reporting.
- Keep manual/CSV survey validation; require trajectory coverage through all
  displayed sections and the simulated shoe, or explicitly clip the display.
- Preserve surface-line input bindings. Materials, A/L, contact friction, and
  additional-properties fields remain metadata unless a supported model uses
  them; label unused inputs so they do not imply an effect on results.
- Remove obsolete midpoint capacity calculations and synthetic open-hole OD
  dependencies from tables, geometry adapters, and plotting validation.

## 12. API compatibility and implementation sequence

Retain existing constant-pair entry points and return semantics where possible.
Adapt a legacy outer/inner `Casing` pair to a single-span profile so that it
shares the new algorithm rather than maintaining a second placement engine.
If state fields or positional constructors must change, document the migration;
do not manufacture a misleading average capacity for compatibility.

Follow the existing calcs -> models -> jobs -> plots dependency direction.
This is the internal SimuHydraulics layering, not the ownership of the reusable
core. In SimuUtils preserve helpers -> geometry -> oilfield -> plots layering;
new well geometry/transport belongs in oilfield after its Casing/Fluid dependencies.
Keep geometry and simulation logic out of Pluto cells.

Suggested implementation increments:

1. SimuUtils geometry, cumulative maps, integration/inversion, and unit tests.
2. SimuUtils stage-aware placement, returns, and void mapping; SimuHydraulics
   schedule/legacy adapters and uniform-case regression.
3. Balanced/primary planning and notebook auto-sizing.
4. Profile-aware hydraulics, timeline, ECD, and existing force outputs.
5. Notebook, schematics, tables, reports, and compatibility documentation.

Each increment must preserve working legacy behavior. Multi-geometry mode is
not complete until all five increments are integrated and validated.

## 13. Verification and acceptance criteria

Use existing Julia test organization and fixtures in each package. Add focused
SimuUtils geometry/placement tests that run without SimuHydraulics or a plotting
backend. Extend SimuHydraulics adapter, plug, primary, timeline, pressure, ECD,
force, and plot tests. Verify shared type identity and the one-way dependency
boundary. Do not rely solely on screenshots or agreement between two functions
that share the same integration helper.

For canonical numerical checks, use:

- Volume tolerance: `max(1e-8 bbl, 1e-9 * relevant total volume)`.
- MD tolerance: `max(1e-6 ft, 1e-9 * shoe MD)`.
- Pressure/force regression tolerance: existing test tolerance, or a justified
  documented scale-aware tolerance if no baseline exists.

### Required test matrix

| ID | Case | Required result |
|---|---|---|
| T01 | One uniform pair | Placement, planned volumes, hydraulics, and forces match existing behavior within tolerance. |
| T02 | Misaligned inner/outer boundaries | Union spans and local capacities match independent hand calculations. |
| T03 | Small first injected volume; no void | Fluid starts at MD 0 inside pipe; annulus remains original well fluid. |
| T04 | First fluid reaches shoe | Arrival occurs at Q = P(L), not deepest-section capacity times L. |
| T05 | Entry into annulus | First pumped fluid appears at shoe, then moves toward lower annular MD. |
| T06 | Interface crosses a capacity change | MD advance per barrel changes with local capacity; interface and volume remain continuous. |
| T07 | Exact boundary and tiny residual | No negative/duplicate/phantom intervals; deterministic boundary ownership. |
| T08 | Cement and spacers span transitions | Independent cumulative-volume calculations reproduce all interface depths. |
| T09 | Balanced plug | Cement/spacer tops agree across both paths; planned volumes conserve injected fluid. |
| T10 | Primary job crossing boundaries | Cement, track, and displacement match exact interval integrals. |
| T11 | API/SI/COMBINED equivalents | Converted inputs yield identical canonical geometry and results. |
| T12 | Vertical and deviated surveys | Equal MD geometry gives equal volumes; hydrostatics use appropriate TVD. |
| T13 | Void crosses inner boundaries | Void base is inverse_P(V0); ordering and all balances hold. |
| T14 | Original-fluid and pumped-fluid returns | Distinct counters satisfy their documented conservation identities. |
| T15 | Same fluid in multiple stages | Per-stage reporting remains distinct, including partially returned stages. |
| T16 | Partial-depth pressure/ECD | Clipping within a geometry span matches independent segmented sums. |
| T17 | Friction and force segmentation | Local geometry sums match independently assembled existing-correlation results. |
| T18 | Invalid geometry/input | Gaps, overlaps, interference, NaN/Inf, infeasible plans, and missing coverage fail with source-aware errors. |
| T19 | Outer span crosses several inner spans | Summary volume equals exact intersection sum, not midpoint approximation. |
| T20 | Plot geometry/state correspondence | Rendered inner/outer boundaries and fluid MD interfaces match the profile/state in both renderers. |
| T21 | Notebook clean-session execution | No missing bindings or stale globals; manual/CSV paths and both job modes work. |
| T22 | Planned versus transient final state | Reports use the selected state, or clearly label a separate zero-void plan. |

### Independent arithmetic fixture

Use a synthetic capacity-map fixture with MD bounds [0, 100, 300] ft,
pipe capacities [0.01, 0.02] bbl/ft, and annular capacities [0.03, 0.04]
bbl/ft. This tests map arithmetic independently of diameter conversion:

- P(L) = 5 bbl; A(L) = 11 bbl.
- P(150) = 2 bbl; inverse_P(2) = 150 ft.
- At Q = 2 bbl, a sufficiently long first stage occupies pipe MD 0-150 ft.
- At Q = 6 bbl, 1 bbl of that stage occupies annular MD 275-300 ft.
- At Q = 14 bbl, 9 bbl occupy annular MD 200/3-300 ft.
- For Vc = 6 bbl and Vsa = 2 bbl, zc = 200 ft, zs = 150 ft,
  Vsb = 1 bbl, and Vdisp = 2 bbl.

Also test physical-diameter fixtures with separately calculated capacities;
the synthetic fixture does not replace capacity-unit validation.

### Performance and completion

Measure representative 1-, 10-, and 100-span cases with 10 pumping stages and
approximately 1,000 timeline samples, both without and with free-fall. Record
runtime and allocations against the existing single-pair baseline on the same
Julia version and machine. Build prefix maps once, avoid per-sample rebuilding,
and investigate demonstrated allocation/runtime regressions before release.
No arbitrary wall-clock threshold is imposed without a measured baseline.

Completion requires the focused tests, both packages' regression suites, and clean
notebook execution to pass; a visual review of early pipe entry, shoe crossing,
annular ascent, and balanced final placement; and updated public docstrings
and user-facing documentation. Document intentional output-shape changes.

## 14. Delivery constraints

This specification authorizes no implementation or package dependency changes
by itself. The implementation must preserve unrelated working-tree edits,
follow existing Julia conventions, and keep public APIs small and documented.
Any further scope expansion or physical-model change requires explicit review.
