"""
    round_to(value::Real, decimals::Integer) -> Float64

Round `value` to `decimals` decimal places using `Base.round` (round-half-even,
so `round_to(-1.5, 0) == -2.0` and `round_to(2.5, 0) == 2.0`). Integers and
rationals are converted to `Float64` first; `NaN` and `±Inf` pass through.

Throws `ArgumentError` when `decimals` is negative.
"""
function round_to(value::Real, decimals::Integer)
    decimals >= 0 || throw(ArgumentError("decimals must be non-negative, got $decimals"))
    return round(float(value); digits=decimals)
end
