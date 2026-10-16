# Function to plot rheology using GHB model
"""
    plot_rheology(readings::FannReadings, regression_type::Symbol)

    This function plots the experimental data points along with
    the GHB model fit using the readings from a Fann35 rheometer.

# Arguments
- `readings::FannReadings`: The experimental readings.
- `regression_type::Symbol`: The type of regression to use (:linear or :non_linear).

# Returns
- `Nothing`
"""
function plot_rheology(
    readings::FannReadings, regression_type::Symbol;
    k1::Float64=0.0, k2::Float64=0.0,
    rotor::Rotor=R1, bob::Bob=B1, spring::Spring=F1,
    figres=(640, 400), scale=identity
)
    # Calculate shear rates and shear stresses
    shear_rates, shear_stresses = FannRheology(
        readings; k1=k1, k2=k2,
        rotor=rotor, bob=bob, spring=spring
    )

    # Fit the GHB model
    params, r2 = ghb_model_fit(shear_rates, shear_stresses)
    ghb_fit_func = γ̇ -> ghb_model(γ̇, params)

    # Annotations for the fitted parameters
    annotations = Dict{AbstractString,Float64}(
        "τ₀ (lbf/100ft2)" => params[1], # τ,
        "μ∞ (cp)" => convert_muinf(params[2]), # μ_inf,
        "m" => params[3], # m,
        "n" => params[4], # n
    )

    # Generate the fitted shear stress values using the GHB model
    ghb_X = range(minimum(shear_rates), stop=maximum(shear_rates), length=100)
    ghb_Y = ghb_fit_func.(ghb_X)

    # Plot the experimental data and the fitted model using plot_regression
    plot_regression(
        shear_rates, shear_stresses,
        collect(ghb_X), ghb_Y, regression_type;
        annotations=annotations, scale=scale,
        label_fit_model="GHB Model (R² = $(round(r2, digits=3)))",
        figres=figres, title="Rheology regression model",
        xlabel=L"Shear rate,\ $[{s}^{-1}]$",
        ylabel=L"Shear stress, $[\frac{lb_{f}}{100ft^2}]$"
    )
end
