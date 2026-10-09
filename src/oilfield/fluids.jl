# Density units (`PPG`, `SG`, `KG_M3`) and the `Density` quantity come from
# UomDefinitions; `Fluid` stores a typed `Density` so the unit travels with
# the value and no enum-to-type bridge is needed downstream.

@enum FluidType begin
    Mud
    Spacer
    Cement
    Brine
end

mutable struct Fluid
    fluid::FluidType
    name::String
    density::Density
end

"""
    Fluid(fluid::FluidType, name::String, density::Real, unit::DensityUnit)

Convenience constructor taking a bare density value plus its unit singleton
(`ppg`, `sg` or `kg_m3`), e.g. `Fluid(Cement, "Slurry 2.0 sg", 2.0, sg)`.
"""
Fluid(fluid::FluidType, name::String, density::Real, unit::DensityUnit) =
    Fluid(fluid, name, Density(density, unit))
