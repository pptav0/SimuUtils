# modules
# using WGLMakie;
using CairoMakie;

"""
	linear_regression(X::Vector{Float64}, Y::Vector{Float64})

    plot_regression(
		X_exp::Vector{Float64}, Y_exp::Vector{Float64},
		X_fit::Vector{Float64}, Y_fit::Vector{Float64},
		regression_type::Symbol;
		title::String="Regression Plot", xlabel::String="x-axis", ylabel::String="y-axis",
		annotations::Dict{String, Float64}=Dict(), figres=(450, 300)
	)

    This function plots the experimental data points along with
    the fitted model data using linear or non-linear regression.

# Arguments
- `X_exp`: 			The experimental X-axis data points.
- `Y_exp`: 			The experimental Y-axis data points.
- `X_fit`: 			The fitted X-axis data points.
- `Y_fit`: 			The fitted Y-axis data points.
- `regression_type`: The type of regression to use (:linear or :non_linear).
- `title`: 			The title of the plot.
- `xlabel`: 		The label for the x-axis.
- `ylabel`: 		The label for the y-axis.
- `annotations`: 	The annotations to display on the plot.
- `figres`: 		The resolution of the figure.

# Returns
- `Nothing`
"""
function plot_regression(
    X_exp::Vector{Float64}, Y_exp::Vector{Float64},
    X_fit::Vector{Float64}, Y_fit::Vector{Float64},
    regression_type::Symbol;
    title::AbstractString="Regression Plot", xlabel::AbstractString="x-axis", ylabel::AbstractString="y-axis",
    annotations::Dict{AbstractString,Float64}=Dict(), figres=(450, 300),
    label_fit_model::AbstractString="Fitted Model"
)
    # Create the plot
    fig = Figure(; size=figres, fontsize=12)
    ax = Axis(fig[1, 1], title=title, xlabel=xlabel, ylabel=ylabel)

    # Plot experimental points
    scatter!(ax, X_exp, Y_exp, color=:blue, label="Experimental Points")

    # Perform regression fitting
    if regression_type == :linear
        slope, intercept = linear_regression(X_exp, Y_exp)
        fit_Y = @. slope * X_fit + intercept
        r_squared = calculate_r_squared(Y_exp, @. slope * X_exp + intercept)
        label = "Linear Fit (R² = $(round(r_squared, digits=3)))"
        lines!(ax, X_fit, fit_Y, color=:red, linestyle=:dash, label=label)
    elseif regression_type == :non_linear
        coeffs = non_linear_regression(X_exp, Y_exp)
        fit_Y = @. coeffs[1] + coeffs[2] * X_fit + coeffs[3] * X_fit^2
        r_squared = calculate_r_squared(Y_exp, @. coeffs[1] + coeffs[2] * X_exp + coeffs[3] * X_exp^2)
        label = "Non-Linear Fit (R² = $(round(r_squared, digits=3)))"
        lines!(ax, X_fit, fit_Y, color=:green, linestyle=:dash, label=label)
    end

    # Plot fitted model data
    lines!(ax, X_fit, Y_fit, color=:purple, linestyle=:solid, label=label_fit_model)

    # Calculate the position for the annotations (bottom right)
    x_pos = maximum(X_fit)
    y_pos = minimum(Y_fit)
    # Add annotations
    for (i, (key, value)) in enumerate(annotations)
        text!(
            ax, x_pos, y_pos - (i - 1) * 0.05 * (maximum(Y_fit) - minimum(Y_fit)),
            text=@sprintf("%s = %.4f", key, value),
            color=:purple, align=(:right, :bottom),
            font="sans-serif", fontsize=12
        )
    end

    # Add legend
    axislegend(ax, position=:lt)

    # Display the plot
    # display(fig)
    return fig
end
