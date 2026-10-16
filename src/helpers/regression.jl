using Statistics
using LinearAlgebra

# Input guard shared by the regression helpers (spec D4): structural problems
# are `ArgumentError`, non-finite data is UomDefinitions' `InvalidValueError`.
"""
    _check_xy(X, Y, nmin)

`ArgumentError` when `X` and `Y` differ in length, have fewer than `nmin`
points, or `X` has fewer than `nmin` distinct values (singular normal
equations); `InvalidValueError` when any element is non-finite.
"""
function _check_xy(X::AbstractVector{<:Real}, Y::AbstractVector{<:Real}, nmin::Int)
    length(X) == length(Y) ||
        throw(ArgumentError("X and Y must have the same length (got $(length(X)) and $(length(Y)))"))
    length(X) >= nmin ||
        throw(ArgumentError("regression needs at least $nmin points, got $(length(X))"))
    (all(isfinite, X) && all(isfinite, Y)) || throw(InvalidValueError())
    length(unique(X)) >= nmin ||
        throw(ArgumentError("regression needs at least $nmin distinct X values"))
    return nothing
end

# Helper function to calculate linear regression
"""
    linear_regression(X, Y) -> (slope, intercept)

Ordinary least-squares line through the points `(X, Y)` (`AbstractVector{<:Real}`).

Throws `ArgumentError` for mismatched lengths, fewer than two points or fewer
than two distinct `X` values; `InvalidValueError` for non-finite elements.
"""
function linear_regression(X::AbstractVector{<:Real}, Y::AbstractVector{<:Real})
    _check_xy(X, Y, 2)
    X_mean = mean(X)
    Y_mean = mean(Y)
    Sxy = sum((X .- X_mean) .* (Y .- Y_mean))
    Sxx = sum((X .- X_mean) .^ 2)
    slope = Sxy / Sxx
    intercept = Y_mean - slope * X_mean
    return slope, intercept
end

# Helper function to calculate non-linear regression (e.g., quadratic)
"""
    non_linear_regression(X, Y) -> [a, b, c]

Least-squares quadratic `y = a + b·x + c·x²` through the points `(X, Y)`
(`AbstractVector{<:Real}`).

Throws `ArgumentError` for mismatched lengths, fewer than three points or fewer
than three distinct `X` values; `InvalidValueError` for non-finite elements.
"""
function non_linear_regression(X::AbstractVector{<:Real}, Y::AbstractVector{<:Real})
    _check_xy(X, Y, 3)
    X_matrix = hcat(ones(length(X)), X, X .^ 2)
    coeffs = X_matrix \ Y
    return coeffs
end

# Helper function to calculate R^2 value
"""
    calculate_r_squared(Y, Y_fit) -> Float64

Coefficient of determination `1 − SS_res / SS_tot` of the fit `Y_fit` to the
observations `Y` (`AbstractVector{<:Real}`, at least two points). When `Y` is
constant (`SS_tot == 0`) the ratio is undefined; the function returns `1.0`
for an exact fit (residual within `√eps` relative to `Σ Y²`) and `0.0`
otherwise instead of `NaN` / `-Inf`.

Throws `ArgumentError` for mismatched lengths or fewer than two points;
`InvalidValueError` for non-finite elements.
"""
function calculate_r_squared(Y::AbstractVector{<:Real}, Y_fit::AbstractVector{<:Real})
    length(Y) == length(Y_fit) ||
        throw(ArgumentError("Y and Y_fit must have the same length (got $(length(Y)) and $(length(Y_fit)))"))
    length(Y) >= 2 || throw(ArgumentError("R² needs at least two points, got $(length(Y))"))
    (all(isfinite, Y) && all(isfinite, Y_fit)) || throw(InvalidValueError())
    ss_res = sum((Y .- Y_fit) .^ 2)
    ss_tot = sum((Y .- mean(Y)) .^ 2)
    if iszero(ss_tot)                       # constant Y: ratio undefined
        exact = ss_res <= sqrt(eps(Float64)) * max(sum(abs2, Y), 1.0)
        return exact ? 1.0 : 0.0
    end
    return 1 - ss_res / ss_tot
end
