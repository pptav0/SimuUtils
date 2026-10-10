# ----------------------------------------
#
# 	* Defined datatypes
#
# ----------------------------------------

@enum CsgWeight begin
    PPF  # lb/ft
end

const STEEL_DENSITY = 490.0 # lb/ft^3


# ----------------------------------------
#
# 	* Specific Helper functions
#
# ----------------------------------------
#
# Diameter <-> feet conversions come from UomDefinitions (`to_ft(::Diameter)`,
# `to_in(::Length)`, `to_mm(::Length)`), so the 12 in/ft and 304.8 mm/ft
# factors live in one place (`IN_PER_FT`, `MM_PER_FT`).

# Function to convert diameter to feet
to_feet(diameter::T, unit::DiameterUnit) where {T<:Union{Float64,Float32}} =
    to_ft(Diameter(diameter, unit)).value

# Function to convert diameter from feet to the original unit
from_feet(diameter_ft::T, ::IN) where {T<:Union{Float64,Float32}} = to_in(Length(diameter_ft, ft)).value
from_feet(diameter_ft::T, ::MM) where {T<:Union{Float64,Float32}} = to_mm(Length(diameter_ft, ft)).value

"""
	calculate_casing_weight(
		od::T, id::T, unit::DiameterUnit;
		material::T=STEEL_DENSITY) where T<:Union{Float64, Float32}

Function to calculate the weight of the casing in ppf (lb/ft)

# Arguments
   - `od::T`: Outer diameter of the casing [in or mm].
   - `id::T`: Inner diameter of the casing [in or mm].
   - `unit::DiameterUnit`: The unit of the diameters (`inch` or `mm`).
   - `material::T=STEEL_DENSITY`: The density of the material in lb/ft^3. Defaults to STEEL_DENSITY.

# Returns
   - `weight_ppf::T`: The weight of the casing in lb/ft.
"""
function calc_casing_weight(
    od::T, id::T, unit::DiameterUnit;
    material::T=STEEL_DENSITY) where {T<:Union{Float64,Float32}}

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
   - `unit::DiameterUnit`: The unit of measurement for the diameters (`inch` or `mm`).
   - `material::T=STEEL_DENSITY`: The density of the material in lb/ft^3. Defaults to STEEL_DENSITY.

# Returns
   - `id::T`: The inner diameter of the casing [in or mm].
"""
function calc_casing_id(
    od::T, weight_ppf::T, unit::DiameterUnit;
    material::T=STEEL_DENSITY) where {T<:Union{Float64,Float32}}

    # Convert od to feet
    od_ft = to_feet(od, unit)

    # Calculate id in feet
    id_ft = sqrt(od_ft^2 - ((4 / π) * (weight_ppf / material)))

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

"""
    Casing{T}

Casing section. Diameters are stored as UomDefinitions `Diameter` quantities
and depths as `Length` quantities, so the unit travels with the value
(`csg.od.value`, `csg.depth.value`).
"""
mutable struct Casing{T<:Union{Float64}}
    od::Diameter
    id::Diameter
    wt::Tuple{T,CsgWeight}
    hanger::Union{Nothing,Length}
    depth::Union{Nothing,Length}
    thread::Union{Nothing,Thread}
    grade::Union{Nothing,String}
    burst::Union{Nothing,T}
    collapse::Union{Nothing,T}
end

# Accept either a typed `Length` or the legacy `(value, unit)` tuple for depths.
_as_length(x::Nothing) = nothing
_as_length(x::Length)  = x
_as_length(x::Tuple{<:Real,<:LengthUnit}) = Length(x[1], x[2])


"""
    Casing(
		od::T, id::T, units::DiameterUnit;
		hanger::Union{Nothing, Length, Tuple{Real, LengthUnit}}=nothing,
		depth::Union{Nothing, Length, Tuple{Real, LengthUnit}}=nothing)
		where T<:Union{Float64, Float32}

Constructor given `od` and `id` inputs. `depth` and other `Casing` properties are optional.

# Arguments
- `od::T`: The outer diameter of the casing [in or mm].
- `id::T`: The inner diameter of the casing [in or mm].
- `units::DiameterUnit`: The unit of measurement for the diameter inputs (`inch` or `mm`).
- `hanger`: The hanger depth of the casing, as `Length(x, ft|m)` or `(x, ft|m)`.
- `depth`: The depth of the casing [ft or m], as `Length(x, ft|m)` or `(x, ft|m)`.

# Result
- `Casing{T}`: The constructed `Casing` object.
"""
function Casing(
    od::T, id::T, units::DiameterUnit=inch;
    hanger=nothing, depth=nothing) where {T<:Union{Float64,Float32}}

    hanger = _as_length(hanger)
    depth  = _as_length(depth)

    # Assert Inputs diameters and depths
    if od <= id
        throw(ArgumentError("Outer diameter must be larger than inner diameter"))
    end
    if !isnothing(hanger) && !isnothing(depth) && hanger.value > depth.value
        throw(ArgumentError("Hanger cannot be deeper than Casing depth"))
    end

    # Calculate the wall thickness of the casing
    wt = calc_casing_weight(od, id, units)

    Casing{Float64}(
        Diameter(od, units), Diameter(id, units), (Float64(wt), PPF::CsgWeight),
        hanger, depth,
        nothing, nothing, nothing, nothing,
    )
end

# Unit singleton of a Casing diameter (`Diameter{IN}` -> `inch`, …)
_unit(::Diameter{U}) where {U} = U()

# Legacy area helper: cross-sectional area expressed in the diameter's own
# unit squared (in² for inch casings, mm² for mm casings), so that the
# user-supplied factor `f` of the legacy `calc_capacity(…, f)` keeps its
# meaning. Computed through the single annulus core (`annulus_capacity`).
function _area_in_unit2(od::Diameter, id::Real=0.0)
    unit   = _unit(od)
    area_m2 = annulus_capacity(od.value, id; unit=unit, out=m3_m).value
    return area_m2 / to_m(Diameter(1.0, unit)).value^2
end

"""
	calc_capacity(csg::Casing{T}, f::T) ::Tuple{T, T, T}
		where T<:Union{Float64, Float32}

Calculate the (3) capacties given a Casing object. Each capacity will
be multiply by `f` conversion factor.

Legacy form: areas are in the casing diameter unit squared (in² or mm²)
and `f` is applied verbatim (`f` is required so this form never collides
with the typed form below). Prefer the keyword form
`calc_capacity(csg; out=bbl_ft)` which returns typed `Capacity` values.

# Arguments
- `csg::Casing{T}`: The Casing object for which to calculate the capacities.
- `f::T`: The conversion factor to multiply each capacity by (use `1.0` for raw areas).

# Returns
- `external::T`: The external capacity of the casing.
- `internal::T`: The internal capacity of the casing.
- `displace::T`: The wall capacity of the casing.
"""
function calc_capacity(csg::Casing{T}, f::T) where {T<:Union{Float64,Float32}}
    external = _area_in_unit2(csg.od) * f
    internal = _area_in_unit2(csg.id) * f
    displace = _area_in_unit2(csg.od, csg.id.value) * f

    return (external=external, internal=internal, displace=displace)
end

"""
	calc_capacity(csg::Casing; out::CapacityUnit=bbl_ft)

Typed form: the (3) capacities of a Casing as UomDefinitions `Capacity`
quantities in the unit `out` (`bbl_ft`, `gal_ft`, `m3_m`, `l_m`).

# Returns
- `external`: [`hole_capacity`](@ref) of the OD (full circle, no washout).
- `internal`: [`pipe_capacity`](@ref) of the ID.
- `displace`: [`pipe_displacement`](@ref) of the steel wall.
"""
function calc_capacity(csg::Casing; out::CapacityUnit=bbl_ft)
    unit = _unit(csg.od)
    external = hole_capacity(csg.od.value; unit=unit, out=out)
    internal = pipe_capacity(csg.id.value; unit=unit, out=out)
    displace = pipe_displacement(csg.od.value, csg.id.value; unit=unit, out=out)

    return (external=external, internal=internal, displace=displace)
end


"""
	calc_capacity(outer::Casing{T}, inner::Casing{T}, f::T)
		where {T<:Union{Float64,Float32}}

Calculate the (3) capacties given two Casing objects. Each capacity will
be multiply by `f` conversion factor.

Legacy form: areas are in the casing diameter unit squared (in² or mm²)
and `f` is applied verbatim (`f` is required so this form never collides
with the typed form below). Prefer the keyword form
`calc_capacity(outer, inner; out=bbl_ft)` which returns typed `Capacity` values.

# Arguments
- `outer::Casing{T}`: The outer Casing object.
- `inner::Casing{T}`: The inner Casing object.
- `f::T`: The conversion factor to multiply each capacity by (use `1.0` for raw areas).

# Returns
- `annular::T`: The annular capacity between the two casings.
- `internal::T`: The internal capacity of the inner casing.
- `displace::T`: The displacement capacity of the inner casing.
"""
function calc_capacity(
    outer::Casing{T}, inner::Casing{T},
    f::T) where {T<:Union{Float64,Float32}}

    annular = _area_in_unit2(outer.id, inner.od.value) * f
    internal = _area_in_unit2(inner.id) * f
    displace = _area_in_unit2(inner.od, inner.id.value) * f

    return (annular=annular, internal=internal, displace=displace)
end

"""
	calc_capacity(outer::Casing, inner::Casing; out::CapacityUnit=bbl_ft)

Typed form: the (3) capacities of a casing-in-casing pair as UomDefinitions
`Capacity` quantities in the unit `out`. Both casings must share a diameter unit.

# Returns
- `annular`: [`annulus_capacity`](@ref) between `outer` ID and `inner` OD.
- `internal`: [`pipe_capacity`](@ref) of the inner ID.
- `displace`: [`pipe_displacement`](@ref) of the inner steel wall.
"""
function calc_capacity(outer::Casing, inner::Casing; out::CapacityUnit=bbl_ft)
    unit = _unit(outer.id)
    _unit(inner.od) === unit || throw(ArgumentError("outer and inner casings must share a diameter unit"))
    annular  = annulus_capacity(outer.id.value, inner.od.value; unit=unit, out=out)
    internal = pipe_capacity(inner.id.value; unit=unit, out=out)
    displace = pipe_displacement(inner.od.value, inner.id.value; unit=unit, out=out)

    return (annular=annular, internal=internal, displace=displace)
end
