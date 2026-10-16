# Plotting layer — stubs only. The bodies live in ext/SimuUtilsMakieExt.jl and
# are attached when CairoMakie **and** MakieThemes are loaded (spec D5), so the
# core package never depends on a plotting backend. Until then these functions
# have no methods and calling one raises MethodError.

"""
    plot_well_schem(outer_geometry::Vector{Casing}, inner_geometry::Vector{Casing};
                    airgap=nothing, water_depth=nothing, units::LengthUnit=m)

2-D wellbore schematic. Provided by the `SimuUtilsMakieExt` extension:
`using CairoMakie, MakieThemes` to enable it.
"""
function plot_well_schem end

"""
    plot_regression(X_exp, Y_exp, X_fit, Y_fit, regression_type::Symbol; kwargs...)

Experimental points with a linear or quadratic fit. Provided by the
`SimuUtilsMakieExt` extension: `using CairoMakie, MakieThemes` to enable it.
"""
function plot_regression end

"""
    plot_rheology(readings::FannReadings, regression_type::Symbol; kwargs...)

Fann-35 rheogram with the fitted model. Provided by the `SimuUtilsMakieExt`
extension: `using CairoMakie, MakieThemes` to enable it.
"""
function plot_rheology end
