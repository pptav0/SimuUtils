@enum DensityUnit begin
    PPG  # Pounds per gallon
    SG # Specific gravity
    KG_M3 # Kilograms per cubic meter
end

@enum FluidType begin
    Mud
    Spacer
    Cement
    Brine
end

mutable struct Fluid{T<:Union{Float32,Float64}}
    fluid::FluidType
    name::String
    density::T
    units::DensityUnit
end
