"""
	area_circle(od::T, id::T=0.0; xs::T=0.0) where T <: Real

Calculate the area of a ring given the outer diameter and inner diameter.
If inner diameter is not provided, it is assumed to be zero. It also
accepts a cross-sectional % excess area.

# Arguments
- `od::T`: The outer diameter of the ring.
- `id::T=0.0`: The inner diameter of the ring.
- `xs::T=0.0`: The cross-sectional % excess area.

# Returns
- `T`: The area of the ring.
"""
function area_circle(od::T, id::T=0.0; xs::T=0.0) where T <: Real
	if !(0.0 <= xs <= 1.0)
        throw(ArgumentError("xs must be between 0.0 and 1.0"))
    end
	(π/4) * (od^2 - id^2) * (1+xs)
end
