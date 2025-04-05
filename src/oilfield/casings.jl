include("../helpers/uom.jl")

# ----------------------------------------
#
# 	* Defined datatypes
#
# ----------------------------------------

@enum CsgWeight begin
    PPF  	# lb/ft
end

const STEEL_DENSITY = 490.0 # lb/ft^3


# ----------------------------------------
#
# 	* Specific Helper functions
#
# ----------------------------------------

# Function to convert diameter to feet
function to_feet(diameter::T, unit::DiameterUnit) where T<:Union{Float64, Float32}
    if unit == IN::DiameterUnit
        return diameter / 12.0
    elseif unit == MM::DiameterUnit
        return diameter / 304.8
    else
        throw(ArgumentError("Unsupported diameter unit"))
    end
end

# Function to convert diameter from feet to the original unit
function from_feet(diameter_ft::T, unit::DiameterUnit) where T<:Union{Float64, Float32}
    if unit == IN::DiameterUnit
        return diameter_ft * 12.0
    elseif unit == MM::DiameterUnit
        return diameter_ft * 304.8
    else
        throw(ArgumentError("Unsupported diameter unit"))
    end
end

"""
	calculate_casing_weight(
		od::T, id::T, unit::DiameterUnit;
		material::T=STEEL_DENSITY) where T<:Union{Float64, Float32}

Function to calculate the weight of the casing in ppf (lb/ft)

# Arguments
   - `od::T`: Outer diameter of the casing [in or mm].
   - `id::T`: Inner diameter of the casing [in or mm].
   - `material::T=STEEL_DENSITY`: The density of the material in lb/ft^3. Defaults to STEEL_DENSITY.

# Returns
   - `weight_ppf::T`: The weight of the casing in lb/ft.
"""
function calc_casing_weight(
	od::T, id::T, unit::DiameterUnit;
	material::T=STEEL_DENSITY) where T<:Union{Float64, Float32}

    # Convert od and id to feet
    od_ft = to_feet(od, unit)
    id_ft = to_feet(id, unit)

    # Calculate the weight in lb/ft (ppf)
    weight_ppf = (π / 4) * (od_ft^2 - id_ft^2) * material

    return round(weight_ppf, digits=2)
end

"""
    calc_casing_id(
        od::T, weight_ppf::T, unit::DiameterUnit;
        material::T=STEEL_DENSITY) where T<:Union{Float64, Float32}

Function to calculate the inner diameter of the casing given the outer diameter and weight in ppf.

# Arguments
   - `od::T`: Outer diameter of the casing [in or mm].
   - `weight_ppf::T`: The weight of the casing in lb/ft.
   - `unit::DiameterUnit`: The unit of measurement for the diameters.
   - `material::T=STEEL_DENSITY`: The density of the material in lb/ft^3. Defaults to STEEL_DENSITY.

# Returns
   - `id::T`: The inner diameter of the casing [in or mm].
"""
function calc_casing_id(
    od::T, weight_ppf::T, unit::DiameterUnit;
    material::T=STEEL_DENSITY) where T<:Union{Float64, Float32}

    # Convert od to feet
    od_ft = to_feet(od, unit)

    # Calculate id in feet
    id_ft = sqrt( od_ft^2 - ((4 / π) * (weight_ppf/ material)) )

    # Convert id back to the original unit
    return round(from_feet(id_ft, unit), digits=3)
end

# ----------------------------------------
#
# 	* Casing Functions
#
# ----------------------------------------

struct Thread{T<:Float64}
	name::String
	yield::T
end

mutable struct Casing{T<:Float64}
	od::Tuple{T, DiameterUnit}
	id::Tuple{T, DiameterUnit}
	wt::Tuple{T, CsgWeight}
	depth::Union{Nothing, Tuple{T, LengthUnit}}
	thread::Union{Nothing, Thread}
	grade::Union{Nothing, String}
	burst::Union{Nothing, T}
	collapse::Union{Nothing, T}
end

"""
	Casing(
		od::T, id::T, units::DiameterUnit=IN::DiameterUnit;
		depth::Union{Nothing, Tuple{T, LengthUnit}}=nothing) where T<:Union{Float64, Float32}

Constructor given `od` and `id` inputs. `depth` and other `Casing` properties are optional.

# Arguments
- `od::T`: The outer diameter of the casing [in or mm].
- `id::T`: The inner diameter of the casing [in or mm].
- `units::DiameterUnit`: The unit of measurement for the diameter inputs.
- `depth::Union{Nothing, Tuple{T, LengthUnit}}`: The depth of the casing [ft or m].

# Result
- `Casing{T}`: The constructed `Casing` object.
"""
function Casing(
	od::T, id::T, units::DiameterUnit=IN::DiameterUnit;
	depth::Union{Nothing, Tuple{T, LengthUnit}}=nothing) where T<:Union{Float64, Float32}

	# Asser OD is larger than ID
	if od <= id
		thread("Outer diameter must be larger than inner diameter")
	end

	# Calculate the wall thickness of the casing
	wt = calc_casing_weight(od, id, units)

	Casing{T}(
		(od, units), (id, units), (wt, PPF::CsgWeight), depth,
		nothing, nothing, nothing, nothing,
	)
end
