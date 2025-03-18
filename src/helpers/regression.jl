using Statistics
using LinearAlgebra

# Helper function to calculate linear regression
"""
	linear_regression(X::Vector{Float64}, Y::Vector{Float64})

	This function calculates the linear regression coefficients (slope and intercept)
	for the given X and Y data points.

# Arguments
- `X::Vector{Float64}`: The X-axis data points.
- `Y::Vector{Float64}`: The Y-axis data points.

# Returns
- `Tuple{Float64, Float64}`: The linear regression coefficients (slope, intercept).
"""
function linear_regression(X, Y)
    n = length(X)
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
	non_linear_regression(X::Vector{Float64}, Y::Vector{Float64})

	This function calculates the non-linear regression coefficients (a, b, c)
	for the given X and Y data points using a quadratic model.

# Arguments
- `X::Vector{Float64}`: The X-axis data points.
- `Y::Vector{Float64}`: The Y-axis data points.

# Returns
- `Vector{Float64}`: The non-linear regression coefficients (a, b, c).
"""
function non_linear_regression(X, Y)
    X_matrix = hcat(ones(length(X)), X, X .^ 2)
    coeffs = X_matrix \ Y
    return coeffs
end

# Helper function to calculate R^2 value
"""
	calculate_r2(Y::Vector{Float64}, Y_fit::Vector{Float64})

	This function calculates the R^2 value for the given Y and Y_fit data points.

# Arguments
- `Y::Vector{Float64}`: The original Y-axis data points.
- `Y_fit::Vector{Float64}`: The fitted Y-axis data points.

# Returns
- `Float64`: The R^2 value.
"""
function calculate_r_squared(Y, Y_fit)
    ss_res = sum((Y .- Y_fit) .^ 2)
    ss_tot = sum((Y .- mean(Y)) .^ 2)
    return 1 - ss_res / ss_tot
end
