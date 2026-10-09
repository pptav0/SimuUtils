# Density units (`PPG`, `SG`, `KG_M3`) and the `Density` quantity come from
# UomDefinitions; `Fluid` stores a typed `Density` so the unit travels with
# the value. Rheology is a `RheoModel` (oilfield/rheos.jl); the `yp` / `pv`
# keyword constructor builds the legacy Bingham model.

"""
    FluidType

Kinds of wellbore fluids used in cementing jobs. `Mud` is kept as a generic
drilling fluid; `OBM` / `WBM` are oil- and water-based muds, `FreshWater` and
`SeaWater` are displacement / flush fluids.
"""
@enum FluidType begin
    Mud
    Spacer
    Cement
    Brine
    OBM
    WBM
    FreshWater
    SeaWater
end

"""
    Fluid(fluid::FluidType, name::String, density::Density, rheo::RheoModel)
    Fluid(fluid::FluidType, name::String, density::Real, unit::DensityUnit, rheo::RheoModel)
    Fluid(fluid, name, density[, unit]; yp=0.0, pv=1.0)     # Bingham(yp, pv)

Wellbore fluid with a typed `Density` and a rheology model. The keyword form
takes the classic yield point `yp` [lbf/100 ft²] and plastic viscosity `pv`
[cP] and stores `Bingham(yp, pv)`; defaults describe water.
"""
mutable struct Fluid
    fluid::FluidType
    name::String
    density::Density
    rheo::RheoModel
end

Fluid(fluid::FluidType, name::String, density::Real, unit::DensityUnit, rheo::RheoModel) =
    Fluid(fluid, name, Density(density, unit), rheo)
Fluid(fluid::FluidType, name::String, density::Density; yp::Real=0.0, pv::Real=1.0) =
    Fluid(fluid, name, density, Bingham(yp, pv))
Fluid(fluid::FluidType, name::String, density::Real, unit::DensityUnit; yp::Real=0.0, pv::Real=1.0) =
    Fluid(fluid, name, Density(density, unit), Bingham(yp, pv))

"Yield point [lbf/100 ft²] of the fluid's Bingham equivalent."
yp(f::Fluid) = bingham_equivalent(f.rheo).τ0
"Plastic viscosity [cP] of the fluid's Bingham equivalent."
pv(f::Fluid) = bingham_equivalent(f.rheo).μp
