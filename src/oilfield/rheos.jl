# ==============================================================================
#   Rheology models (RheoModel), fitting, and Fann-35 helpers
# ==============================================================================
# One convention everywhere:
#   τ   shear stress        [lbf/100 ft²]
#   γ̇   shear rate          [1/s]
#   μ   viscosities         [cP]   (1 lbf·s/100 ft² = CP_PER_LBF100FT2_S cP)
# The Fann-35 acquisition helpers and the GHB fit below were moved verbatim
# from SimuHydraulics/src/functions/rheos.jl; SimuHydraulics re-exports them.

using BlackBoxOptim
using UomDefinitions: N_PER_LBF, M_PER_FT

"centipoise per (lbf·s / 100 ft²) — derived: N_PER_LBF / (100 · M_PER_FT²) Pa·s × 1000"
const CP_PER_LBF100FT2_S = N_PER_LBF / (100 * M_PER_FT^2) * 1000

# ---- models -------------------------------------------------------------------
"""
    RheoModel

Constitutive model τ(γ̇). Concrete: [`Newtonian`](@ref), [`PowerLaw`](@ref),
[`Bingham`](@ref), [`HerschelBulkley`](@ref), [`GeneralizedHB`](@ref).
"""
abstract type RheoModel end

"τ = μ·γ̇ — `μ` [cP]"
struct Newtonian <: RheoModel
    μ::Float64
    Newtonian(μ::Real) = μ < 0 ? throw(ArgumentError("μ must be ≥ 0")) : new(float(μ))
end

"τ = K·γ̇ⁿ — `K` [lbf·sⁿ/100 ft²], `n` > 0"
struct PowerLaw <: RheoModel
    K::Float64
    n::Float64
    PowerLaw(K::Real, n::Real) = (K < 0 || n <= 0) ? throw(ArgumentError("K ≥ 0 and n > 0 required")) : new(float(K), float(n))
end

"τ = τ0 + μp·γ̇ — `τ0` [lbf/100 ft²], `μp` [cP]"
struct Bingham <: RheoModel
    τ0::Float64
    μp::Float64
    Bingham(τ0::Real, μp::Real) = (τ0 < 0 || μp < 0) ? throw(ArgumentError("τ0 ≥ 0 and μp ≥ 0 required")) : new(float(τ0), float(μp))
end

"τ = τ0 + K·γ̇ⁿ — `τ0` [lbf/100 ft²], `K` [lbf·sⁿ/100 ft²], `n` > 0"
struct HerschelBulkley <: RheoModel
    τ0::Float64
    K::Float64
    n::Float64
    HerschelBulkley(τ0::Real, K::Real, n::Real) =
        (τ0 < 0 || K < 0 || n <= 0) ? throw(ArgumentError("τ0 ≥ 0, K ≥ 0, n > 0 required")) : new(float(τ0), float(K), float(n))
end

"""
    GeneralizedHB(τ0, μ∞, m, n; τ_ref=1.0)

(τ/τ_ref)ᵐ = (τ0/τ_ref)ᵐ + (μ∞·γ̇/τ_ref)ⁿ — `τ0` and `τ_ref` [lbf/100 ft²]
(τ_ref is a **stress**, default 1 lbf/100 ft²), `μ∞` [cP], `m`, `n` > 0.
"""
struct GeneralizedHB <: RheoModel
    τ0::Float64
    μ∞::Float64
    m::Float64
    n::Float64
    τ_ref::Float64
    GeneralizedHB(τ0::Real, μ∞::Real, m::Real, n::Real; τ_ref::Real=1.0) =
        (τ0 < 0 || μ∞ <= 0 || m <= 0 || n <= 0 || τ_ref <= 0) ?
            throw(ArgumentError("τ0 ≥ 0, μ∞ > 0, m > 0, n > 0, τ_ref > 0 required")) :
            new(float(τ0), float(μ∞), float(m), float(n), float(τ_ref))
end

_field(μ_cp) = μ_cp / CP_PER_LBF100FT2_S          # cP → lbf·s/100 ft²

"Shear stress [lbf/100 ft²] at shear rate `γ̇` [1/s]."
shear_stress(m::Newtonian, γ̇::Real)       = _field(m.μ) * γ̇
shear_stress(m::PowerLaw, γ̇::Real)        = m.K * γ̇^m.n
shear_stress(m::Bingham, γ̇::Real)         = m.τ0 + _field(m.μp) * γ̇
shear_stress(m::HerschelBulkley, γ̇::Real) = m.τ0 + m.K * γ̇^m.n
function shear_stress(m::GeneralizedHB, γ̇::Real)
    base = max((m.τ0 / m.τ_ref)^m.m + (_field(m.μ∞) * γ̇ / m.τ_ref)^m.n, 1e-300)
    return m.τ_ref * base^(1 / m.m)
end
shear_stress(m::RheoModel, γ̇::AbstractVector) = [shear_stress(m, g) for g in γ̇]

"Apparent viscosity τ/γ̇ [cP] at `γ̇` [1/s]."
apparent_viscosity(m::RheoModel, γ̇::Real) = shear_stress(m, γ̇) / γ̇ * CP_PER_LBF100FT2_S

"Yield stress [lbf/100 ft²] (zero for models without one)."
yield_stress(::Newtonian) = 0.0
yield_stress(::PowerLaw)  = 0.0
yield_stress(m::Bingham)  = m.τ0
yield_stress(m::HerschelBulkley) = m.τ0
yield_stress(m::GeneralizedHB)   = m.τ0

"""
    bingham_equivalent(m; γ̇₁=511.0, γ̇₂=1022.0) -> Bingham

Two-point Bingham fit through the model at the Fann 300 / 600 rpm shear
rates, for legacy correlations that need `yp` / `pv`.
"""
function bingham_equivalent(m::RheoModel; γ̇₁::Real=511.0, γ̇₂::Real=1022.0)
    τ1, τ2 = shear_stress(m, γ̇₁), shear_stress(m, γ̇₂)
    μp_field = (τ2 - τ1) / (γ̇₂ - γ̇₁)
    τ0 = max(τ1 - μp_field * γ̇₁, 0.0)
    return Bingham(τ0, max(μp_field, 0.0) * CP_PER_LBF100FT2_S)
end
bingham_equivalent(m::Bingham; kw...) = m

# ---- fitting ------------------------------------------------------------------
# One @info per fit; @warn when the rheogram is poorly represented.
function _report_fit(m::RheoModel, r2::Real)
    @info "rheology fit" model=nameof(typeof(m)) params=m r2=round(r2; digits=4)
    r2 < 0.95 && @warn "rheology fit R² below 0.95 — check readings or model choice" model=nameof(typeof(m)) r2=r2
    return m, r2
end

"""
    fit_rheology(Model, γ̇, τ) -> (model, r2)

Fit a rheogram. Newtonian, Bingham and Power Law are closed-form least
squares; Herschel–Bulkley and Generalized HB use BlackBoxOptim.
"""
function fit_rheology(::Type{Newtonian}, γ̇::AbstractVector, τ::AbstractVector)
    μf = sum(γ̇ .* τ) / sum(γ̇ .^ 2)                       # through the origin
    m = Newtonian(μf * CP_PER_LBF100FT2_S)
    return _report_fit(m, calculate_r_squared(τ, shear_stress(m, γ̇)))
end
function fit_rheology(::Type{Bingham}, γ̇::AbstractVector, τ::AbstractVector)
    slope, intercept = linear_regression(collect(γ̇), collect(τ))
    m = Bingham(max(intercept, 0.0), max(slope, 0.0) * CP_PER_LBF100FT2_S)
    return _report_fit(m, calculate_r_squared(τ, shear_stress(m, γ̇)))
end
function fit_rheology(::Type{PowerLaw}, γ̇::AbstractVector, τ::AbstractVector)
    slope, intercept = linear_regression(log.(collect(γ̇)), log.(collect(τ)))
    m = PowerLaw(exp(intercept), slope)
    return _report_fit(m, calculate_r_squared(τ, shear_stress(m, γ̇)))
end
function fit_rheology(::Type{HerschelBulkley}, γ̇::AbstractVector, τ::AbstractVector)
    loss(p) = sum(abs2, shear_stress(HerschelBulkley(p[1], p[2], p[3]), γ̇) .- τ)
    res = bboptimize(loss; SearchRange=[(0.0, maximum(τ)), (1e-6, maximum(τ)), (0.05, 1.5)],
                     Method=:adaptive_de_rand_1_bin_radiuslimited, MaxSteps=50_000, TraceMode=:silent)
    p = best_candidate(res)
    m = HerschelBulkley(p[1], p[2], p[3])
    return _report_fit(m, calculate_r_squared(τ, shear_stress(m, γ̇)))
end
function fit_rheology(::Type{GeneralizedHB}, γ̇::AbstractVector, τ::AbstractVector)
    params, r2 = ghb_model_fit(γ̇, τ)                      # legacy fit, μ∞ in lbf·s/100 ft²
    m = GeneralizedHB(params[1], params[2] * CP_PER_LBF100FT2_S, params[3], params[4])
    return _report_fit(m, r2)
end
# ---- Fann-35 helpers and legacy GHB (moved verbatim from SimuHydraulics) -----
# Define enums for Bob, Rotor, and Spring configurations
@enum Rotor R1 R2 R3
@enum Bob B1 B2 B3 B4
@enum Spring F0_2 F0_5 F1 F2 F3 F4 F5 F10

const FloatNothing = Union{Missing,Nothing,Float64}
const NumberNothing = Union{Missing,Nothing,Number}

# Define the FannReadings struct
struct FannReadings{T<:FloatNothing}
    r600::T
    r300::T
    r200::T
    r100::T
    r60::T
    r30::T
    r6::T
    r3::T

    # Inner constructor for FannReadings
    function FannReadings(
        r600::NumberNothing, r300::NumberNothing,
        r200::NumberNothing, r100::NumberNothing,
        r60::NumberNothing, r30::NumberNothing,
        r6::NumberNothing, r3::NumberNothing
    ) # Return a new instance of FannReadings
        new{FloatNothing}(r600, r300, r200, r100, r60, r30, r6, r3)
    end
end

# Function to return RPM values paired with readings
function FannReadings(readings::FannReadings)
    rpm_values = Int[600, 300, 200, 100, 60, 30, 6, 3]
    dial_readings = FloatNothing[
        readings.r600, readings.r300,
        readings.r200, readings.r100,
        readings.r60, readings.r30,
        readings.r6, readings.r3
    ]

    # Filter out the readings that are nothing
    filtered_rpm = Int[]
    filtered_readings = Float64[]
    for (rpm, read) in zip(rpm_values, dial_readings)
        if (read !== nothing) && (read > 0.0)
            push!(filtered_rpm, rpm)
            push!(filtered_readings, read)
        end
    end

    return filtered_rpm, filtered_readings
end

"""
	FannRheology(
		readings::FannReadings;
		k1::Float64=0.0, k2::Float64=0.0,
		rotor::Rotor=R1, bob::Bob=B1, spring::Spring=F1
	)

	Returns the shear rates and shear stresses calculated from the Fann readings.
	If `k1` and `k2` are provided, the calculation will be based on these values,
	otherwise, the calculation will be based on the rotor-bob configuration.

# Arguments
- `readings::FannReadings`: The Fann readings.
- `k1::Float64`: The spring constant (k₁) for the spring configuration, Affects the shear rates.
- `k2::Float64`: The geometry factor (k₂) for the rotor-bob configuration. Affected the shear stress.
- `rotor::Rotor`: The rotor configuration.
- `bob::Bob`: The bob configuration.
- `spring::Spring`: The spring configuration.

# Returns
- Tuple `(shear_rates, shear_stresses)`: The calculated shear rates and shear stresses.
"""
function FannRheology(
    readings::FannReadings;
    k1::Float64=0.0, k2::Float64=0.0,
    rotor::Rotor=R1, bob::Bob=B1, spring::Spring=F1
)
    # Extract RPM values and readings
    rpms, dials = FannReadings(readings)

    # initialize shear rates and shear stresses
    shear_rates = Float64[]
    shear_stresses = Float64[]

    # Calculate shear rates and shear stresses
    if k1 > 0 && k2 > 0
        # use default values
        for (rpm, dial) in zip(rpms, dials)
            push!(shear_rates, rpm * k1)
            push!(shear_stresses, dial * k2)
        end
    else
        # use rotor-bob configuration
        shear_rates = [calc_shear_rate(rpm, rotor, bob) for rpm in rpms]
        shear_stresses = [
            calc_shear_stress(dial, rotor, bob, spring)
            for dial in dials
        ]
    end

    return shear_rates, shear_stresses
end

struct FannInputs
    readings::FannReadings
    rotor::Rotor
    bob::Bob
    spring::Spring
    k1::Union{Float64,Nothing}
    k2::Union{Float64,Nothing}

    # Inner constructor for FannInputs
    function FannInputs(
        readings::FannReadings, ;
        rotor::Rotor=R1, bob::Bob=B1, spring::Spring=F1,
        k1::Union{Float64,Nothing}=nothing, k2::Union{Float64,Nothing}=nothing
    )
        # Return a new instance of FannInputs
        new(readings, rotor, bob, spring, k1, k2)
    end
end


# Shear rate constant (k3) for R-B combinations, sec⁻¹ per RPM
# spring affects shear-stress, not shear-rate
const RB_K3 = Dict{Tuple{Rotor,Bob},Float64}(
    (R1, B1) => 1.7023, # standard API configuration
    (R1, B2) => 0.377,
    (R1, B3) => 0.268,
    (R1, B4) => 0.268,
    (R2, B1) => 5.4225,
    (R3, B1) => 0.377,
)

"""
 	calc_shear_rate(rpm::Int, rotor::Rotor, bob::Bob)

Calculate the shear rate given the RPM and the rotor-bob combination.
The shear rate is calculated using the formula:

		k3 * rpm

where k3 is the shear rate constant for the given rotor-bob combination.

# Arguments
- `rpm::Int`: The RPM of the rheometer.
- `rotor::Rotor`: The rotor configuration.
- `bob::Bob`: The bob configuration.

# Returns
- `Float64`: The calculated shear rate. γ [=] sec⁻¹.
"""
function calc_shear_rate(rpm::Int, rotor::Rotor, bob::Bob)
    # Get the shear rate constant for the given rotor-bob combination
    key = (r, b) = (rotor, bob)
    k3 = get(RB_K3, (r, b), nothing)

    # Throw an error if the combination is not found
    if isnothing(k3)
        error("Invalid rotor-bob combination: ($(r), $(b)) not found.")
    end

    return k3 * rpm
end

# Shear stress geometry factor (k₂) = [cm-3] for R-B combinations
const RB_K2 = Dict{Tuple{Rotor,Bob},Float64}(
    (R1, B1) => 0.01323,
    (R2, B1) => 0.01323,
    (R3, B1) => 0.01323,
    (R1, B2) => 0.0261,
    (R1, B3) => 0.0529,
    (R1, B4) => 0.106
)

# Spring constant (k₁) for different spring configurations
# [dyne/cm/degree_deflection]
const SPRING_K1 = Dict{Spring,Float64}(
    F0_2 => 77.2,
    F0_5 => 193.0,
    F1 => 386.0,
    F2 => 772.0,
    F3 => 1158.0,
    F4 => 1544.0,
    F5 => 1930.0,
    F10 => 3860.0,
)

const DIAL_DEFLECTION = Dict{Tuple{Spring,Int},Float64}(
    (F0_2, 10) => 127.0,
    (F0_2, 20) => 254.0,
    (F0_5, 10) => 50.8,
    (F0_5, 20) => 101.6,
    (F0_5, 50) => 254.0,
    (F1, 10) => 25.4,
    (F1, 20) => 50.8,
    (F1, 50) => 127.0,
    (F1, 100) => 254.0,
    (F2, 20) => 25.4,
    (F2, 50) => 63.5,
    (F2, 100) => 127.0,
    (F2, 200) => 254.0,
    (F3, 50) => 43,
    (F3, 100) => 84.7,
    (F3, 200) => 169.4,
    (F4, 100) => 63.5,
    (F4, 200) => 127.0,
    (F5, 100) => 50.8,
    (F5, 200) => 101.6,
    (F10, 200) => 50.8,
)

"""
	calc_spring_constant(spring::Spring, G::Float64=50.0)

Calculate the spring constant for the given spring configuration. Given the
dial deflection and the radius arm, the spring constant is calculated using
the formula:

		(G * r * g) / θ

where:
- G is the Calibration weight in grams
- r is the radius arm in cm.
- g is the gravitational acceleration in cm/s².

# Arguments
- `spring::Spring`: The spring configuration.
- `G::Float64`: The Calibration weight in grams

# Returns
- `Float64`: The calculated spring constant. k₁ [=] dyne/cm/degree.
"""
function calc_spring_constant(spring::Spring, G::Float64=50.0)
    # gravitational acceleration, cm/s²
    g = 981.0
    # Retrieve dial deflection and radius arm from DIAL_DEFLECTION dictionary
    θ = get(DIAL_DEFLECTION, (spring, G), nothing)
    isnothing(θ) && error("Spring calibration data not defined for spring: $spring")

    Ks = (G * 1 * g) / θ

    return Ks
end

"""
	 calc_shear_stress(θ::Real, rotor::Rotor, bob::Bob, spring::Spring)

Calculate shear stress from dial reading and R-B-F configuration. The shear stress
is calculated using the formula:

		k1 * k2 * θ

where:
- k1 is the spring constant for the given spring configuration.
- k2 is the geometry factor for the given rotor-bob combination.
- θ is the dial reading in degrees.

# Arguments
- `θ::Real`: The dial reading in degrees.
- `rotor::Rotor`: The rotor configuration.
- `bob::Bob`: The bob configuration.
- `spring::Spring`: The spring configuration.

# Returns
- `Float64`: The calculated shear stress. τ [=] lb/100ft².
"""
function calc_shear_stress(θ::Real, rotor::Rotor, bob::Bob, spring::Spring)
    k1 = get(SPRING_K1, spring, nothing) # spring-only property
    k2 = get(RB_K2, (rotor, bob), nothing) # geometry-only property

    if isnothing(k1)
        error("Spring constant (k1) not defined for spring: $spring")
    elseif isnothing(k2)
        error("Rotor-Bob constant (k2) not defined for combination: ($rotor, $bob)")
    end

    # Shear stress calculation in dynes/cm²
    τ_dynescm2 = k1 * k2 * θ

    # The exact conversion factor is 1.065 lb/100ft² = 5.1059 dynes/cm²
    τ_lb100ft2 = τ_dynescm2 / (444822.16 / (30.48^2 * 100))
    # Using API std conversion, only valid for R1-B1 configuration
    # τ_lb100ft2 = 1.065 * θ

    return τ_lb100ft2
end

# --------------------------------------------------------------------
#
# 		Helper function to calculate GHB model parameters
#
# --------------------------------------------------------------------


"""
	ghb_model(γ̇, params)

# Arguments
- `γ̇`: 		Array of shear rates.
- `params`: 	Vector of parameters [τ₀, μ_inf, m, n].

# Returns
- Array of predicted shear stresses.
"""
function ghb_model(γ̇, params)
    τ₀, μ_inf, m, n = params
    τ_ref = 1.0

    # safeguard calculation: ensure argument of exponentiation always positive
    base = @. max((τ₀ / τ_ref)^m + ((μ_inf .* γ̇) / τ_ref)^n, 1e-12)

    return τ_ref .* base .^ (1 / m)
end

"""
	ghb_model_fit(γ̇_exp::Vector{Float64}, τ_exp::Vector{Float64})

	This function fits the GHB model to the experimental data points
	(γ̇_exp, τ_exp) using nonlinear least squares fitting.

# Arguments
- `γ̇_exp`: The experimental shear rate data points (s-1).
- `τ_exp`: The experimental shear stress data points (lb/ft2 or consistent units).

# Returns
- Tuple `(τ₀, μ_inf, m, n)`: The fitted GHB model parameters.
"""
function ghb_model_fit(γ̇_exp, τ_exp)
    # Loss function explicitly defined
    loss(params) = sum(abs2, ghb_model(γ̇_exp, params) .- τ_exp)
    res = bboptimize(
        loss;
        SearchRange=[
            (0.00, 500.0), # τ₀,
            (0.01, 500.0), # μ_inf,
            (0.01, 1.0), # m,
            (0.01, 1.0) # n
        ],
        Method=:adaptive_de_rand_1_bin_radiuslimited,
        MaxSteps=100_000
    )
    params_fit = best_candidate(res)

    # Compute fitted shear stress explicitly and calculate R² clearly
    τ_fit = ghb_model(γ̇_exp, params_fit)
    r_squared = calculate_r_squared(τ_exp, τ_fit)

    return params_fit, r_squared
end

"""
	ghb_model_fit(inputs::FannInputs)

	This function fits the GHB model using the experimental readings.
	It calculates the shear rates and shear stresses from the readings
	and fits the GHB model to the data points.

# Arguments
- `inputs::FannInputs`: The experimental readings and rheometer configuration.

# Returns
- Tuple `(τ₀, μ_inf, m, n)`: The fitted GHB model parameters.
"""
function ghb_model_fit(inputs::FannInputs)
    # Calculate shear rates and shear stresses
    shear_rates, shear_stresses = FannRheology(
        inputs.readings; k1=inputs.k1, k2=inputs.k2,
        rotor=inputs.rotor, bob=inputs.bob, spring=inputs.spring
    )

    return ghb_model_fit(shear_rates, shear_stresses)
end


# --------------------------------------------------------------------
#
# 		Plotting functions
#
# --------------------------------------------------------------------

"""
		convert_muinf(mu_inf::Float64)

		This function converts the viscosity value from (lbf / 100ft2)*(sec) to
		centipoise (cP). The conversion factor is 1 cp = 1 mPa-s.
"""
function convert_muinf(mu_inf::Float64)
    factor = 1 * (1 / (100 * 0.3048^2)) * 4.44822 # this returns 1 N-s/m² = 1 Pa-s
    return mu_inf * factor * 1000 # 1 Pa-s = 1000 cP
end

# ---- fit from Fann inputs (needs FannInputs / FannRheology defined above) -----
"""
    fit_rheology(Model, inputs::FannInputs) -> (model, r2)

Fit any model to the rheogram computed from Fann-35 readings.
"""
fit_rheology(::Type{M}, inputs::FannInputs) where {M<:RheoModel} =
    fit_rheology(M, FannRheology(inputs.readings; rotor=inputs.rotor, bob=inputs.bob, spring=inputs.spring,
                                 k1=something(inputs.k1, 0.0), k2=something(inputs.k2, 0.0))...)
