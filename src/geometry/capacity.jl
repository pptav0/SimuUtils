# ================================================================================
# Capacity Calculations (cross-sectional area and volume per unit length)
# ================================================================================
#
# One geometry covers every wellbore capacity: the annulus between two
# concentric circles, π/4 · (od² − id²) · (1 + xs). A full circle (open hole,
# pipe bore) is the annulus with `id = 0`, so there is exactly one core:
#
#   annulus_capacity(od, id=0)   unit-aware: DiameterUnit in, CapacityUnit out
#   circle_capacity(d)           explicit entry point for the id = 0 case
#
# The oilfield-named wrappers (`hole_capacity`, `pipe_capacity`,
# `pipe_displacement`) only fix the semantics and which arguments make sense
# (e.g. washout never applies to steel). All of them return a UomDefinitions
# `Capacity{U}` whose unit is chosen with the `out` keyword, and the
# cross-sectional area is the `m3_m` capacity read as m².

# Shared argument check for the washout / excess factor
function _check_washout(xs::Real)
    if !(0.0 <= xs <= 1.0)
        throw(ArgumentError("Washout factor xs must be in [0.0, 1.0], got $xs."))
    end
end

# ================================================================================
# Generic geometries
# ================================================================================
"""
    circle_capacity(d::Real;
                    unit::DiameterUnit = inch,
                    xs::Real = 0.0,
                    out::CapacityUnit = bbl_ft) -> Capacity

Capacity (volume per unit length) of a full circle of diameter `d`,
i.e. the non-annular case: an open hole or the inside of a pipe.

The area is computed as `π/4 * d²` with optional washout excess.

# Arguments
- `d::Real`: Diameter of the circle (hole size or pipe ID) [in/mm]
- `unit::DiameterUnit = inch`: Unit of the input diameter (`inch` or `mm` singletons from UomDefinitions)
- `xs::Real = 0.0`: Washout/excess area factor as percentage (0.0–1.0).
    Accounts for hole enlargement beyond nominal diameter.
- `out::CapacityUnit = bbl_ft`: Output unit singleton from UomDefinitions:
    `bbl_ft`, `gal_ft`, `m3_m` or `l_m`.

# Returns
A UomDefinitions `Capacity{U}` tagged with the requested unit. The bare
number is `.value`; convert later with `to_l_m`, `to_gal_ft`, … or
`to_unit(cap, unit)`. The cross-sectional area is numerically the `m3_m`
capacity in m² (`to_m3_m(cap).value`).

# Throws
- `ArgumentError`: If `d ≤ 0`
- `ArgumentError`: If `xs ∉ [0.0, 1.0]` (invalid washout factor)

Equivalent to `annulus_capacity(d, 0; …)`; provided so the intent reads at
the call site.

# Examples
```julia
circle_capacity(8.5; unit=inch)              # 0.0702 bbl/ft (8.5" open hole)
circle_capacity(4.892; unit=inch, out=l_m)   # 12.12 L/m   (5.5" 17# casing ID)
```

# See Also
[`hole_capacity`](@ref), [`pipe_capacity`](@ref), [`annulus_capacity`](@ref)
"""
function circle_capacity(
    d::Real;
    unit::DiameterUnit = inch,
    xs::Real = 0.0,
    out::CapacityUnit = bbl_ft
)
    # Validate inputs
    # -----------------
    return annulus_capacity(d, zero(d); unit=unit, xs=xs, out=out)
end

"""
    annulus_capacity(od::Real, id::Real = 0;
                     unit::DiameterUnit = inch,
                     xs::Real = 0.0,
                     out::CapacityUnit = bbl_ft) -> Capacity

Calculate the capacity (volume per unit length) of the ring between two
concentric cylindrical boundaries. This is the single geometric core of the
file: every other capacity function reduces to it.

This function generalizes annular area calculations for:
- Open Hole (OH) to casing OD scenarios
- Casing-to-casing annular spaces
- Pipe wall (steel) cross-sections — see [`pipe_displacement`](@ref)
- Full circles (open hole, pipe bore) when `id = 0` — see [`circle_capacity`](@ref)
- Any concentric cylinder pair (outer boundary -> inner boundary)

The annular area is computed as `π/4 * (od² - id²)` with optional washout excess.

# Arguments
- `od::Real`: Outer diameter of the annulus (e.g., open hole diameter or outer casing ID) [in/mm]
- `id::Real = 0`: Inner diameter of the annulus (e.g., inner casing OD) [in/mm]; zero gives a full circle
- `unit::DiameterUnit = inch`: Unit of input diameters (`inch` or `mm` singletons from UomDefinitions)
- `xs::Real = 0.0`: Washout/excess area factor as percentage (0.0–1.0).
    Accounts for hole enlargement beyond nominal diameter.
- `out::CapacityUnit = bbl_ft`: Output unit singleton from UomDefinitions:
    `bbl_ft`, `gal_ft`, `m3_m` or `l_m`.

# Returns
A UomDefinitions `Capacity{U}` tagged with the requested unit, e.g.
`Capacity{BBL_PER_FT}`. The bare number is `.value`; convert later with
`to_l_m`, `to_gal_ft`, … or `to_unit(cap, unit)`. The cross-sectional area
is numerically the `m3_m` capacity in m² (`to_m3_m(cap).value`).

# Throws
- `ArgumentError`: If `od ≤ id` or `id < 0` (invalid annular geometry)
- `ArgumentError`: If `xs ∉ [0.0, 1.0]` (invalid washout factor)
- `MethodError`: If `unit` or `out` is not a supported singleton

# Examples
```julia
# 8.5\" OH with 5.0\" casing OD, no washout
annulus_capacity(8.5, 5.0; unit=inch)                  # 0.0459 bbl/ft

# 12.25\" OH with 9.625\" casing OD, 10% washout
annulus_capacity(12.25, 9.625; unit=inch, xs=0.10)

# Millimeter inputs, metric output
annulus_capacity(215.9, 127.0; unit=mm, out=l_m)       # 23.94 L/m

# Cross-sectional area in m² (m³/m is numerically m²)
annulus_capacity(8.5, 5.0; out=m3_m).value
```

# Notes
- The output unit is chosen with `out`; field (bbl/ft, gal/ft) and metric (m³/m, L/m) are all supported
- The washout factor `xs` multiplies the area by `(1 + xs)` to simulate hole enlargement
- Conversion factors come from UomDefinitions (`M_PER_FT`, `M3_M_PER_BBL_FT`, `GAL_PER_BBL`, `L_PER_M3`)

# See Also
[`circle_capacity`](@ref), [`pipe_displacement`](@ref), [`capacity_volume`](@ref), [`calc_capacity`](@ref)
"""
function annulus_capacity(
    od::Real, id::Real = zero(od);
    unit::DiameterUnit = inch,
    xs::Real = 0.0,
    out::CapacityUnit = bbl_ft
)
    # Validate inputs
    # -----------------
    if id < 0
        throw(ArgumentError("Inner diameter ($id) cannot be negative."))
    end
    if od <= id
        throw(ArgumentError(
            "Outer diameter ($od) must exceed inner diameter ($id). " *
            "Invalid annular geometry."
        ))
    end
    _check_washout(xs)

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
# Oilfield-named wrappers
# ================================================================================
"""
    hole_capacity(d::Real; unit=inch, xs=0.0, out=bbl_ft) -> Capacity

Open-hole capacity: a full circle of hole size `d`, with optional washout
`xs`. Thin wrapper over [`circle_capacity`](@ref).
"""
hole_capacity(d::Real; unit::DiameterUnit = inch, xs::Real = 0.0, out::CapacityUnit = bbl_ft) =
    circle_capacity(d; unit=unit, xs=xs, out=out)

"""
    pipe_capacity(id::Real; unit=inch, out=bbl_ft) -> Capacity

Internal capacity of a pipe (casing, tubing, drill pipe) from its inner
diameter `id`. A full circle; washout does not apply to a pipe bore.
Thin wrapper over [`circle_capacity`](@ref).
"""
pipe_capacity(id::Real; unit::DiameterUnit = inch, out::CapacityUnit = bbl_ft) =
    circle_capacity(id; unit=unit, xs=0.0, out=out)

"""
    pipe_displacement(od::Real, id::Real; unit=inch, out=bbl_ft) -> Capacity

Steel displacement of a pipe per unit length, from its outer diameter `od`
and inner diameter `id` (the wall cross-section). Washout does not apply.
Thin wrapper over [`annulus_capacity`](@ref).
"""
pipe_displacement(od::Real, id::Real; unit::DiameterUnit = inch, out::CapacityUnit = bbl_ft) =
    annulus_capacity(od, id; unit=unit, xs=0.0, out=out)

# ================================================================================
# Volumes
# ================================================================================
"""
    capacity_volume(cap::Capacity, length_val::Real;
                    length_unit::LengthUnit = ft,
                    out::VolumeUnit = bbl) -> Volume

Total volume of any capacity over an axial length: `cap × length`.

Works with the result of every capacity function above, so there is a single
volume routine instead of one per geometry.

# Arguments
- `cap::Capacity`: Capacity per unit length (any unit)
- `length_val::Real`: Axial length
- `length_unit::LengthUnit = ft`: Unit for length (`ft` or `m`)
- `out::VolumeUnit = bbl`: Output unit singleton: `bbl`, `m3` or `ltr`

# Returns
A UomDefinitions `Volume{U}` tagged with the requested unit. Convert later
with `to_bbl`, `to_m3`, `to_ltr` or `to_unit(vol, unit)`.

# Examples
```julia
capacity_volume(annulus_capacity(8.5, 5.0), 5000.0)                    # 229.48 bbl
capacity_volume(pipe_capacity(4.892), 1524.0; length_unit=m, out=m3)   # 18.48 m³
```
"""
function capacity_volume(
    cap::Capacity, length_val::Real;
    length_unit::LengthUnit = ft,
    out::VolumeUnit = bbl
)
    # Convert capacity to m³/m and length to meters for calculation
    cap_m3_m = to_m3_m(cap).value
    length_m = to_m(Length(length_val, length_unit)).value

    # Total volume [m³] by scaling the per-meter capacity, then tag it as a
    # UomDefinitions `Volume` and convert to the requested output unit
    total_m3 = cap_m3_m * length_m

    return to_unit(Volume(total_m3, m3; digits=10), out)
end

"""
    annulus_volume(od::Real, id::Real, length_val::Real;
                   unit::DiameterUnit = inch,
                   length_unit::LengthUnit = ft,
                   xs::Real = 0.0,
                   out::VolumeUnit = bbl) -> Volume

Calculate total annular volume for a given axial length.

Wraps [`annulus_capacity`](@ref) and [`capacity_volume`](@ref) to compute
full volumes rather than per-length rates.

# Arguments
- `od::Real`: Outer diameter [in/mm]
- `id::Real`: Inner diameter [in/mm]
- `length_val::Real`: Axial length of the annulus
- `unit::DiameterUnit`: Unit for diameters (default: inches)
- `length_unit::LengthUnit`: Unit for length (default: feet)
- `xs::Real = 0.0`: Washout factor
- `out::VolumeUnit = bbl`: Output unit singleton: `bbl`, `m3` or `ltr`

# Returns
A UomDefinitions `Volume{U}` tagged with the requested unit (rounded to
4 digits by the `Volume` constructor).

# Examples
```julia
# 5000 ft of 8.5\"x5.0\" annulus
annulus_volume(8.5, 5.0, 5000.0; unit=inch, length_unit=ft)           # 229.48 bbl
annulus_volume(8.5, 5.0, 1524.0; unit=inch, length_unit=m, out=m3)    # 36.49 m³
```
"""
annulus_volume(od::Real, id::Real, length_val::Real;
               unit::DiameterUnit = inch, length_unit::LengthUnit = ft,
               xs::Real = 0.0, out::VolumeUnit = bbl) =
    capacity_volume(annulus_capacity(od, id; unit=unit, xs=xs), length_val;
                    length_unit=length_unit, out=out)

"""
    circle_volume(d::Real, length_val::Real;
                  unit::DiameterUnit = inch,
                  length_unit::LengthUnit = ft,
                  xs::Real = 0.0,
                  out::VolumeUnit = bbl) -> Volume

Total volume of a full circle (open hole or pipe bore) over an axial length.
Wraps [`circle_capacity`](@ref) and [`capacity_volume`](@ref); arguments as
in [`annulus_volume`](@ref).
"""
circle_volume(d::Real, length_val::Real;
              unit::DiameterUnit = inch, length_unit::LengthUnit = ft,
              xs::Real = 0.0, out::VolumeUnit = bbl) =
    capacity_volume(circle_capacity(d; unit=unit, xs=xs), length_val;
                    length_unit=length_unit, out=out)
