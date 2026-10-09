using Test
using SimuUtils
using UomDefinitions: N_PER_LBF, M_PER_FT

@testset "unit bridge lbf·s/100ft² → cP" begin
    @test CP_PER_LBF100FT2_S ≈ N_PER_LBF / (100 * M_PER_FT^2) * 1000 rtol=1e-12
    @test CP_PER_LBF100FT2_S ≈ 478.8 atol=0.1
end

@testset "models — shear_stress, apparent_viscosity, yield_stress" begin
    γ̇ = 511.0                                              # Fann 300 rpm
    nw = Newtonian(30.0)                                   # 30 cP
    @test shear_stress(nw, γ̇) ≈ 30.0 / CP_PER_LBF100FT2_S * γ̇
    @test apparent_viscosity(nw, γ̇) ≈ 30.0
    @test yield_stress(nw) == 0.0
    bp = Bingham(10.0, 30.0)
    @test shear_stress(bp, γ̇) ≈ 10.0 + 30.0 / CP_PER_LBF100FT2_S * γ̇
    @test apparent_viscosity(bp, γ̇) ≈ 30.0 + 10.0 * CP_PER_LBF100FT2_S / γ̇
    @test yield_stress(bp) == 10.0
    pl = PowerLaw(0.5, 0.7)
    @test shear_stress(pl, γ̇) ≈ 0.5 * γ̇^0.7
    @test yield_stress(pl) == 0.0
    @test apparent_viscosity(pl, 2γ̇) < apparent_viscosity(pl, γ̇)        # shear thinning
    hb = HerschelBulkley(5.0, 0.5, 0.7)
    @test shear_stress(hb, γ̇) ≈ 5.0 + 0.5 * γ̇^0.7
    @test shear_stress(HerschelBulkley(10.0, 30.0 / CP_PER_LBF100FT2_S, 1.0), γ̇) ≈ shear_stress(bp, γ̇)   # n = 1 ⇒ Bingham
    @test shear_stress(HerschelBulkley(0.0, 0.5, 0.7), γ̇) ≈ shear_stress(pl, γ̇)                        # τ0 = 0 ⇒ Power Law
    g = GeneralizedHB(5.0, 30.0, 0.8, 0.9)
    @test g.τ_ref == 1.0
    μ∞_field = 30.0 / CP_PER_LBF100FT2_S
    @test shear_stress(g, γ̇) ≈ (5.0^0.8 + (μ∞_field * γ̇)^0.9)^(1 / 0.8)
    @test shear_stress(g, 1e-9) ≈ 5.0 atol=1e-6                         # tends to the yield stress
    @test apparent_viscosity(g, γ̇) ≈ shear_stress(g, γ̇) / γ̇ * CP_PER_LBF100FT2_S
    # vector broadcast
    @test shear_stress(bp, [511.0, 1022.0]) == [shear_stress(bp, 511.0), shear_stress(bp, 1022.0)]
    # validation
    @test_throws ArgumentError Newtonian(-1.0)
    @test_throws ArgumentError PowerLaw(0.5, 0.0)
    @test_throws ArgumentError Bingham(-1.0, 10.0)
end

@testset "bingham_equivalent — two-point Fann 300/600" begin
    bp = Bingham(10.0, 30.0)
    @test bingham_equivalent(bp).τ0 ≈ 10.0 atol=1e-9
    @test bingham_equivalent(bp).μp ≈ 30.0 atol=1e-9
    hb = HerschelBulkley(5.0, 0.5, 0.7)
    be = bingham_equivalent(hb)
    @test be isa Bingham
    τ1, τ2 = shear_stress(hb, 511.0), shear_stress(hb, 1022.0)
    @test be.μp ≈ (τ2 - τ1) / 511.0 * CP_PER_LBF100FT2_S atol=1e-9
    @test be.τ0 ≈ τ1 - be.μp / CP_PER_LBF100FT2_S * 511.0 atol=1e-9
    @test bingham_equivalent(Newtonian(20.0)).τ0 ≈ 0.0 atol=1e-9
end

@testset "fit_rheology — closed form and optimiser" begin
    γ̇ = [1022.0, 511.0, 340.7, 170.3, 102.2, 51.1, 10.2, 5.1]
    bp = Bingham(10.0, 30.0)
    m, r2 = fit_rheology(Bingham, γ̇, shear_stress(bp, γ̇))
    @test m isa Bingham
    @test m.τ0 ≈ 10.0 atol=1e-6
    @test m.μp ≈ 30.0 atol=1e-6
    @test r2 ≈ 1.0 atol=1e-9
    nw, r2n = fit_rheology(Newtonian, γ̇, shear_stress(Newtonian(25.0), γ̇))
    @test nw.μ ≈ 25.0 atol=1e-6
    @test r2n ≈ 1.0 atol=1e-9
    pl, r2p = fit_rheology(PowerLaw, γ̇, shear_stress(PowerLaw(0.5, 0.7), γ̇))
    @test pl.K ≈ 0.5 atol=1e-6
    @test pl.n ≈ 0.7 atol=1e-6
    @test r2p ≈ 1.0 atol=1e-9
    hb_true = HerschelBulkley(5.0, 0.5, 0.7)
    hb, r2h = fit_rheology(HerschelBulkley, γ̇, shear_stress(hb_true, γ̇))
    @test r2h > 0.999
    @test hb.τ0 ≈ 5.0 atol=0.5
    @test hb.n ≈ 0.7 atol=0.05
    g, r2g = fit_rheology(GeneralizedHB, γ̇, shear_stress(GeneralizedHB(5.0, 30.0, 0.8, 0.9), γ̇))
    @test g isa GeneralizedHB
    @test r2g > 0.999
    # the moved legacy entry points still work
    params, r2l = ghb_model_fit(γ̇, shear_stress(hb_true, γ̇))
    @test length(params) == 4
    @test r2l > 0.99
    @test ghb_model(γ̇, params) isa Vector
end

@testset "fit_rheology logs" begin
    γ̇ = [1022.0, 511.0, 340.7, 170.3, 102.2, 51.1, 10.2, 5.1]
    τ_good = shear_stress(Bingham(10.0, 30.0), γ̇)
    @test_logs (:info, r"rheology fit") fit_rheology(Bingham, γ̇, τ_good)
    τ_bad = [60.0, 10.0, 50.0, 5.0, 40.0, 2.0, 30.0, 1.0]        # not a rheogram
    @test_logs (:info, r"rheology fit") (:warn, r"R² below 0.95") fit_rheology(Bingham, γ̇, τ_bad)
end

@testset "Fann helpers moved intact" begin
    r = FannReadings(60, 35, 28, 19, 14, 10, 4, 3)
    rpm, dial = FannReadings(r)
    @test rpm == [600, 300, 200, 100, 60, 30, 6, 3]
    @test dial[1] == 60.0
    γ̇, τ = FannRheology(r)
    @test length(γ̇) == 8
    @test γ̇[2] ≈ 511.0 atol=1.0
    inputs = FannInputs(r)
    hb, r2 = fit_rheology(HerschelBulkley, inputs)
    @test hb isa HerschelBulkley
    @test 0.9 < r2 <= 1.0
end
