# SimuUtils

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://pptav0.github.io/SimuUtils.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://pptav0.github.io/SimuUtils.jl/dev/)
[![Build Status](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/pptav0/SimuUtils.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/pptav0/SimuUtils.jl)

Shared utilities for the Simulytics hydraulics-simulation platform: numeric helpers, regression fitting, wellbore geometry, and Makie-based plotting. SimuUtils is the common dependency of the simulation packages (notably [SimuHydraulics](https://github.com/pptav0/SimuHydraulics.jl)).

## What's inside

- **Numeric helpers** (`helpers/`) — `round_to` for decimal rounding. Units of measure (`Diameter`, `Length`, `Density`, `Volume`, … with `to_*` conversions and named constants) come from the [UomDefinitions](../UomDefinitions) package; SimuUtils defines no unit conversions of its own.
- **Regression** (`helpers/regression.jl`) — linear and quadratic least-squares fits plus R² calculation (`calculate_r_squared`).
- **Geometry** (`geometry/capacity.jl`) — one unit-aware core, `annulus_capacity(od, id=0; unit, xs, out)`, covering rings and full circles (optional excess-area factor for hole washout); `circle_capacity` for the explicit `id = 0` case; oilfield wrappers `hole_capacity`, `pipe_capacity`, `pipe_displacement`; and volumes via `capacity_volume`, `annulus_volume`, `circle_volume`. Results are UomDefinitions `Capacity` / `Volume` quantities whose unit is chosen with `out=`; the cross-sectional area is the `m3_m` capacity read as m².
- **Oilfield types** (`oilfield/`) — `Casing` (OD/ID, weight, hanger/setting depth, thread, grade, burst/collapse ratings) and wellbore schematic drawing.
- **Plotting** (`plots/`) — `plot_regression` for experimental-vs-fitted data (linear or non-linear, with annotations and axis scaling) and `plot_well_schem` for well schematics, built on CairoMakie.

## Usage

```julia
using SimuUtils
using UomDefinitions: Diameter, Length, inch, mm, ft, m, l_m, m3_m, m3

# every physical input is a typed quantity; the unit travels with the value
hole, csg = Diameter(8.5, inch), Diameter(5.0, inch)

# annular capacity between an 8.5" hole and a 5" pipe (bbl/ft by default)
cap    = annulus_capacity(hole, csg)                        # 0.0459 bbl/ft
cap_xs = annulus_capacity(hole, csg; xs=0.2)                # with 20% excess
annulus_capacity(hole, Diameter(127.0, mm); out=l_m)        # mixed units in, L/m out
annulus_capacity(hole, csg; out=m3_m).value                 # cross-section area in m²

# full circle (id = 0): open hole / pipe bore, and the steel wall
hole_capacity(hole)                                         # 0.0702 bbl/ft
pipe_capacity(Diameter(4.892, inch))
pipe_displacement(Diameter(5.5, inch), Diameter(4.892, inch))

# volumes: any capacity × length
capacity_volume(cap, Length(5000.0, ft))                    # 229.48 bbl
annulus_volume(hole, csg, Length(1524.0, m); out=m3)

# fit and plot experimental data
slope, intercept = SimuUtils.linear_regression(X, Y)
r2 = calculate_r_squared(Y, Y_fit)
plot_regression(X, Y, X_fit, Y_fit, :linear; title="Fit", annotations=Dict("R²" => r2))
```

## Installation & development

Requires Julia ≥ 1.11. The package is not registered; use it via a local path or the repo URL:

```julia
using Pkg
Pkg.develop(path="path/to/SimuUtils")
```

Run tests from the package directory:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Build the docs locally:

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```
