# ================================================================================
# Annular Capacity Calculations
# ================================================================================
"""
    annular_capacity(od::T, id::T;
                     unit::DiameterUnit = inch,
                     xs::T = 0.0,
                     out::CapacityUnit = bbl_ft) where {T <: Real} -> Capacity

Calculate the annular capacity between two concentric cylindrical boundaries.

This function generalizes annular volume/area calculations for:
- Open Hole (OH) to casing ID scenarios
- Casing-to-casing annular spaces
- Any concentric cylinder pair (outer boundary -> inner boundary)

The annular area is computed as `π/4 * (od² - id²)` with optional washout excess.

# Arguments
- `od::T`: Outer diameter of the annulus (e.g., open hole diameter or outer casing OD) [in/mm]
- `id::T`: Inner diameter of the annulus (e.g., inner casing ID) [in/mm]
- `unit::DiameterUnit = inch`: Unit of input diameters (`inch` or `mm` singletons from UomDefinitions)
- `xs::T = 0.0`: Washout/excess area factor as percentage (0.0–1.0).
    Accounts for hole enlargement beyond nominal diameter.
- `out::CapacityUnit = bbl_ft`: Output unit singleton from UomDefinitions:
    `bbl_ft`, `gal_ft`, `m3_m` or `l_m`.

# Returns
A UomDefinitions `Capacity{U}` tagged with the requested unit, e.g.
`Capacity{BBL_PER_FT}`. The bare number is `.value`; convert later with
`to_l_m`, `to_gal_ft`, … or `to_unit(cap, unit)`. The cross-sectional area
is numerically the `m3_m` capacity in m² (`to_m3_m(cap).value`).

# Throws
- `ArgumentError`: If `od ≤ id` (invalid geometry)
- `ArgumentError`: If `xs ∉ [0.0, 1.0]` (invalid washout factor)
- `MethodError`: If `unit` or `out` is not a supported singleton

# Examples
```julia
# 8.5\" OH with 5.0\" casing ID, no washout
annular_capacity(8.5, 5.0; unit=inch)                  # 0.0459 bbl/ft

# 12.25\" OH with 9.625\" casing ID, 10% washout
annular_capacity(12.25, 9.625; unit=inch, xs=0.10)

# Millimeter inputs, metric output
annular_capacity(215.9, 127.0; unit=mm, out=l_m)       # 23.94 L/m

# Cross-sectional area in m² (m³/m is numerically m²)
annular_capacity(8.5, 5.0; out=m3_m).value
```

# Notes
- The output unit is chosen with `out`; field (bbl/ft, gal/ft) and metric (m³/m, L/m) are all supported
- The washout factor `xs` multiplies the area by `(1 + xs)` to simulate hole enlargement
- For a solid pipe (id=0), this reduces to the standard cylinder cross-section
- Conversion factors come from UomDefinitions (`M_PER_FT`, `M3_M_PER_BBL_FT`, `GAL_PER_BBL`, `L_PER_M3`)

# See Also
[`area_circle`](@ref), [`calc_capacity`](@ref)
"""
function annular_capacity(
    od::T, id::T;
    unit::DiameterUnit = inch,
    xs::T = 0.0,
    out::CapacityUnit = bbl_ft
) where {T <: Real}

    # Validate inputs
    # -----------------
    if od <= id
        throw(ArgumentError(
            "Outer diameter ($od) must exceed inner diameter ($id). " *
            "Invalid annular geometry."
        ))
    end

    if !(0.0 <= xs <= 1.0)
        throw(ArgumentError(
            "Washout factor xs must be in [0.0, 1.0], got $xs."
        ))
    end

    # Convert diameters to meters for internal calculations
    # UomDefinitions owns the factors (IN_PER_FT = 12, MM_PER_FT = 304.8, M_PER_FT)
    od_m = to_m(Diameter(od, unit)).value
    id_m = to_m(Diameter(id, unit)).value

    # Cross-sectional annular area [m²]
    # Formula: π/4 * (OD² - ID²) * (1 + washout)
    area_m2 = (π / 4) * (od_m^2 - id_m^2) * (1 + xs)

    # Capacity per meter [m³/m] — numerically equals area in m²
    # but semantically represents volume per unit length. Tag it as a
    # UomDefinitions `Capacity` and let `to_unit` produce the requested
    # output (bbl/ft, gal/ft, m³/m or L/m) from the shared factors.
    return to_unit(Capacity(area_m2, m3_m), out)
end

# ================================================================================
# Helper Functions (Private)
# ================================================================================
# Diameter-to-meter and length-to-meter conversions are provided by
# UomDefinitions (`to_m(::Diameter)`, `to_m(::Length)`), and the output
# unit selection by `to_unit`; an unsupported unit surfaces as a
# MethodError instead of a hand-written ArgumentError.

# ================================================================================
# Public API Extensions
# ================================================================================

"""
    annular_volume(od::T, id::T, length_val::T;
                   unit::DiameterUnit = inch,
                   length_unit::LengthUnit = ft,
                   xs::T = 0.0,
                   out::VolumeUnit = bbl) where {T <: Real} -> Volume

Calculate total annular volume for a given axial length.

Wraps `annular_capacity` to compute full volumes rather than per-length rates.

# Arguments
- `od::T`: Outer diameter [in/mm]
- `id::T`: Inner diameter [in/mm]
- `length_val::T`: Axial length of the annulus
- `unit::DiameterUnit`: Unit for diameters (default: inches)
- `length_unit::LengthUnit`: Unit for length (default: feet)
- `xs::T = 0.0`: Washout factor
- `out::VolumeUnit = bbl`: Output unit singleton: `bbl`, `m3` or `ltr`

# Returns
A UomDefinitions `Volume{U}` tagged with the requested unit (rounded to
4 digits by the `Volume` constructor). Convert later with `to_bbl`,
`to_m3`, `to_ltr` or `to_unit(vol, unit)`.

# Examples
```julia
# 5000 ft of 8.5\"x5.0\" annulus
annular_volume(8.5, 5.0, 5000.0; unit=inch, length_unit=ft)           # 229.48 bbl
annular_volume(8.5, 5.0, 1524.0; unit=inch, length_unit=m, out=m3)    # 36.49 m³
```

# See Also
[`annular_capacity`](@ref)
"""
function annular_volume(
    od::T, id::T, length_val::T;
    unit::DiameterUnit = inch,
    length_unit::LengthUnit = ft,
    xs::T = 0.0,
    out::VolumeUnit = bbl
) where {T <: Real}

    # Get per-meter capacity [m³/m]
    cap = annular_capacity(od, id; unit=unit, xs=xs, out=m3_m)

    # Convert length to meters for calculation
    length_m = to_m(Length(length_val, length_unit)).value

    # Total volume [m³] by scaling the per-meter capacity, then tag it as a
    # UomDefinitions `Volume` and convert to the requested output unit
    total_m3 = cap.value * length_m

    return to_unit(Volume(total_m3, m3; digits=10), out)
end
