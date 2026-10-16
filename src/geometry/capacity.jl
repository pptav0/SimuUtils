# ================================================================================
# Capacity Calculations (cross-sectional area and volume per unit length)
# ================================================================================
#
# One geometry covers every wellbore capacity: the annulus between two
# concentric circles, π/4 · (od² − id²) · (1 + xs). A full circle (open hole,
# pipe bore) is the annulus with `id = 0`, so there is exactly one core:
#
#   annulus_capacity(od::Diameter, id::Diameter)   typed core; od and id may
#                                                  carry different units
#   annulus_capacity(od::Diameter)                 full circle (id = 0)
#   circle_capacity(d; unit)                       Real entry for id = 0 (tags d)
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
- `NegativeValueError` / `InvalidValueError`: If `d` is negative or non-finite (raised by `Diameter`)
- `ArgumentError`: If `d == 0` (no area)
- `ArgumentError`: If `xs ∉ [0.0, 1.0]` (invalid washout factor)

Equivalent to `annulus_capacity(Diameter(d, unit); …)`; provided so the intent
reads at the call site.

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
    return annulus_capacity(Diameter(d, unit); xs=xs, out=out)
end

"""
    annulus_capacity(od::Diameter, id::Diameter; xs=0.0, out=bbl_ft) -> Capacity
    annulus_capacity(od::Diameter; xs=0.0, out=bbl_ft) -> Capacity               # full circle

Capacity (volume per unit length) of the ring between two concentric
cylindrical boundaries. This is the single geometric core of the file: every
other capacity function reduces to it.

The typed form takes UomDefinitions `Diameter` quantities, so each diameter
carries its own unit and **`od` and `id` may be in different units** (an 8.5 in
hole around a 127 mm casing is fine): both are converted to metres before the
comparison and the area. A single `Diameter` is the full circle (`id = 0` in
`od`'s unit). There is no untyped form: callers tag their numbers with
`Diameter(value, unit)`.

Covers:
- Open hole to casing OD, casing-to-casing annuli, any concentric pair
- Pipe wall (steel) cross-sections — see [`pipe_displacement`](@ref)
- Full circles (open hole, pipe bore) — see [`circle_capacity`](@ref)

The annular area is `π/4 · (od² − id²) · (1 + xs)`.

# Arguments
- `od::Diameter`: Outer boundary (hole size, outer casing ID)
- `id::Diameter`: Inner boundary (inner casing OD); omit it for a full circle
- `xs::Real = 0.0`: Washout / excess area factor, `0.0 ≤ xs ≤ 1.0`
- `out::CapacityUnit = bbl_ft`: `bbl_ft`, `gal_ft`, `m3_m` or `l_m`

# Returns
A UomDefinitions `Capacity{U}` tagged with `out`. The bare number is `.value`;
the cross-sectional area is numerically the `m3_m` capacity in m²
(`to_m3_m(cap).value`).

# Throws
- `NegativeValueError` / `InvalidValueError`: negative or non-finite diameters (raised by `Diameter`)
- `ArgumentError`: If `od ≤ id` after conversion to metres (invalid annular geometry)
- `ArgumentError`: If `xs ∉ [0.0, 1.0]`
- `MethodError`: If a bare number is passed instead of a `Diameter`
- `TypeError`: If `out` is not a `CapacityUnit` singleton

# Examples
```julia
annulus_capacity(Diameter(8.5, inch), Diameter(5.0, inch))        # 0.0459 bbl/ft
annulus_capacity(Diameter(8.5, inch), Diameter(127.0, mm))        # same annulus, mixed units
annulus_capacity(Diameter(215.9, mm); out=l_m)                    # full circle, L/m
annulus_capacity(Diameter(12.25, inch), Diameter(9.625, inch); xs=0.10)   # 10 % washout
annulus_capacity(Diameter(8.5, inch), Diameter(5.0, inch); out=m3_m).value  # area in m²
```

# See Also
[`circle_capacity`](@ref), [`pipe_displacement`](@ref), [`capacity_volume`](@ref)
"""
function annulus_capacity(
    od::Diameter, id::Diameter;
    xs::Real = 0.0,
    out::CapacityUnit = bbl_ft
)
    _check_washout(xs)

    # Each Diameter carries its own unit; compare and compute in inches.
    # Finiteness and sign were already enforced by the Diameter constructor.
    od_in = to_in(od).value
    id_in = to_in(id).value
    od_in > id_in || throw(ArgumentError(
        "Outer diameter ($od) must exceed inner diameter ($id). Invalid annular geometry."
    ))

    # Cross-sectional annular area: π/4 · (OD² − ID²) · (1 + washout) in in²,
    # then in² → m² (M_PER_IN²) and m²  ≡ m³/m → L/m (L_PER_M3)
    area = (π / 4) * (od_in^2 - id_in^2) * (1 + xs) * M_PER_IN^2 * L_PER_M3

    # Tag as L/m and let `to_unit` produce bbl/ft, gal/ft, m³/m or L/m.
    return to_unit(Capacity(area, l_m), out)
end

# Full circle: inner boundary of zero in the outer diameter's own unit.
annulus_capacity(od::Diameter{U}; xs::Real = 0.0, out::CapacityUnit = bbl_ft) where {U<:DiameterUnit} =
    annulus_capacity(od, Diameter{U}(0.0); xs=xs, out=out)

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
    annulus_capacity(Diameter(od, unit), Diameter(id, unit); xs=0.0, out=out)

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

    return to_unit(Volume(total_m3, m3), out)
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
A UomDefinitions `Volume{U}` tagged with the requested unit.

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
    capacity_volume(annulus_capacity(Diameter(od, unit), Diameter(id, unit); xs=xs), length_val;
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
