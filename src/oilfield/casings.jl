# ----------------------------------------
#
# 	* Defined datatypes
#
# ----------------------------------------
#
# Typed-parameter contract (spec D2): every physical input is a UomDefinitions
# quantity — diameters `Diameter`, depths `Length`, ratings `Pressure`,
# material density `Density` (any unit; converted to lb/ft³ internally). The
# only `Real` parameters are `weight_ppf` (lb/ft, no UomDefinitions family yet)
# and `Thread.yield` (plain number).
# Validation (D4/D10): the single `new` site is the `Casing{T}` inner
# constructor; errors are UomDefinitions types except for structural
# problems (`hanger` below `depth`, empty thread name) which are `ArgumentError`.

@enum CsgWeight begin
    PPF  # lb/ft
end

"Carbon-steel density used for nominal casing weights (490 lb/ft³ ≈ 7849 kg/m³)."
const STEEL_DENSITY = Density(490.0, ppcf)

# Material density in lb/ft³; `Density` already rejects non-finite and negative values
function _ppcf(material::Density)
    ρ = to_ppcf(material).value
    iszero(ρ) && throw(ZeroValueError())
    return ρ
end

# Unit singleton of a Casing diameter (`Diameter{IN}` -> `inch`, …)
_unit(::Diameter{U}) where {U} = U()

# A foot length expressed as a Diameter in the unit of `u`
_as_diameter(l::Length, ::IN)  = to_in(l)
_as_diameter(l::Length, ::MM)  = to_mm(l)
_as_diameter(l::Length, ::D64) = to_d64(to_in(l))

# ----------------------------------------
#
# 	* Specific Helper functions
#
# ----------------------------------------

"""
    calc_casing_weight(od::Diameter, id::Diameter; material::Density=STEEL_DENSITY) -> Float64

Nominal weight of the casing wall in ppf (lb/ft), no rounding. The two
diameters may use different units. The steel area comes from the geometry
core ([`pipe_displacement`](@ref)).

# Arguments
- `od::Diameter`: Outer diameter of the casing.
- `id::Diameter`: Inner diameter of the casing.
- `material::Density=STEEL_DENSITY`: Density of the material, any unit (`ppcf`, `kg_m3`, `sg`, `ppg`).

# Throws
- `ZeroCapacityError` if `od == id`; `NegativeValueError` if `od < id` (from the geometry core).
- `ZeroValueError` for a zero `material` (non-finite / negative densities are rejected by `Density` itself).
"""
function calc_casing_weight(od::Diameter, id::Diameter; material::Density=STEEL_DENSITY)
    steel_ft2 = pipe_displacement(od, id; out=ft3_ft).value   # ft³/ft == ft²
    return steel_ft2 * _ppcf(material)                        # ft² × lb/ft³ = lb/ft
end

"""
    calc_casing_id(od::Diameter, weight_ppf::Real; material::Density=STEEL_DENSITY) -> Diameter

Inner diameter of a casing from its outer diameter and nominal weight, returned
in the unit of `od`, no rounding.

# Arguments
- `od::Diameter`: Outer diameter of the casing.
- `weight_ppf::Real`: Nominal weight in lb/ft.
- `material::Density=STEEL_DENSITY`: Density of the material, any unit.

# Throws
- `InvalidValueError` / `NegativeValueError` / `ZeroValueError` for a non-finite, negative or zero `weight_ppf`.
- `ZeroValueError` for a zero `material` (non-finite / negative densities are rejected by `Density` itself).
- `NegativeValueError` if the weight exceeds a solid bar of diameter `od` (no real bore).
- `ZeroCapacityError` if the weight equals a solid bar (bore would be zero).
"""
function calc_casing_id(od::Diameter, weight_ppf::Real; material::Density=STEEL_DENSITY)
    validate_positive_value(weight_ppf)
    ρ = _ppcf(material)

    od_ft = to_ft(od).value
    radicand = od_ft^2 - (4 / π) * (weight_ppf / ρ)
    # a solid bar gives a radicand of ~1e-16, not exactly zero: same 1e-9 relative rule as the diameter check
    isapprox(radicand, 0.0; atol=1e-9 * od_ft^2) && throw(ZeroCapacityError())
    radicand < 0 && throw(NegativeValueError())

    return _as_diameter(Length(sqrt(radicand), ft), _unit(od))
end

# ----------------------------------------
#
# 	* Casing Functions
#
# ----------------------------------------

"""
    Thread(name::AbstractString, yield::Real)

Casing connection: thread `name` and its `yield` strength (plain number, kips).

# Throws
- `ArgumentError` for an empty `name`.
- `InvalidValueError` / `NegativeValueError` / `ZeroValueError` for a non-finite, negative or zero `yield`.
"""
struct Thread
    name::String
    yield::Float64

    function Thread(name::AbstractString, yield::Real)
        isempty(name) && throw(ArgumentError("Thread name cannot be empty"))
        validate_positive_value(yield)
        new(String(name), Float64(yield))
    end
end

"""
    Casing{T}

Casing section. Diameters are stored as UomDefinitions `Diameter` quantities,
depths as `Length` quantities and burst/collapse ratings as `Pressure`
quantities, so the unit travels with the value (`csg.od.value`, `csg.depth.value`).

The inner constructor is the single validation point:
- `od > id` after converting both to inches (`ZeroCapacityError` if equal,
  `NegativeValueError` if smaller);
- `wt[1]` finite and positive (`InvalidValueError` / `NegativeValueError` / `ZeroValueError`);
- `hanger ≤ depth` when both are given, compared in metres (`ArgumentError`);
- `burst` / `collapse` non-negative when given (`NegativeValueError`).

An `id` of zero (solid bar) and `D64` diameters are accepted here; the
capacity functions raise `ZeroCapacityError` for a zero bore.
"""
mutable struct Casing{T<:Float64}
    od::Diameter
    id::Diameter
    wt::Tuple{T,CsgWeight}
    hanger::Union{Nothing,Length}
    depth::Union{Nothing,Length}
    thread::Union{Nothing,Thread}
    grade::Union{Nothing,String}
    burst::Union{Nothing,Pressure}
    collapse::Union{Nothing,Pressure}

    function Casing{T}(
        od::Diameter, id::Diameter, wt::Tuple{T,CsgWeight},
        hanger::Union{Nothing,Length}, depth::Union{Nothing,Length},
        thread::Union{Nothing,Thread}, grade::Union{Nothing,AbstractString},
        burst::Union{Nothing,Pressure}, collapse::Union{Nothing,Pressure}) where {T<:Float64}

        od_in, id_in = to_in(od).value, to_in(id).value
        isapprox(od_in, id_in; rtol=1e-9) && throw(ZeroCapacityError())   # conversion is not bit-exact
        od_in < id_in && throw(NegativeValueError())

        validate_positive_value(wt[1])

        if !isnothing(hanger) && !isnothing(depth)
            h, d = to_m(hanger).value, to_m(depth).value
            h > d && !isapprox(h, d; rtol=1e-9) &&
                throw(ArgumentError("Hanger cannot be deeper than Casing depth"))
        end

        !isnothing(burst)    && burst.value    < 0 && throw(NegativeValueError())
        !isnothing(collapse) && collapse.value < 0 && throw(NegativeValueError())

        new{T}(od, id, wt, hanger, depth, thread,
               isnothing(grade) ? nothing : String(grade), burst, collapse)
    end
end

"""
    Casing(od::Diameter, id::Diameter;
        hanger::Union{Nothing,Length}=nothing, depth::Union{Nothing,Length}=nothing,
        thread::Union{Nothing,Thread}=nothing, grade::Union{Nothing,AbstractString}=nothing,
        burst::Union{Nothing,Pressure}=nothing, collapse::Union{Nothing,Pressure}=nothing)

Ergonomic constructor: computes the nominal weight `wt` in ppf from `od` and `id`
([`calc_casing_weight`](@ref)) and delegates every check to the inner constructor.
`od` and `id` may use different diameter units; `hanger` and `depth` different length units.

# Arguments
- `od::Diameter`, `id::Diameter`: Outer and inner diameters.
- `hanger`, `depth`: Hanger and setting depths as `Length`.
- `thread`, `grade`: Connection and steel grade.
- `burst`, `collapse`: Pressure ratings as `Pressure`.
"""
function Casing(
    od::Diameter, id::Diameter;
    hanger::Union{Nothing,Length}=nothing, depth::Union{Nothing,Length}=nothing,
    thread::Union{Nothing,Thread}=nothing, grade::Union{Nothing,AbstractString}=nothing,
    burst::Union{Nothing,Pressure}=nothing, collapse::Union{Nothing,Pressure}=nothing)

    wt = (calc_casing_weight(od, id), PPF::CsgWeight)
    return Casing{Float64}(od, id, wt, hanger, depth, thread, grade, burst, collapse)
end

"""
	calc_capacity(csg::Casing; out::CapacityUnit=bbl_ft)

The (3) capacities of a Casing as UomDefinitions `Capacity` quantities in
the unit `out` (`bbl_ft`, `gal_ft`, `m3_m`, `l_m`).

# Returns
- `external`: [`hole_capacity`](@ref) of the OD (full circle, no washout).
- `internal`: [`pipe_capacity`](@ref) of the ID.
- `displace`: [`pipe_displacement`](@ref) of the steel wall.
"""
function calc_capacity(csg::Casing; out::CapacityUnit=bbl_ft)
    external = hole_capacity(csg.od; out=out)
    internal = pipe_capacity(csg.id; out=out)
    displace = pipe_displacement(csg.od, csg.id; out=out)

    return (external=external, internal=internal, displace=displace)
end

"""
	calc_capacity(outer::Casing, inner::Casing; out::CapacityUnit=bbl_ft)

The (3) capacities of a casing-in-casing pair as UomDefinitions `Capacity`
quantities in the unit `out`. The two casings may use different diameter units.

# Returns
- `annular`: [`annulus_capacity`](@ref) between `outer` ID and `inner` OD.
- `internal`: [`pipe_capacity`](@ref) of the inner ID.
- `displace`: [`pipe_displacement`](@ref) of the inner steel wall.
"""
function calc_capacity(outer::Casing, inner::Casing; out::CapacityUnit=bbl_ft)
    annular  = annulus_capacity(outer.id, inner.od; out=out)        # units may differ
    internal = pipe_capacity(inner.id; out=out)
    displace = pipe_displacement(inner.od, inner.id; out=out)

    return (annular=annular, internal=internal, displace=displace)
end
