# ================================================================================
# Annular Capacity Calculations
# ================================================================================
"""
    annular_capacity(od::T, id::T;
                     unit::DiameterUnit = inch,
                     xs::T = 0.0,
                     per_length::Bool = true) where {T <: Real}

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
- `per_length::Bool = true`: If true, returns capacity **per foot** of depth [e.g., bbl/ft].
    If false, returns cross-sectional area only [e.g., ft²].

# Returns
Named tuple with capacities in multiple units:
```julia
(
    ft2::T,           # Cross-sectional annular area [ft²]
    bbl_ft::T,        # Capacity per foot [bbl/ft] (when per_length=true)
    gal_ft::T,        # Capacity per foot [gal/ft] (when per_length=true)
    ft3_ft::T         # Capacity per foot [ft³/ft] (when per_length=true)
)
```

# Throws
- `ArgumentError`: If `od ≤ id` (invalid geometry)
- `ArgumentError`: If `xs ∉ [0.0, 1.0]` (invalid washout factor)
- `ArgumentError`: If `unit` is unsupported

# Examples
```julia
# 8.5\" OH with 5.0\" casing ID, no washout
annular_capacity(8.5, 5.0; unit=inch)

# 12.25\" OH with 9.625\" casing ID, 10% washout
annular_capacity(12.25, 9.625; unit=inch, xs=0.10)

# Millimeter inputs
annular_capacity(215.9, 127.0; unit=mm)

# Cross-sectional area only (no length normalization)
annular_capacity(8.5, 5.0; per_length=false)  # returns ft² only
```

# Notes
- All outputs are in **field units** (bbl/ft, gal/ft, ft²) for oil & gas workflows
- The washout factor `xs` multiplies the area by `(1 + xs)` to simulate hole enlargement
- For a solid pipe (id=0), this reduces to the standard cylinder cross-section
- Conversion factors come from UomDefinitions: `FT3_PER_BBL` (≈ 5.6146 ft³/bbl), `GAL_PER_BBL` (42 gal/bbl)

# See Also
[`area_circle`](@ref), [`calc_capacity`](@ref)
"""
function annular_capacity(
    od::T, id::T;
    unit::DiameterUnit = inch,
    xs::T = 0.0,
    per_length::Bool = true
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

    # Convert diameters to feet for internal calculations
    # UomDefinitions owns the factors (IN_PER_FT = 12, MM_PER_FT = 304.8)
    od_ft = T(to_ft(Diameter(od, unit)).value)
    id_ft = T(to_ft(Diameter(id, unit)).value)

    # Cross-sectional annular area [ft²]
    # Formula: π/4 * (OD² - ID²) * (1 + washout)
    area_ft2::T = (π / T(4)) * (od_ft^2 - id_ft^2) * (T(1) + xs)

    # Early return if only area is requested (avoids unnecessary conversions)
    if !per_length
        return (ft2 = area_ft2,)
    end

    # Capacity per foot [ft³/ft] — numerically equals area in ft²
    # but semantically represents volume per unit length
    capacity_ft3_ft::T = area_ft2

    # Convert to field units: bbl/ft and gal/ft
    # Conversion factors (from UomDefinitions):
    #   GAL_PER_BBL — 1 bbl = 42 gal (petroleum industry standard)
    #   FT3_PER_BBL — 1 bbl ≈ 5.6146 ft³ (derived from L_PER_BBL and M3_PER_FT3)

    capacity_bbl_ft::T = capacity_ft3_ft / T(FT3_PER_BBL)
    capacity_gal_ft::T = capacity_bbl_ft * T(GAL_PER_BBL)

    return (
        ft2 = area_ft2,
        bbl_ft = capacity_bbl_ft,
        gal_ft = capacity_gal_ft,
        ft3_ft = capacity_ft3_ft
    )
end

# ================================================================================
# Helper Functions (Private)
# ================================================================================
# Diameter-to-feet and length-to-feet conversions are provided by
# UomDefinitions (`to_ft(::Diameter)`, `to_ft(::Length)`); an unsupported
# unit surfaces as a MethodError instead of a hand-written ArgumentError.

# ================================================================================
# Public API Extensions
# ================================================================================

"""
    annular_volume(od::T, id::T, length_val::T;
                   unit::DiameterUnit = inch,
                   length_unit::LengthUnit = ft,
                   xs::T = 0.0) where {T <: Real}

Calculate total annular volume for a given axial length.

Wraps `annular_capacity` to compute full volumes rather than per-length rates.

# Arguments
- `od::T`: Outer diameter [in/mm]
- `id::T`: Inner diameter [in/mm]
- `length_val::T`: Axial length of the annulus
- `unit::DiameterUnit`: Unit for diameters (default: inches)
- `length_unit::LengthUnit`: Unit for length (default: feet)
- `xs::T = 0.0`: Washout factor

# Returns
Named tuple with total volumes:
```julia
(
    bbl::T,      # Total volume in barrels
    gal::T,      # Total volume in gallons
    ft3::T,      # Total volume in cubic feet
    m3::T        # Total volume in cubic meters
)
```

# Examples
```julia
# 5000 ft of 8.5\"x5.0\" annulus
annular_volume(8.5, 5.0, 5000.0; unit=inch, length_unit=ft)
```

# See Also
[`annular_capacity`](@ref)
"""
function annular_volume(
    od::T, id::T, length_val::T;
    unit::DiameterUnit = inch,
    length_unit::LengthUnit = ft,
    xs::T = 0.0
) where {T <: Real}

    # Get per-foot capacity
    caps = annular_capacity(od, id; unit=unit, xs=xs, per_length=true)

    # Convert length to feet for calculation
    length_ft::T = T(to_ft(Length(length_val, length_unit)).value)

    # Compute total volumes by scaling per-foot values
    total_bbl::T = caps.bbl_ft * length_ft
    total_gal::T = caps.gal_ft * length_ft
    total_ft3::T = caps.ft3_ft * length_ft

    # Convert to metric (1 ft³ = 0.0283168466 m³) — M3_PER_FT3 from UomDefinitions
    total_m3::T = total_ft3 * T(M3_PER_FT3)

    return (
        bbl = total_bbl,
        gal = total_gal,
        ft3 = total_ft3,
        m3 = total_m3
    )
end
