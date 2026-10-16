# SimuUtils

[![Build Status](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/pptav0/SimuUtils.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/pptav0/SimuUtils.jl)

Shared utilities for the Simulytics hydraulics-simulation platform: numeric and regression helpers, wellbore geometry, oilfield types (casings, fluids, rheology) and optional Makie plotting. SimuUtils is the common dependency of the simulation packages (notably [SimuHydraulics](https://github.com/pptav0/SimuHydraulics.jl)).

## What's inside

The source tree is layered and the dependency arrow points left only — **helpers → geometry → oilfield → plots** — enforced by `test/test_structure.jl`.

- **Helpers** (`src/helpers/`) — `round_to` (round-half-even to *n* decimals); `linear_regression`, `non_linear_regression` (quadratic) and `calculate_r_squared`, all validated: mismatched or too-short vectors raise `ArgumentError`, non-finite entries `InvalidValueError`; a constant `Y` gives R² = 1 for an exact fit and 0 otherwise.
- **Geometry** (`src/geometry/capacity.jl`) — one unit-aware core, `annulus_capacity(od, id; xs, out)`, covering rings and full circles (optional excess-area factor `xs` for hole washout); `circle_capacity`, `hole_capacity`, `pipe_capacity`, `pipe_displacement`; volumes via `capacity_volume`, `annulus_volume`, `circle_volume`. Results are UomDefinitions `Capacity` / `Volume` quantities whose unit is chosen with `out=`.
- **Oilfield types** (`src/oilfield/`)
  - `Casing(od::Diameter, id::Diameter; hanger, depth, thread, grade, burst, collapse)` with `Length` depths, `Pressure` ratings and a computed nominal weight `CsgWeight{PPF}`; helpers `calc_casing_weight`, `calc_casing_id`, `calc_capacity` (bore or annulus between two casings), `Thread`, `STEEL_DENSITY`.
  - `Fluid(kind::FluidType, name, density::Density, rheo::RheoModel)` and the keyword form `Fluid(kind, name, density; yp, pv)` → Bingham; `yp` / `pv` accessors give the Bingham equivalent of any model. A `Real` + `DensityUnit` form is kept for convenience; it builds the `Density`.
  - Rheology: `Newtonian`, `PowerLaw`, `Bingham`, `HerschelBulkley`, `GeneralizedHB` (`RheoModel`), `shear_stress`, `apparent_viscosity`, `yield_stress`, `bingham_equivalent`, `fit_rheology` (closed form or BlackBoxOptim) and the Fann-35 toolkit (`FannReadings`, `FannRheology`, `FannInputs`, `Rotor`/`Bob`/`Spring`, `calc_shear_rate`, `calc_shear_stress`).
- **Plotting** (`src/plots/plots.jl` + `ext/SimuUtilsMakieExt.jl`) — `plot_regression`, `plot_rheology`, `plot_well_schem`. The core package declares them without methods; the `SimuUtilsMakieExt` package extension attaches the CairoMakie implementations when **both** `CairoMakie` and `MakieThemes` are loaded. SimuUtils itself never depends on a plotting backend.

## Contracts

- **Dependency contract.** `UomDefinitions → SimuUtils → SimuHydraulics`. Every unit type, singleton, `to_*` conversion and physical constant comes from [UomDefinitions](../UomDefinitions); SimuUtils defines no unit conversions of its own.
- **Typed inputs.** Physical parameters are UomDefinitions quantities (`Diameter`, `Length`, `Density`, `Pressure`, `Capacity`, `Volume`); the unit travels with the value, so there are no `unit=` input keywords, only `out=` for the result. Dimensionless values (washout `xs`, flow index `n`, dial readings, R²) stay `Real`. Mixed units are fine: `annulus_capacity(Diameter(8.5, inch), Diameter(127.0, mm))`.
- **Error types.** Finiteness and sign are checked once, in the UomDefinitions constructors (`InvalidValueError`, `NegativeValueError`, `ZeroValueError`). SimuUtils adds geometric and model guards with the same types (`ZeroCapacityError` for `od == id`) and uses `ArgumentError` only for structural problems: mismatched lengths, empty input, too few points, a hanger below the setting depth, an empty name.
- **Constructors.** Each struct validates in a single inner constructor; outer constructors only convert and delegate. Mutating a field afterwards bypasses the checks.

## Usage

```julia
using SimuUtils
using UomDefinitions: Diameter, Length, Density, inch, mm, ft, m, ppg, sg, l_m, m3_m, m3

# every physical input is a typed quantity; the unit travels with the value
hole, csg = Diameter(8.5, inch), Diameter(5.0, inch)

cap    = annulus_capacity(hole, csg)                        # 0.0459 bbl/ft
cap_xs = annulus_capacity(hole, csg; xs=0.2)                # with 20 % excess
annulus_capacity(hole, Diameter(127.0, mm); out=l_m)        # mixed units in, L/m out
hole_capacity(hole)                                         # 0.0702 bbl/ft
capacity_volume(cap, Length(5000.0, ft))                    # 229.48 bbl

# casings and fluids
c7 = Casing(Diameter(7.0, inch), Diameter(6.276, inch); hanger=Length(0.0, ft), depth=Length(3000.0, ft))
c7.wt                                                       # 25.69 ppf (computed)
calc_capacity(c7)                                           # bore capacity, bbl/ft
mud = Fluid(OBM, "OBM 10 ppg", Density(10.0, ppg); yp=10.0, pv=30.0)
yp(mud), pv(mud)

# rheology from Fann-35 readings
r = FannReadings(60, 35, 28, 19, 14, 10, 4, 3)
hb, r2 = fit_rheology(HerschelBulkley, FannInputs(r))

# regression helpers
slope, intercept = linear_regression(X, Y)
r2 = calculate_r_squared(Y, slope .* X .+ intercept)

# plotting: load the two triggers and the extension attaches the methods
using CairoMakie, MakieThemes
plot_regression(X, Y, X, slope .* X .+ intercept, :linear; title="Fit",
                annotations=Dict{AbstractString,Float64}("R²" => r2))
plot_well_schem([c7], Casing[]; units=ft)
```

## Tests

Tests follow a **Normal / Edge / Failure** layout per source file (typical inputs; physical or numerical limits; rejected inputs with the documented error type). Run the full suite from the package directory:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

`Pkg.test()` builds the test environment from the test target, which adds `CairoMakie` and `MakieThemes`, so the extension tests run. An in-process run (`julia --project=. -e 'using Test, SimuUtils; include("test/runtests.jl")'`) uses the package environment, where the plotting triggers are absent; `test_extension.jl` and `test_wellbore.jl` then skip with a warning and the rest of the suite runs.

## Documentation

Documentation is the docstrings: every exported name answers `?name` in the REPL (enforced by `test/test_structure.jl`). There is no separate documentation site.

## Installation

Requires Julia ≥ 1.11. The package is not registered; use it via a local path or the repo URL:

```julia
using Pkg
Pkg.develop(path="path/to/SimuUtils")
```
