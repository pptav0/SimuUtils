# SimuUtils

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://pptav0.github.io/SimuUtils.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://pptav0.github.io/SimuUtils.jl/dev/)
[![Build Status](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/pptav0/SimuUtils.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/pptav0/SimuUtils.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/pptav0/SimuUtils.jl)

Shared utilities for the Simulytics hydraulics-simulation platform: numeric helpers, regression fitting, wellbore geometry, and Makie-based plotting. SimuUtils is the common dependency of the simulation packages (notably [SimuHydraulics](https://github.com/pptav0/SimuHydraulics.jl)).

## What's inside

- **Numeric helpers** (`helpers/`) — `round_to` for decimal rounding; enum-based unit-of-measure definitions (`VolumeUnit`, `DiameterUnit`, `LengthUnit`, `RateUnit`, `DensityUnit`, …) with a `convert` helper for engineering unit conversions.
- **Regression** (`helpers/regression.jl`) — linear and quadratic least-squares fits plus R² calculation (`calculate_r_squared`).
- **Geometry** (`geometry/area.jl`) — `area_circle` for circle and annular (ring) cross-sections, with optional excess-area factor for hole washout.
- **Oilfield types** (`oilfield/`) — `Casing` (OD/ID, weight, hanger/setting depth, thread, grade, burst/collapse ratings) and wellbore schematic drawing.
- **Plotting** (`plots/`) — `plot_regression` for experimental-vs-fitted data (linear or non-linear, with annotations and axis scaling) and `plot_well_schem` for well schematics, built on CairoMakie.

## Usage

```julia
using SimuUtils

# annular cross-section area between hole and pipe
a = area_circle(8.5, 5.0)          # ring area
a_xs = area_circle(8.5, 5.0; xs=0.2)  # with 20% excess

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
