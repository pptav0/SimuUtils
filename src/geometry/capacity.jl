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
#   circle_capacity(d::Diameter)                   explicit entry for id = 0
#
# Every physical input is a UomDefinitions quantity (`Diameter`, `Length`,
# `Capacity`); there is no bare-number form anywhere in this file.
#
# Typed-parameter audit (2026-10-16) — every public function is fully typed;
# ten method definitions, none with a bare-number physical parameter. The only
# `Real` is the washout fraction `xs`, which is dimensionless by contract.
#
#   Function                         Physical inputs                 Dimensionless   Status
#   annulus_capacity(od, id)         Diameter, Diameter              xs::Real        typed (core)
#   annulus_capacity(od)             Diameter{U}                     xs::Real        typed
#   circle_capacity(d)               Diameter                        xs::Real        typed
#   hole_capacity(d)                 Diameter                        xs::Real        typed
#   pipe_capacity(id)                Diameter                        —               typed
#   pipe_displacement(od, id)        Diameter, Diameter              —               typed
#   capacity_volume(cap, len)        Capacity, Length                —               typed
#   annulus_volume(od, id, len)      Diameter, Diameter, Length      xs::Real        typed
#   circle_volume(d, len)            Diameter, Length                xs::Real        typed
#   _check_washout(xs)               —                               xs::Real        typed (private)
#
# Output units are chosen with a typed singleton keyword (`out::CapacityUnit`
# or `out::VolumeUnit`); no `unit=` / `length_unit=` input keyword exists.
#
# Error types (D4, closed 2026-10-16): od == id → ZeroCapacityError, od < id →
# NegativeValueError, non-finite xs → InvalidValueError; the only ArgumentError
# left is the structural xs ∉ [0, 1] range check. Negative / non-finite
# diameters and lengths are rejected by the UomDefinitions constructors.
#
# The oilfield-named wrappers (`hole_capacity`, `pipe_capacity`,
# `pipe_displacement`) take `Diameter`s only and fix the semantics and which
# arguments make sense (e.g. washout never applies to steel). All of them
# return a UomDefinitions `Capacity{U}` whose unit is chosen with the `out`
# keyword, and the cross-sectional area is the `m3_m` capacity read as m².

# Shared argument check for the washout / excess factor: non-finite is an
# invalid value (UomDefinitions type); out of range is a structural error.
function _check_washout(xs::Real)
    isfinite(xs) || throw(InvalidValueError())
    0.0 <= xs <= 1.0 || throw(ArgumentError("Washout factor xs must be in [0.0, 1.0], got $xs."))
end

# ================================================================================
# Generic geometries
# ================================================================================
"""
    circle_capacity(d::Diameter; xs::Real = 0.0, out::CapacityUnit = bbl_ft) -> Capacity

Capacity (volume per unit length) of a full circle of diameter `d`,
i.e. the non-annular case: an open hole or the inside of a pipe.

The area is computed as `π/4 * d²` with optional washout excess.

# Arguments
- `d::Diameter`: Diameter of the circle (hole size or pipe ID); the unit travels with it
- `xs::Real = 0.0`: Washout/excess area factor as a fraction (0.0–1.0).
    Accounts for hole enlargement beyond nominal diameter.
- `out::CapacityUnit = bbl_ft`: Output unit singleton from UomDefinitions:
    `bbl_ft`, `gal_ft`, `m3_m` or `l_m`.

# Returns
A UomDefinitions `Capacity{U}` tagged with the requested unit. The bare
number is `.value`; convert later with `to_l_m`, `to_gal_ft`, … or
`to_unit(cap, unit)`. The cross-sectional area is numerically the `m3_m`
capacity in m² (`to_m3_m(cap).value`).

# Throws
- `NegativeValueError` / `InvalidValueError`: raised by `Diameter` for a negative or non-finite value
- `ZeroCapacityError`: If `d == 0` (no area)
- `InvalidValueError`: If `xs` is non-finite; `ArgumentError`: If `xs ∉ [0.0, 1.0]`
- `MethodError`: If a bare number is passed instead of a `Diameter`

Equivalent to the single-`Diameter` form of [`annulus_capacity`](@ref); provided
so the intent reads at the call site.

# Examples
```julia
circle_capacity(Diameter(8.5, inch))               # 0.0702 bbl/ft (8.5" open hole)
circle_capacity(Diameter(4.892, inch); out=l_m)    # 12.13 L/m   (5.5" 17# casing ID)
circle_capacity(Diameter(215.9, mm); xs=0.10)      # 10 % washout
```

# See Also
[`hole_capacity`](@ref), [`pipe_capacity`](@ref), [`annulus_capacity`](@ref)
"""
function circle_capacity(
    d::Diameter;
    xs::Real = 0.0,
    out::CapacityUnit = bbl_ft
)
    return annulus_capacity(d; xs=xs, out=out)
end

"""
    annulus_capacity(od::Diameter, id::Diameter; xs=0.0, out=bbl_ft) -> Capacity
    annulus_capacity(od::Diameter; xs=0.0, out=bbl_ft) -> Capacity               # full circle

Capacity (volume per unit length) of the ring between two concentric
cylindrical boundaries. This is the single geometric core of the file: every
other capacity function reduces to it.

The typed form takes UomDefinitions `Diameter` quantities, so each diameter
carries its own unit and **`od` and `id` may be in different units** (an 8.5 in
hole around a 127 mm casing is fine): both are converted to inches before the
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
- `ZeroCapacityError`: If `od == id` after conversion to inches (judged with `rtol = 1e-9`): zero annulus
- `NegativeValueError`: If `od < id` after conversion: inverted (negative) annulus
- `InvalidValueError`: If `xs` is non-finite; `ArgumentError`: If `xs ∉ [0.0, 1.0]` (structural)
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
    # Equal boundaries are a zero annulus (solid rod / no hole). Unit conversion
    # is not bit-exact (139.7 mm → 5.499999999999999 in), so "equal" is judged
    # with a 1e-9 relative tolerance: far below any quoted diameter resolution
    # (0.001 in) and far above Float64 conversion noise (~1e-15).
    isapprox(od_in, id_in; rtol=1e-9) && throw(ZeroCapacityError())
    od_in < id_in && throw(NegativeValueError())       # inverted: negative annular area

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
    hole_capacity(d::Diameter; xs=0.0, out=bbl_ft) -> Capacity

Open-hole capacity: a full circle of hole size `d`, with optional washout
`xs`. Thin wrapper over the single-`Diameter` form of [`annulus_capacity`](@ref).

```julia
hole_capacity(Diameter(8.5, inch))             # 0.0702 bbl/ft
hole_capacity(Diameter(215.9, mm); xs=0.10)    # 10 % washout
```
"""
hole_capacity(d::Diameter; xs::Real = 0.0, out::CapacityUnit = bbl_ft) =
    annulus_capacity(d; xs=xs, out=out)

"""
    pipe_capacity(id::Diameter; out=bbl_ft) -> Capacity

Internal capacity of a pipe (casing, tubing, drill pipe) from its inner
diameter `id`. A full circle; washout does not apply to a pipe bore.
Thin wrapper over the single-`Diameter` form of [`annulus_capacity`](@ref).

```julia
pipe_capacity(Diameter(4.892, inch))           # 0.0232 bbl/ft (5.5" 17# casing)
pipe_capacity(Diameter(124.26, mm); out=l_m)   # 12.13 L/m
```
"""
pipe_capacity(id::Diameter; out::CapacityUnit = bbl_ft) =
    annulus_capacity(id; xs=0.0, out=out)

"""
    pipe_displacement(od::Diameter, id::Diameter; out=bbl_ft) -> Capacity

Steel displacement of a pipe per unit length, from its outer diameter `od`
and inner diameter `id` (the wall cross-section). Washout does not apply.
`od` and `id` may carry different units. Thin wrapper over [`annulus_capacity`](@ref).

```julia
pipe_displacement(Diameter(5.5, inch), Diameter(4.892, inch))   # 0.0061 bbl/ft
```
"""
pipe_displacement(od::Diameter, id::Diameter; out::CapacityUnit = bbl_ft) =
    annulus_capacity(od, id; xs=0.0, out=out)

# ================================================================================
# Volumes
# ================================================================================
"""
    capacity_volume(cap::Capacity, len::Length; out::VolumeUnit = bbl) -> Volume

Total volume of any capacity over an axial length: `cap × len`.

Works with the result of every capacity function above, so there is a single
volume routine instead of one per geometry. Both inputs are UomDefinitions
quantities, so each carries its own unit; there is no bare-number form.

# Arguments
- `cap::Capacity`: Capacity per unit length (any unit)
- `len::Length`: Axial length (`ft` or `m`)
- `out::VolumeUnit = bbl`: Output unit singleton: `bbl`, `m3` or `ltr`

# Returns
A UomDefinitions `Volume{U}` tagged with the requested unit. Convert later
with `to_bbl`, `to_m3`, `to_ltr` or `to_unit(vol, unit)`.

# Throws
- `NegativeValueError` / `InvalidValueError`: raised by `Length` for a negative or non-finite length
- `MethodError`: If a bare number is passed instead of a `Length`
- `TypeError`: If `out` is not a `VolumeUnit` singleton

# Examples
```julia
capacity_volume(annulus_capacity(Diameter(8.5, inch), Diameter(5.0, inch)), Length(5000.0, ft))   # 229.48 bbl
capacity_volume(pipe_capacity(Diameter(4.892, inch)), Length(1524.0, m); out=m3)                 # 18.48 m³
```
"""
function capacity_volume(
    cap::Capacity, len::Length;
    out::VolumeUnit = bbl
)
    # Convert capacity to L/m and length to metres for calculation
    cap_ltr_m = to_l_m(cap).value
    length_m = to_m(len).value

    # Total volume [L] by scaling the per-metre capacity, then tag it as a
    # UomDefinitions `Volume` and convert to the requested output unit
    total_ltr = cap_ltr_m * length_m

    return to_unit(Volume(total_ltr, ltr), out)
end

"""
    annulus_volume(od::Diameter, id::Diameter, len::Length;
                   xs::Real = 0.0, out::VolumeUnit = bbl) -> Volume

Total annular volume over an axial length `len`.

Wraps [`annulus_capacity`](@ref) and [`capacity_volume`](@ref) to compute
full volumes rather than per-length rates. `od` and `id` may carry different
units; `len` carries its own.

# Arguments
- `od::Diameter`: Outer boundary (hole size, outer casing ID)
- `id::Diameter`: Inner boundary (inner casing OD)
- `len::Length`: Axial length of the annulus (`ft` or `m`)
- `xs::Real = 0.0`: Washout factor, `0.0 ≤ xs ≤ 1.0`
- `out::VolumeUnit = bbl`: Output unit singleton: `bbl`, `m3` or `ltr`

# Returns
A UomDefinitions `Volume{U}` tagged with the requested unit.

# Throws
As [`annulus_capacity`](@ref) and [`capacity_volume`](@ref); `MethodError` for any bare number.

# Examples
```julia
# 5000 ft of 8.5" x 5.0" annulus
annulus_volume(Diameter(8.5, inch), Diameter(5.0, inch), Length(5000.0, ft))            # 229.48 bbl
annulus_volume(Diameter(215.9, mm), Diameter(127.0, mm), Length(1524.0, m); out=m3)     # 36.49 m³
```
"""
annulus_volume(od::Diameter, id::Diameter, len::Length;
               xs::Real = 0.0, out::VolumeUnit = bbl) =
    capacity_volume(annulus_capacity(od, id; xs=xs), len; out=out)

"""
    circle_volume(d::Diameter, len::Length; xs::Real = 0.0, out::VolumeUnit = bbl) -> Volume

Total volume of a full circle (open hole or pipe bore) over an axial length.
Wraps [`circle_capacity`](@ref) and [`capacity_volume`](@ref); arguments as
in [`annulus_volume`](@ref).

```julia
circle_volume(Diameter(8.5, inch), Length(1000.0, ft))          # 70.19 bbl
```
"""
circle_volume(d::Diameter, len::Length;
              xs::Real = 0.0, out::VolumeUnit = bbl) =
    capacity_volume(circle_capacity(d; xs=xs), len; out=out)
