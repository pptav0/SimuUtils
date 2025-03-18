# modules
using CairoMakie;

"""
    plot_regression(
		X_exp, Y_exp, X_fit, Y_fit, regression_type::Symbol;
		title = "Regression Plot", xlabel = "x-axis", ylabel = "y-axis"
	)

    This function plots the experimental data points along with
    the fitted model data using linear or non-linear regression.

# Arguments
- `X_exp::Vector{Float64}`: The X-axis experimental data.
- `Y_exp::Vector{Float64}`: The Y-axis experimental data.
- `X_fit::Vector{Float64}`: The X-axis fitted model data.
- `Y_fit::Vector{Float64}`: The Y-axis fitted model data.
- `regression_type::Symbol`: The type of regression to use (:linear or :non_linear).

# Returns
- `Nothing`
"""
function plot_regression(
		X_exp::Vector{Float64}, Y_exp::Vector{Float64},
		X_fit::Vector{Float64}, Y_fit::Vector{Float64},
		regression_type::Symbol;
		title::String="Regression Plot", xlabel::String="x-axis", ylabel::String="y-axis",
		annotations::Dict{String, Float64}=Dict()
	)
    # Create the plot
    fig = Figure(resolution = (600, 400))
    ax = Axis(fig[1, 1], title=title, xlabel=xlabel, ylabel=ylabel)

    # Plot experimental points
    scatter!(ax, X_exp, Y_exp, color = :blue, label = "Experimental Points")

    # Perform regression fitting
    if regression_type == :linear
        slope, intercept = linear_regression(X_exp, Y_exp)
        fit_Y = slope .* X_fit .+ intercept
        lines!(ax, X_fit, fit_Y, color = :red, linestyle = :dash, label = "Linear Fit")
    elseif regression_type == :non_linear
        coeffs = non_linear_regression(X_exp, Y_exp)
        fit_Y = coeffs[1] .+ coeffs[2] .* X_fit .+ coeffs[3] .* X_fit .^ 2
        lines!(ax, X_fit, fit_Y, color = :green, linestyle = :dash, label = "Non-Linear Fit")
    end

    # Plot fitted model data
    lines!(ax, X_fit, Y_fit, color = :purple, linestyle = :solid, label = "Fitted Model")

    # Calculate the position for the annotations (bottom right)
    x_pos = maximum(X_fit)
    y_pos = minimum(Y_fit)
    # Add annotations
    for (i, (key, value)) in enumerate(annotations)
        text!(
        	ax, x_pos, y_pos - (i-1) * 0.05 * (maximum(Y_fit) - minimum(Y_fit)),
         	text = "$key = $(round(value, digits=4))",
          	color = :purple, align = (:right, :bottom),
           	font = "sans-serif", fontsize = 8
        )
    end

    # Add legend
    axislegend(ax, position = :lt)

    # Display the plot
    display(fig)
end
