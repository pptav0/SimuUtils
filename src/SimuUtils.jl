module SimuUtils

using Printf
using LaTeXStrings
# Units of measure: all unit types, singletons, constants and `to_*`
# conversions come from UomDefinitions (no local unit definitions).
# The names used here are imported explicitly because Makie (loaded in
# wellbore.jl) also exports `Density` and `Volume`; an explicit import
# takes precedence over the conflicting `using` exports.
using UomDefinitions
import UomDefinitions:
    DiameterUnit, Diameter, IN, MM, D64, inch, mm, d64, to_in, to_mm,
    LengthUnit, Length, FT, M, ft, m, to_ft, to_m,
    DensityUnit, Density, PPG, SG, KG_M3, ppg, sg, kg_m3,
    VolumeUnit, Volume, M3, BBL, L, m3, bbl, ltr, to_m3, to_bbl, to_ltr,
    CapacityUnit, Capacity, BBL_PER_FT, GAL_PER_FT, FT3_PER_FT, M3_PER_M, L_PER_M,
    bbl_ft, gal_ft, ft3_ft, m3_m, l_m, to_bbl_ft, to_gal_ft, to_ft3_ft, to_m3_m, to_l_m,
    to_unit

# Include all  functions
include("helpers/numeric.jl")
include("helpers/regression.jl")
# include all geometry functions
# capacity.jl: annulus/circle capacities and volumes (single unit-aware core)
include("geometry/capacity.jl")

# include Oilfield module
# casings.jl must precede wellbore.jl: it defines `Casing`, which
# wellbore.jl uses in method signatures (exported: Casing, calc_capacity)
include("oilfield/casings.jl")
include("oilfield/wellbore.jl")
# rheos.jl must precede fluids.jl: `Fluid` holds a `RheoModel`
include("oilfield/rheos.jl")
include("oilfield/fluids.jl")

# include plots functions
include("plots/regression.jl")
include("plots/rheology.jl")

# export functions
export round_to,
    Casing, calc_capacity,
    circle_capacity, annulus_capacity, hole_capacity, pipe_capacity, pipe_displacement,
    capacity_volume, annulus_volume, circle_volume,
    plot_well_schem,
    plot_regression, calculate_r_squared,
    Fluid, FluidType, Mud, Spacer, Cement, Brine, OBM, WBM, FreshWater, SeaWater, yp, pv,
    RheoModel, Newtonian, PowerLaw, Bingham, HerschelBulkley, GeneralizedHB,
    shear_stress, apparent_viscosity, yield_stress, bingham_equivalent, fit_rheology, CP_PER_LBF100FT2_S,
    Rotor, Bob, Spring, FannReadings, FannRheology, FannInputs,
    calc_shear_rate, calc_shear_stress, calc_spring_constant, ghb_model, ghb_model_fit, convert_muinf,
    plot_rheology

end
