using CairoMakie

"""
	plot_regression(X::Vector{Float64}, Y::Vector{Float64})

	This function plots the experimental data points along with
	the linear and non-linear regression lines.

# Arguments
- `X::Vector{Float64}`: The X-axis data.
- `Y::Vector{Float64}`: The Y-axis data.

# Returns
- `Nothing`
"""
function plot_regression(X, Y)
    # Calculate linear regression
    slope, intercept = linear_regression(X, Y)
    linear_fit = X -> slope * X + intercept

    # Calculate non-linear regression (quadratic)
    coeffs = non_linear_regression(X, Y)
    non_linear_fit = X -> coeffs[1] + coeffs[2] * X + coeffs[3] * X^2

    # Create the plot
    fig = Figure(resolution = (600, 400))
    ax = Axis(fig[1, 1], title = "Regression Plot", xlabel = "X", ylabel = "Y")

    # Plot experimental points
    scatter!(ax, X, Y, color = :blue, label = "Experimental Points")

    # Plot linear regression line
    linear_X = range(minimum(X), stop = maximum(X), length = 100)
    linear_Y = linear_fit.(linear_X)
    lines!(ax, linear_X, linear_Y, color = :green, linestyle = :dash, label = "linear Regression")

    # Plot non-linear regression line
    non_linear_X = range(minimum(X), stop = maximum(X), length = 100)
    non_linear_Y = non_linear_fit.(non_linear_X)
    lines!(ax, non_linear_X, non_linear_Y, color = :red, label = "Non-Linear Regression")


    # Add legend
    axislegend(ax, position = :rt)

    # Display the plot
    display(fig)
end
