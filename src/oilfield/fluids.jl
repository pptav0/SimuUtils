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
    Fluid(fluid::FluidType, name::AbstractString, density::Density, rheo::RheoModel)
    Fluid(fluid::FluidType, name::AbstractString, density::Real, unit::DensityUnit, rheo::RheoModel)
    Fluid(fluid, name, density[, unit]; yp=0.0, pv=1.0)     # Bingham(yp, pv)

Wellbore fluid with a typed `Density` and a rheology model. The keyword form
takes the classic yield point `yp` [lbf/100 ft²] and plastic viscosity `pv`
[cP] and stores `Bingham(yp, pv)`; defaults describe water. The `Real` forms
build `Density(density, unit)`, so the density is validated by UomDefinitions
(`InvalidValueError` for non-finite, `NegativeValueError` for negative values).

Throws `ArgumentError` for an empty `name`. The inner constructor is the single
`new` site; the invariants hold at construction only — assigning to the fields
of this mutable struct bypasses the checks.
"""
mutable struct Fluid
    fluid::FluidType
    name::String
    density::Density
    rheo::RheoModel

    function Fluid(fluid::FluidType, name::AbstractString, density::Density, rheo::RheoModel)
        isempty(name) && throw(ArgumentError("Fluid name cannot be empty"))
        new(fluid, String(name), density, rheo)
    end
end

Fluid(fluid::FluidType, name::AbstractString, density::Real, unit::DensityUnit, rheo::RheoModel) =
    Fluid(fluid, name, Density(density, unit), rheo)
Fluid(fluid::FluidType, name::AbstractString, density::Density; yp::Real=0.0, pv::Real=1.0) =
    Fluid(fluid, name, density, Bingham(yp, pv))
Fluid(fluid::FluidType, name::AbstractString, density::Real, unit::DensityUnit; yp::Real=0.0, pv::Real=1.0) =
    Fluid(fluid, name, Density(density, unit), Bingham(yp, pv))

"Yield point [lbf/100 ft²] of the fluid's Bingham equivalent."
yp(f::Fluid) = bingham_equivalent(f.rheo).τ0
"Plastic viscosity [cP] of the fluid's Bingham equivalent."
pv(f::Fluid) = bingham_equivalent(f.rheo).μp
