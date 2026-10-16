using Test
using SimuUtils
using UomDefinitions: Density, sg, ppg, kg_m3, to_ppg
using UomDefinitions: InvalidValueError, NegativeValueError

@testset "Fluid — Normal" begin
    # every FluidType constructs with a typed Density
    for kind in instances(FluidType)
        f = Fluid(kind, string(kind), Density(10.0, ppg))
        @test f.fluid == kind
        @test f.density isa Density
    end
    fluids = Set([Mud, Spacer, Cement, Brine, OBM, WBM, FreshWater, SeaWater])
    @test Set(instances(FluidType)) ⊇ fluids

    # default rheology is Bingham(0, 1) — water
    w = Fluid(FreshWater, "Fresh water", 8.33, ppg)
    @test w.rheo isa Bingham
    @test w.rheo == Bingham(0.0, 1.0)
    @test yp(w) == 0.0
    @test pv(w) == 1.0

    # Real + unit keyword form converts to a Density
    c = Fluid(Cement, "Class G 1.90 sg", 1.90, sg; yp=12.0, pv=45.0)
    @test c.density isa Density
    @test to_ppg(c.density).value ≈ 15.86 atol=0.01
    @test yp(c) == 12.0
    @test pv(c) == 45.0

    # Density keyword form
    m = Fluid(OBM, "OBM", Density(1.20, sg); yp=8.0, pv=20.0)
    @test m.fluid == OBM
    @test m.name == "OBM"
    @test pv(m) == 20.0

    # any RheoModel: Herschel-Bulkley and Newtonian accessors
    h = Fluid(Spacer, "HB spacer", 12.0, ppg, HerschelBulkley(5.0, 0.5, 0.7))
    @test h.rheo isa HerschelBulkley
    @test pv(h) ≈ bingham_equivalent(h.rheo).μp
    @test yp(h) ≈ bingham_equivalent(h.rheo).τ0
    n = Fluid(FreshWater, "water", Density(1000.0, kg_m3), Newtonian(1.0))
    @test yp(n) ≈ 0.0 atol=1e-9
    @test pv(n) ≈ 1.0 atol=1e-9
end

@testset "Fluid — Edge" begin
    # zero density is a valid Density (gas-free reference), accepted by Fluid
    z = Fluid(Brine, "zero", Density(0.0, ppg))
    @test z.density.value == 0.0

    # long name is stored verbatim
    long = repeat("x", 300)
    f = Fluid(Mud, long, Density(10.0, ppg))
    @test f.name == long
    @test length(f.name) == 300

    # AbstractString names are stored as String
    s = Fluid(Mud, SubString("OBM 10 ppg", 1, 3), Density(10.0, ppg))
    @test s.name == "OBM"
    @test s.name isa String
end

@testset "Fluid — Failure" begin
    # density validity is enforced upstream by UomDefinitions
    @test_throws InvalidValueError Fluid(Mud, "nan", NaN, ppg)
    @test_throws NegativeValueError Fluid(Mud, "neg", -1.0, ppg)
    @test_throws InvalidValueError Fluid(Mud, "inf", Density(Inf, ppg))

    # structural: empty name
    @test_throws ArgumentError Fluid(Mud, "", Density(10.0, ppg))
    @test_throws ArgumentError Fluid(Mud, "", 10.0, ppg; yp=1.0, pv=2.0)
    @test_throws ArgumentError Fluid(Mud, "", 10.0, ppg, Newtonian(1.0))

    # wrong types: no matching method
    @test_throws MethodError Fluid(Mud, "m", 10.0, "ppg")
    @test_throws MethodError Fluid(Mud, "m", 10.0)
    @test_throws MethodError Fluid(Mud, "m", Density(10.0, ppg), 30.0)
    @test_throws MethodError Fluid("Mud", "m", Density(10.0, ppg))
end
