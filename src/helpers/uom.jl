# Unit of measure definitions
abstract type Unit end

@enum VolumeUnit begin
    BBL  # Barrels
    M3   # Cubic meters
    FT3  # Cubic feet
    GAL  # Gallons
end

@enum LengthUnit begin
    M    # Meters
    FT   # Feet
    IN   # Inches
end

@enum RateUnit begin
    BPM  # Barrels per minute
    M3MIN  # Cubic meters per minute
    LPM  # Liters per minute
end

@enum VelocityUnit begin
    FT_S  # Feet per second
    FT_MIN  # Feet per minute
    M_S  # Meters per second
    M_MIN  # Meters per minute
end

@enum MassUnit begin
    KG  # Kilograms
    LB  # Pounds
end


# UOM definition
#
# The UOM struct is used to define the unit of measure for a given quantity.
# It is a parametric type that takes two type parameters: T and U. T is the
struct Uom{T, U}
    value::T
    unit::U
end

# Conversion factors
"""
	UOM_CONVERSIONS

A dictionary of conversion factors between different units of measure.
"""
const UOM_CONVERSIONS = Dict(
	# volume
    (BBL, M3) => 0.159,
    (BBL, FT3) => 0.159 / 0.3048^3,
    (BBL, GAL) => 42.0,
    (M3, BBL) => 1 / 0.159,
    (M3, FT3) => 1 / 0.3048^3,
    (M3, GAL) => 1_000 / 3.785,
    (FT3, BBL) => 0.3048^3 / 0.159,
    (FT3, M3) => 0.3048^3,
    (FT3, GAL) =>  0.3048^3 * 1_000 / 3.785,
    (GAL, BBL) => 1 / 42.0,
    (GAL, M3) => 3.785 / 1_000,
    (GAL, FT3) => 3.785 / (1_000 * 0.3048^3),
    # length
    (M, FT) => 1 / 0.3048,
    (M, IN) => 1 / 0.0254,
    (FT, M) => 0.3048,
    (FT, IN) => 12.0,
    (IN, M) => 0.0254,
    (IN, FT) => 1 / 12.0,
    # rate
    (BPM, M3MIN) => 0.159,
    (M3MIN, BPM) => 1 / 0.159,
    (BPM, LPM) => 42.0 / 3.785,
    (LPM, BPM) => 3.785 / 42.0,
    # mass
    (KG, LB) => 1 / 0.454,
    (LB, KG) => 0.454,
    # velocity
    (FT_S, FT_MIN) => 60.0,
    (FT_S, M_S) => 0.3048,
    (FT_S, M_MIN) => 0.3048 * 60.0,
    (FT_MIN, FT_S) => 1 / 60.0,
)

# Catch-all method to handle invalid conversions
"""
	convert(value::T, from_unit::U, to_unit::U) where {T<:Number, U<:Unit}

Convert a value from one unit of measure to another.

# Arguments
- `value::T`: The value to convert.
- `from_unit::U`: The unit of measure to convert from.
- `to_unit::U`: The unit of measure to convert to.

# Returns
- `T`: The converted value.
"""
function convert(value::T, from_unit, to_unit) where {T<:Number}
    throw(ArgumentError("""
		Conversion from $from_unit to $to_unit is not defined or
	    units are not compatible.
    """))
end

# Conversion functions
"""
	convert(value::T, from_unit::U, to_unit::U) where {T<:Number, U}

Convert a value from one unit of measure to another.

# Arguments
- `value::T`: The value to convert.
- `from_unit::U`: The unit of measure to convert from.
- `to_unit::U`: The unit of measure to convert to.

# Returns
- `T`: The converted value.
"""
function convert(value::T, from_unit::U, to_unit::U) where {T<:Number, U}
    if from_unit == to_unit
        return value
    end
    factor = get(UOM_CONVERSIONS, (from_unit, to_unit), nothing)
    if factor === nothing
        throw(ArgumentError("""
         	Conversion from $from_unit to $to_unit is not defined or
          	units are not compatible.
        """))
    end
    return value * factor
end

"""
	convert(uom::Uom{T, U}, to_unit::U) where {T, U}

Convert a Uom struct from one unit of measure to another.

# Arguments
- `uom::Uom{T, U}`: The Uom struct to convert.
- `to_unit::U`: The unit of measure to convert to.

# Returns
- `Uom{T, U}`: The converted Uom struct.
"""
function convert(uom::Uom{T, U}, to_unit::U) where {T, U}
    new_value = convert(uom.value, uom.unit, to_unit)
    return Uom{T, U}(new_value, to_unit)
end

# Arithmetic operations
import Base: +, -, *, /

function +(uom1::Uom{T, U}, uom2::Uom{T, U}) where {T, U}
	uom2_converted = convert(uom2, uom1.unit)
	return Uom{T, U}(uom1.value + uom2_converted.value, uom1.unit)
end

function -(uom1::Uom{T, U}, uom2::Uom{T, U}) where {T, U}
	uom2_converted = convert(uom2, uom1.unit)
	return Uom{T, U}(uom1.value - uom2_converted.value, uom1.unit)
end

function *(uom::Uom{T, U}, scalar::T) where {T, U}
	return Uom{T, U}(uom.value * scalar, uom.unit)
end

function /(uom::Uom{T, U}, scalar::T) where {T, U}
	return Uom{T, U}(uom.value / scalar, uom.unit)
end
