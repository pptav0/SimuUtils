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
    CapacityUnit, Capacity, BBL_PER_FT, GAL_PER_FT, M3_PER_M, L_PER_M,
    bbl_ft, gal_ft, m3_m, l_m, to_bbl_ft, to_gal_ft, to_m3_m, to_l_m,
    to_unit

# Include all  functions
include("helpers/numeric.jl")
include("helpers/regression.jl")
# include all geometry functions
include("geometry/area.jl")
include("geometry/annulus.jl")

# include Oilfield module
# casings.jl must precede wellbore.jl: it defines `Casing`, which
# wellbore.jl uses in method signatures (exported: Casing, calc_capacity)
include("oilfield/casings.jl")
include("oilfield/wellbore.jl")
include("oilfield/fluids.jl")

# include plots functions
include("plots/regression.jl")

# export functions
export round_to, area_circle,
    Casing, calc_capacity, annular_capacity, annular_volume,
    plot_well_schem,
    plot_regression, calculate_r_squared,
    Fluid, FluidType, Mud, Spacer, Cement

end
