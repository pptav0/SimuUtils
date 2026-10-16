module SimuUtils

using Printf
using LaTeXStrings
# Units of measure: all unit types, singletons, constants and `to_*`
# conversions come from UomDefinitions (no local unit definitions).
# The names used here are listed explicitly as documentation of the units
# contract; plotting backends no longer load here (see plots/plots.jl), so
# there is no name clash to resolve.
using UomDefinitions
import UomDefinitions:
    DiameterUnit, Diameter, IN, MM, D64, inch, mm, d64, to_in, to_mm,
    LengthUnit, Length, FT, M, ft, m, to_ft, to_m,
    DensityUnit, Density, PPG, SG, KG_M3, PPCF, ppg, sg, kg_m3, ppcf, to_ppcf,
    VolumeUnit, Volume, M3, BBL, L, m3, bbl, ltr, to_m3, to_bbl, to_ltr,
    CapacityUnit, Capacity, BBL_PER_FT, GAL_PER_FT, FT3_PER_FT, M3_PER_M, L_PER_M,
    bbl_ft, gal_ft, ft3_ft, m3_m, l_m, to_bbl_ft, to_gal_ft, to_ft3_ft, to_m3_m, to_l_m,
    to_unit, validate_value

# Layers, each with its own index file (dependency direction: left to right only,
# enforced by test/test_structure.jl):
#   helpers → geometry → oilfield → plots
include("helpers/helpers.jl")
include("geometry/geometry.jl")
include("oilfield/oilfield.jl")
include("plots/plots.jl")

# ---- exports, grouped by layer ------------------------------------------------
# helpers
export round_to, linear_regression, non_linear_regression, calculate_r_squared
# geometry
export annulus_capacity, hole_capacity, pipe_capacity, pipe_displacement,
    circle_capacity, circle_volume, capacity_volume, annulus_volume
# oilfield
export Casing, CsgWeightUnit, PPF, ppf, CsgWeight, Thread, STEEL_DENSITY,
    calc_casing_weight, calc_casing_id, calc_capacity,
    Fluid, FluidType, Mud, Spacer, Cement, Brine, OBM, WBM, FreshWater, SeaWater, yp, pv,
    RheoModel, Newtonian, PowerLaw, Bingham, HerschelBulkley, GeneralizedHB,
    shear_stress, apparent_viscosity, yield_stress, bingham_equivalent, fit_rheology, CP_PER_LBF100FT2_S,
    Rotor, Bob, Spring, FannReadings, FannRheology, FannInputs,
    calc_shear_rate, calc_shear_stress, calc_spring_constant, ghb_model, ghb_model_fit, convert_muinf
# plots
export plot_well_schem, plot_regression, plot_rheology

end
