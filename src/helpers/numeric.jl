"""
    round_to(value::T, decimals::Int) where T <: Real

Round a value to a given number of decimals.

# Arguments
- `value::T`: The value to round.
- `decimals::Int`: The number of decimals to round to.

# Returns
- `T`: The rounded value.
"""
function round_to(value::T, decimals::Int) where T <: Real
    factor = 10.0 ^ decimals;
    round(value * factor) / factor
end
