using Test
using SimuUtils
using UomDefinitions: Density, sg, ppg, to_ppg

@testset "Fluid — types, rheology model, keyword Bingham defaults" begin
    @test Set(instances(FluidType)) ⊇ Set([Mud, Spacer, Cement, Brine, OBM, WBM, FreshWater, SeaWater])
    w = Fluid(FreshWater, "Fresh water", 8.33, ppg)
    @test w.density isa Density
    @test w.rheo isa Bingham
    @test yp(w) == 0.0
    @test pv(w) == 1.0
    c = Fluid(Cement, "Class G 1.90 sg", 1.90, sg; yp=12.0, pv=45.0)
    @test to_ppg(c.density).value ≈ 15.86 atol=0.01
    @test yp(c) == 12.0
    @test pv(c) == 45.0
    m = Fluid(OBM, "OBM", Density(1.20, sg); yp=8.0, pv=20.0)
    @test m.fluid == OBM
    @test pv(m) == 20.0
    # any RheoModel
    h = Fluid(Spacer, "HB spacer", 12.0, ppg, HerschelBulkley(5.0, 0.5, 0.7))
    @test h.rheo isa HerschelBulkley
    @test pv(h) ≈ bingham_equivalent(h.rheo).μp
    @test yp(h) ≈ bingham_equivalent(h.rheo).τ0
    n = Fluid(FreshWater, "water", 8.33, ppg, Newtonian(1.0))
    @test yp(n) ≈ 0.0 atol=1e-9
    @test pv(n) ≈ 1.0 atol=1e-9
end
