using Test
using SimuUtils

using UomDefinitions: Uom, Diameter, Length, Pressure, Density, PPCF, D64,
    inch, mm, d64, ft, m, psi, bar, l_m, ppcf, kg_m3, sg, to_kg_m3,
    Capacity, BBL_PER_FT, L_PER_M, to_bbl_ft, to_in, M_PER_IN, M3_PER_BBL, M_PER_FT,
    ZeroCapacityError, NegativeValueError, InvalidValueError, ZeroValueError

const SU = SimuUtils

# Tests for src/oilfield/casings.jl: Thread, Casing, calc_casing_weight,
# calc_casing_id and the typed calc_capacity forms (Normal / Edge / Failure).

@testset "casings.jl — exports" begin
    for n in (:Casing, :CsgWeight, :CsgWeightUnit, :PPF, :ppf, :Thread,
              :calc_casing_weight, :calc_casing_id, :STEEL_DENSITY, :calc_capacity)
        @test n in names(SimuUtils)
    end
end

@testset "Casing helpers — Normal" begin
    # 7" x 6.276" steel at 490 lb/ft³: (π/4)(7² − 6.276²)/144 ft² × 490 = 25.69 ppf
    w = SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch))
    @test w isa CsgWeight{PPF}
    @test string(w) == "$(w.value) ppf"
    # CsgWeight follows the UomDefinitions unit pattern: unit singleton, parametric quantity
    @test ppf isa PPF && PPF <: CsgWeightUnit && CsgWeightUnit <: Uom
    @test CsgWeight(23.0, ppf) isa CsgWeight{PPF}
    @test CsgWeight(23.0, ppf).value === 23.0
    @test CsgWeight(23, ppf).value === 23.0
    @test CsgWeight{PPF}(23).value === 23.0
    @test isapprox(w.value, 25.69, atol=0.05)

    # no rounding: full precision retained
    @test w.value ≈ (π / 4) * (7.0^2 - 6.276^2) / 144 * 490.0 rtol=1e-12

    # 7" × 6.366" is the familiar 23 ppf casing
    @test isapprox(
        SU.calc_casing_weight(
            Diameter(7.0, inch),
            Diameter(6.366, inch)).value,
        23.0, atol=0.5)

    # mm inputs agree with inch inputs (unit conversion is not bit-exact)
    w_mm = SU.calc_casing_weight(Diameter(7.0 * 25.4, mm), Diameter(6.276 * 25.4, mm))
    @test w_mm.value ≈ w.value rtol=1e-12

    # mixed units allowed
    @test SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276 * 25.4, mm)).value ≈ w.value rtol=1e-12

    # material is a typed Density: steel default, any density unit accepted
    @test SU.STEEL_DENSITY isa Density{PPCF} && SU.STEEL_DENSITY.value == 490.0
    @test SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=SU.STEEL_DENSITY).value == w.value
    # aluminium ≈ 169 lb/ft³ scales linearly
    @test SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=Density(169.0, ppcf)).value ≈ w.value * 169.0 / 490.0 rtol=1e-12
    # same steel given in kg/m³ and SG
    @test SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=to_kg_m3(SU.STEEL_DENSITY)).value ≈ w.value rtol=1e-12
    @test SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=Density(7.849, sg)).value ≈ w.value rtol=1e-4

    # calc_casing_id: 7" at 23.0 ppf → 6.3556 in, returned in od's unit, no rounding
    id = SU.calc_casing_id(Diameter(7.0, inch), CsgWeight(23.0, ppf))
    @test id isa Diameter{typeof(inch)}
    @test isapprox(id.value, 6.3556, atol=0.02)
    id_mm = SU.calc_casing_id(Diameter(7.0 * 25.4, mm), CsgWeight(23.0, ppf))
    @test id_mm isa Diameter{typeof(mm)}
    @test to_in(id_mm).value ≈ id.value rtol=1e-12
    # round trip: weight(od, id(od, w)) == w
    @test SU.calc_casing_weight(Diameter(7.0, inch), id).value ≈ 23.0 rtol=1e-12
    # Int inputs accepted
    @test SU.calc_casing_id(Diameter(7, inch), CsgWeight(23, ppf)) isa Diameter{typeof(inch)}
    # calc_casing_id with the material in kg/m³ agrees with the lb/ft³ default
    @test SU.calc_casing_id(Diameter(7.0, inch), CsgWeight(23.0, ppf); material=to_kg_m3(SU.STEEL_DENSITY)).value ≈ id.value rtol=1e-12
    # D64 outer diameter: result comes back in 64ths and agrees with the inch result
    id_64 = SU.calc_casing_id(Diameter(7.0 * 64, d64), CsgWeight(23.0, ppf))
    @test id_64 isa Diameter{D64}
    @test to_in(id_64).value ≈ id.value rtol=1e-12
    # CsgWeight equality is by value and unit
    @test CsgWeight(23.0, ppf) == CsgWeight(23.0, ppf)
    @test CsgWeight(23.0, ppf) != CsgWeight(23.1, ppf)
end

@testset "Casing helpers — Failure" begin
    # helper guards
    @test_throws MethodError SU.calc_casing_weight(7.0, 6.276, inch)
    @test_throws MethodError SU.calc_casing_id(7.0, 23.0, inch)
    @test_throws ZeroCapacityError SU.calc_casing_weight(Diameter(7.0, inch), Diameter(7.0, inch))
    @test_throws NegativeValueError SU.calc_casing_weight(Diameter(6.0, inch), Diameter(7.0, inch))
    @test_throws ZeroValueError SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=Density(0.0, ppcf))
    @test_throws ZeroValueError SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=Density(0.0, kg_m3))
    # material must be a Density (bare numbers rejected; typed keyword → TypeError); NaN/negative are rejected by Density itself
    @test_throws TypeError SU.calc_casing_weight(Diameter(7.0, inch), Diameter(6.276, inch); material=490.0)
    @test_throws TypeError SU.calc_casing_id(Diameter(7.0, inch), CsgWeight(23.0, ppf); material=490.0)
    # the weight must be a CsgWeight: bare numbers and densities are rejected
    @test_throws MethodError SU.calc_casing_id(Diameter(7.0, inch), 23.0)
    @test_throws MethodError SU.calc_casing_id(Diameter(7.0, inch), Density(23.0, ppcf))
    @test_throws ZeroValueError SU.calc_casing_id(Diameter(7.0, inch), CsgWeight(23.0, ppf); material=Density(0.0, ppcf))
    # weight heavier than a solid 7" bar (≈131 ppf) → no real id
    @test_throws NegativeValueError SU.calc_casing_id(Diameter(7.0, inch), CsgWeight(200.0, ppf))
    # weight exactly equal to a solid bar → id == 0 → ZeroCapacityError
    solid = SU.calc_casing_weight(Diameter(7.0, inch), Diameter(0.0, inch))
    @test_throws ZeroCapacityError SU.calc_casing_id(Diameter(7.0, inch), solid)
end

@testset "Casing constructor — Normal" begin
    od, id = Diameter(13.375, inch), Diameter(12.415, inch)
    c = Casing(od, id; hanger=Length(100.0, ft), depth=Length(1000.0, ft))
    @test c isa Casing{Float64}
    @test c.od === od && c.id === id
    @test c.od.value == 13.375 && c.id.value == 12.415
    @test c.hanger isa Length && c.hanger.value == 100.0
    @test c.depth isa Length && c.depth.value == 1000.0
    @test c.wt isa CsgWeight
    @test c.wt.value ≈ SU.calc_casing_weight(od, id).value
    # optional fields default to nothing
    @test c.thread === nothing && c.grade === nothing
    @test c.burst === nothing && c.collapse === nothing

    # mm diameters and metric depths
    cm = Casing(Diameter(244.5, mm), Diameter(222.4, mm); hanger=Length(0.0, m), depth=Length(1500.0, m))
    @test cm.od isa Diameter{typeof(mm)} && cm.od.value == 244.5
    @test cm.depth.value == 1500.0
    @test cm.wt.value > 0.0

    # full keyword set: Pressure ratings, thread, grade stored as given
    t = SU.Thread("BTC", 80.0)
    cf = Casing(Diameter(7.0, inch), Diameter(6.276, inch);
        hanger=Length(0.0, ft), depth=Length(3000.0, ft),
        thread=t, grade="N80", burst=Pressure(7240.0, psi), collapse=Pressure(386.0, bar))
    @test cf.thread === t && cf.thread.name == "BTC" && cf.thread.yield == 80.0
    @test cf.grade == "N80"
    @test cf.burst isa Pressure{typeof(psi)} && cf.burst.value == 7240.0
    @test cf.collapse isa Pressure{typeof(bar)} && cf.collapse.value == 386.0

    # no depths at all
    nd = Casing(Diameter(5.0, inch), Diameter(4.276, inch))
    @test nd.hanger === nothing && nd.depth === nothing
end

@testset "Casing constructor — Edge" begin
    od, id = Diameter(9.625, inch), Diameter(8.755, inch)
    # hanger == depth is allowed
    e = Casing(od, id; hanger=Length(1000.0, ft), depth=Length(1000.0, ft))
    @test e.hanger.value == e.depth.value
    # hanger == depth across units (1000 ft vs 304.8 m)
    @test Casing(od, id; hanger=Length(1000.0, ft), depth=Length(1000.0 * M_PER_FT, m)) isa Casing
    # zero hanger
    @test Casing(od, id; hanger=Length(0.0, ft), depth=Length(1000.0, ft)).hanger.value == 0.0
    # only one of hanger/depth given
    @test Casing(od, id; hanger=Length(0.0, ft)).depth === nothing
    @test Casing(od, id; depth=Length(10.0, m)).hanger === nothing
    # mixed diameter units: od in inch, id in mm
    mix = Casing(Diameter(9.625, inch), Diameter(8.755 * 25.4, mm))
    @test mix.wt.value ≈ e.wt.value rtol=1e-12
    # zero-pressure ratings allowed
    @test Casing(od, id; burst=Pressure(0.0, psi)).burst.value == 0.0
    # Thread with minimal valid inputs
    @test SU.Thread("x", 1e-9).yield == 1e-9
    # D64 diameters are accepted; weight equals the inch result
    c64 = Casing(Diameter(7.0 * 64, d64), Diameter(6.276 * 64, d64))
    @test c64.od isa Diameter{D64}
    @test c64.wt.value ≈ Casing(Diameter(7.0, inch), Diameter(6.276, inch)).wt.value rtol=1e-12
    # any AbstractString grade is stored as a String
    cg = Casing(od, id; grade=SubString("N80 x", 1, 3))
    @test cg.grade isa String && cg.grade == "N80"
end

@testset "Casing constructor — Failure" begin
    h, d = Length(100.0, ft), Length(1000.0, ft)
    # od == id → ZeroCapacityError, in one unit and across units
    @test_throws ZeroCapacityError Casing(Diameter(12.415, inch), Diameter(12.415, inch); hanger=h, depth=d)
    @test_throws ZeroCapacityError Casing(Diameter(8.5, inch), Diameter(215.9, mm))
    # od < id → NegativeValueError, in one unit and across units
    @test_throws NegativeValueError Casing(Diameter(12.415, inch), Diameter(13.375, inch); hanger=h, depth=d)
    @test_throws NegativeValueError Casing(Diameter(8.0, inch), Diameter(215.9, mm))
    # hanger deeper than depth → ArgumentError (structural)
    @test_throws ArgumentError Casing(Diameter(13.375, inch), Diameter(12.415, inch); hanger=Length(1100.0, ft), depth=d)
    @test_throws ArgumentError Casing(Diameter(13.375, inch), Diameter(12.415, inch); hanger=Length(400.0, m), depth=d)
    # bare numbers are not accepted (Real form removed)
    @test_throws MethodError Casing(13.375, 12.415, inch; hanger=h, depth=d)
    @test_throws MethodError Casing(13.375, 12.415)
    # legacy (value, unit) depth tuples removed (typed keyword arguments raise TypeError, not MethodError)
    @test_throws TypeError Casing(Diameter(13.375, inch), Diameter(12.415, inch); hanger=(100.0, ft), depth=(1000.0, ft))
    # ratings must be Pressure
    @test_throws TypeError Casing(Diameter(13.375, inch), Diameter(12.415, inch); burst=7240.0)
    @test_throws TypeError Casing(Diameter(13.375, inch), Diameter(12.415, inch); collapse=386.0)
    # negative ratings rejected (Pressure itself allows negatives)
    @test_throws NegativeValueError Casing(Diameter(13.375, inch), Diameter(12.415, inch); burst=Pressure(-1.0, psi))
    @test_throws NegativeValueError Casing(Diameter(13.375, inch), Diameter(12.415, inch); collapse=Pressure(-1.0, psi))
    # positional inner constructor is the only `new` site and validates too
    @test_throws ZeroCapacityError Casing{Float64}(Diameter(7.0, inch), Diameter(7.0, inch), CsgWeight(1.0, ppf),
        nothing, nothing, nothing, nothing, nothing, nothing)
    # an invalid weight cannot be built at all (CsgWeight inner constructor); the old tuple form is gone
    @test_throws MethodError Casing{Float64}(Diameter(7.0, inch), Diameter(6.276, inch), (1.0, :ppf),
        nothing, nothing, nothing, nothing, nothing, nothing)

    # CsgWeight validation (lb/ft, finite and > 0); the enum is gone
    @test_throws ZeroValueError CsgWeight(0.0, ppf)
    @test_throws NegativeValueError CsgWeight(-23.0, ppf)
    @test_throws InvalidValueError CsgWeight(NaN, ppf)
    @test_throws InvalidValueError CsgWeight(Inf, ppf)
    @test_throws MethodError CsgWeight(23.0)               # unit is required (no default)
    @test_throws MethodError CsgWeight(23.0, inch)         # not a casing-weight unit
    @test_throws ZeroValueError CsgWeight{PPF}(0.0)        # inner constructor validates too

    # Thread validation
    @test_throws ArgumentError SU.Thread("", 80.0)
    @test_throws ZeroValueError SU.Thread("BTC", 0.0)
    @test_throws NegativeValueError SU.Thread("BTC", -1.0)
    @test_throws InvalidValueError SU.Thread("BTC", NaN)

end

@testset "calc_capacity — typed forms" begin
    outer = Casing(Diameter(9.625, inch), Diameter(8.755, inch); hanger=Length(0.0, ft), depth=Length(1500.0, ft))
    inner = Casing(Diameter(5.5, inch),   Diameter(4.892, inch); hanger=Length(0.0, ft), depth=Length(3000.0, ft))
    # bbl/ft from in²: (π/4) d² in² → m² (× M_PER_IN²) → m³/m → × M_PER_FT / M3_PER_BBL → bbl/ft
    in2_to_bblft = M_PER_IN^2 * M_PER_FT / M3_PER_BBL
    typ = calc_capacity(outer, inner)                  # bbl/ft default
    @test typ.annular isa Capacity{BBL_PER_FT}
    @test typ.annular.value  ≈ (π/4) * (8.755^2 - 5.5^2) * in2_to_bblft rtol=1e-9
    @test typ.internal.value ≈ (π/4) * 4.892^2 * in2_to_bblft rtol=1e-9
    @test typ.displace.value ≈ (π/4) * (5.5^2 - 4.892^2) * in2_to_bblft rtol=1e-9
    # single casing, metric output
    one = calc_capacity(inner; out=l_m)
    @test one.internal isa Capacity{L_PER_M}
    @test to_bbl_ft(one.internal).value ≈ typ.internal.value atol=1e-12
    @test one.external.value ≈ one.internal.value + one.displace.value atol=1e-9
    # legacy factor forms are gone
    @test_throws MethodError calc_capacity(outer, inner, 1/808.5)
    @test_throws MethodError calc_capacity(inner, 1.0)
end
