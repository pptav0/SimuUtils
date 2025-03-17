using Statistics
using LinearAlgebra

# Helper function to calculate linear regression
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
function non_linear_regression(X, Y)
    X_matrix = hcat(ones(length(X)), X, X .^ 2)
    coeffs = X_matrix \ Y
    return coeffs
end
