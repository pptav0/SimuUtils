using Test
using SimuUtils
using UomDefinitions: inch, mm, ft, m, bbl, m3, ltr,
    Diameter, IN, MM, d64, M_PER_IN, Length,
    Capacity, Volume, BBL_PER_FT, GAL_PER_FT, M3_PER_M, L_PER_M, BBL, M3, L,
    bbl_ft, gal_ft, m3_m, l_m, to_bbl_ft, to_l_m, to_m3_m, GAL_PER_BBL, L_PER_M3, M_PER_FT,
    InvalidValueError, NegativeValueError

# Reference geometry used throughout: 8.5" open hole around 5.0" casing.
#   annulus  π/4 (8.5² − 5²) / 144 ft² = 0.257709 ft² = 0.045896 bbl/ft
#   circle   π/4 · 8.5²      / 144 ft² = 0.394063 ft² = 0.070185 bbl/ft
area_m2(od_in, id_in=0.0) = (π / 4) * (od_in^2 - id_in^2) * M_PER_IN^2
D(v) = Diameter(v, inch)                  # typed inch diameter
const OD, ID = D(8.5), D(5.0)

#===============================================================================#
# Normal cases — typical oilfield geometry, every entry point, every unit       #
#===============================================================================#

@testset "annulus_capacity — typed core: Diameter inputs, mixed units allowed" begin
    od, id = OD, ID
    ref = annulus_capacity(od, id)
    @test ref isa Capacity{BBL_PER_FT}
    @test ref.value ≈ 0.045896 atol=1e-5

    # the two diameters may carry different units
    @test annulus_capacity(od, Diameter(127.0, mm)).value ≈ ref.value atol=1e-16
    @test annulus_capacity(Diameter(215.9, mm), id).value ≈ ref.value atol=1e-16
    @test annulus_capacity(Diameter(215.9, mm), Diameter(127.0, mm)).value  ≈ ref.value atol=1e-16
    @test annulus_capacity(Diameter(544, d64), Diameter(320, d64)).value    ≈ ref.value atol=1e-16

    # output unit and washout
    @test annulus_capacity(od, id; out=m3_m).value ≈ area_m2(8.5, 5.0) atol=1e-16
    @test annulus_capacity(od, id; xs=0.10).value ≈ ref.value * 1.10

    # single Diameter: full circle in that diameter's unit
    @test annulus_capacity(od).value ≈ circle_capacity(D(8.5)).value
    @test annulus_capacity(Diameter(215.9, mm)).value ≈ circle_capacity(D(8.5)).value atol=1e-9
    @test annulus_capacity(Diameter(8.5, inch); xs=0.5).value ≈ circle_capacity(D(8.5)).value * 1.5

    # there is no `unit` keyword: the unit travels with each Diameter
    @test_throws MethodError annulus_capacity(od, id; unit=inch)
end

@testset "annulus_capacity — OD/ID ratio sweep against π/4·(OD²−ID²) in m²" begin
    ds = ((12.0, 8.0), (20.0, 5.0), (16.0, 2.0), (9.625, 8.755), (13.375, 9.625))
    for (od, id) in ds
        @test annulus_capacity(D(od), D(id); out=m3_m).value ≈ area_m2(od, id) atol=1e-15
    end
end

@testset "annulus_capacity — every output unit agrees" begin
    ref = annulus_capacity(OD, ID)                                    # bbl/ft
    g   = annulus_capacity(OD, ID; out=gal_ft)
    c   = annulus_capacity(OD, ID; out=m3_m)
    l   = annulus_capacity(OD, ID; out=l_m)
    @test g isa Capacity{GAL_PER_FT} && g.value ≈ ref.value * GAL_PER_BBL
    @test c isa Capacity{M3_PER_M}
    @test c.value ≈ 0.257709 * M_PER_FT^2 atol=1e-6
    @test l isa Capacity{L_PER_M}    && l.value ≈ c.value * L_PER_M3
    @test to_bbl_ft(g).value ≈ ref.value atol=1e-12
    @test to_bbl_ft(c).value ≈ ref.value atol=1e-12
    @test to_bbl_ft(l).value ≈ ref.value atol=1e-12
    # round trip through a metric unit and back
    @test to_bbl_ft(to_l_m(ref)).value ≈ ref.value atol=1e-12
end

@testset "circle_capacity — open hole / pipe bore" begin
    c = circle_capacity(D(8.5))
    @test c isa Capacity{BBL_PER_FT}
    @test c.value ≈ 0.070185 atol=1e-5
    @test c.value ≈ annulus_capacity(OD, ID).value + circle_capacity(D(5.0)).value atol=1e-12
    @test circle_capacity(Diameter(215.9, mm)).value ≈ c.value atol=1e-9
    @test circle_capacity(D(8.5); out=l_m).value ≈ to_l_m(c).value atol=1e-9
    @test circle_capacity(D(8.5); out=m3_m).value ≈ area_m2(8.5) atol=1e-15
end

@testset "oilfield wrappers — hole, pipe bore, steel wall (Diameter inputs)" begin
    pod, pid = D(5.5), D(4.892)                                           # 5.5" 17# casing
    @test hole_capacity(OD).value ≈ circle_capacity(D(8.5)).value
    @test hole_capacity(OD; xs=0.10).value ≈ circle_capacity(D(8.5)).value * 1.10
    @test pipe_capacity(pid).value ≈ circle_capacity(D(4.892)).value
    @test pipe_displacement(pod, pid).value ≈ annulus_capacity(pod, pid).value
    # steel + bore == full OD circle
    @test pipe_displacement(pod, pid).value + pipe_capacity(pid).value ≈ circle_capacity(D(5.5)).value atol=1e-12
    # each Diameter carries its own unit; wrappers honour `out` like the core
    @test pipe_capacity(Diameter(4.892 * 25.4, mm); out=l_m).value ≈ to_l_m(pipe_capacity(pid)).value atol=1e-9
    @test pipe_displacement(Diameter(5.5 * 25.4, mm), pid; out=m3_m).value ≈ area_m2(5.5, 4.892) atol=1e-12
    @test hole_capacity(Diameter(215.9, mm)).value ≈ hole_capacity(OD).value atol=1e-9
    @test hole_capacity(OD; out=gal_ft) isa Capacity{GAL_PER_FT}
end

@testset "washout — xs scales the area by (1 + xs)" begin
    base = annulus_capacity(OD, ID)
    @test annulus_capacity(OD, ID; xs=0.10).value ≈ base.value * 1.10
    @test annulus_capacity(OD, ID; xs=0.25, out=m3_m).value ≈ area_m2(8.5, 5.0) * 1.25 atol=1e-15
    @test circle_capacity(D(8.5); xs=0.5).value ≈ circle_capacity(D(8.5)).value * 1.5
end

@testset "volumes — capacity_volume, annulus_volume, circle_volume" begin
    v_ft = annulus_volume(OD, ID, Length(1000.0, ft))
    v_m  = annulus_volume(OD, ID, Length(304.8, m))
    @test v_ft isa Volume{BBL}
    @test v_ft.value ≈ v_m.value atol=1e-3
    @test v_ft.value ≈ annulus_capacity(OD, ID).value * 1000.0 atol=1e-3
    vm3 = annulus_volume(OD, ID, Length(1000.0, ft) ; out=m3)
    vl  = annulus_volume(OD, ID, Length(1000.0, ft) ; out=ltr)
    @test vm3 isa Volume{M3} && vl isa Volume{L}
    @test vl.value ≈ vm3.value * L_PER_M3 atol=1e-2
    @test vm3.value ≈ area_m2(8.5, 5.0) * 1000.0 * M_PER_FT atol=1e-9      # m² × m
    # generic volume from any capacity, any unit
    @test capacity_volume(annulus_capacity(OD, ID; out=l_m), Length(1000.0, ft)).value ≈ v_ft.value atol=1e-3
    @test capacity_volume(annulus_capacity(OD, ID; out=m3_m), Length(304.8, m); out=m3).value ≈ vm3.value atol=1e-9
    @test capacity_volume(annulus_capacity(OD, ID), Length(304.8, m)).value ≈ capacity_volume(annulus_capacity(OD, ID), Length(1000.0, ft)).value atol=1e-9   # the Length carries its unit
    @test circle_volume(D(8.5), Length(1000.0, ft)).value ≈ circle_capacity(D(8.5)).value * 1000.0 atol=1e-3
    @test circle_volume(D(8.5), Length(1000.0, ft)).value ≈ v_ft.value + circle_volume(D(5.0), Length(1000.0, ft)).value atol=1e-3
    @test annulus_volume(OD, ID, Length(1000.0, ft) ; xs=0.10).value ≈ v_ft.value * 1.10 atol=1e-3
end

#==============================================================================#
# Edge cases — boundaries of geometry, washout and length                      #
#==============================================================================#

@testset "edge — thin annulus and extreme ratios stay finite and positive" begin
    thin = annulus_capacity(OD, D(8.499))                                # 0.001" gap
    @test thin.value > 0 && isfinite(thin.value)
    @test annulus_capacity(OD, D(8.49); out=m3_m).value ≈ area_m2(8.5, 8.49) rtol=1e-9
    wide = annulus_capacity(D(36.0), D(0.5))                             # 72:1 ratio
    @test wide.value ≈ circle_capacity(D(36.0)).value - circle_capacity(D(0.5)).value atol=1e-12
    tiny = circle_capacity(D(0.001))                                        # sub-mil bore
    @test tiny.value > 0 && isfinite(tiny.value)
end

@testset "edge — washout bounds are inclusive" begin
    @test hole_capacity(OD; xs=0.0).value == hole_capacity(OD).value
    @test hole_capacity(OD; xs=1.0).value ≈ 2 * circle_capacity(D(8.5)).value atol=1e-12
    @test annulus_capacity(OD, ID; xs=1.0).value ≈ 2 * annulus_capacity(OD, ID).value atol=1e-12
end

@testset "edge — integer inputs are accepted" begin
    @test annulus_capacity(Diameter(8, inch), Diameter(5, inch)).value ≈ annulus_capacity(D(8.0), D(5.0)).value
    @test circle_capacity(D(8)).value ≈ circle_capacity(D(8.0)).value
    @test capacity_volume(annulus_capacity(OD, ID), Length(1000, ft)).value ≈ capacity_volume(annulus_capacity(OD, ID), Length(1000.0, ft)).value
end

@testset "edge — zero and very long lengths" begin
    cap = annulus_capacity(OD, ID)
    @test capacity_volume(cap, Length(0.0, ft)).value == 0.0
    @test annulus_volume(OD, ID, Length(0.0, ft)).value == 0.0
    deep = annulus_volume(OD, ID, Length(30_000.0, ft))
    @test deep.value ≈ 0.045896 * 30_000 rtol=1e-4
    @test isfinite(annulus_volume(OD, ID, Length(1.0e6, ft) ; out=m3).value)
end

#===============================================================================#
# Failure cases — rejected inputs and the error type each raises today          #
#   od ≤ id and washout guards: ArgumentError (spec task 2.3 may move these to  #
#   UomDefinitions error types); negative / non-finite diameters and lengths    #
#   are rejected by the UomDefinitions constructors                             #
#===============================================================================#

@testset "failure — invalid annular geometry" begin
    @test_throws ArgumentError circle_capacity(D(0.0))
    @test_throws NegativeValueError circle_capacity(D(-8.5))
    @test_throws ArgumentError pipe_displacement(D(4.892), D(5.5))   # id larger than od
    @test_throws ArgumentError pipe_capacity(D(0.0))
    @test_throws ArgumentError hole_capacity(D(0.0))
    # typed core: geometry rules with units compared in metres
    @test_throws ArgumentError annulus_capacity(ID, OD)                                      # od < id
    @test_throws ArgumentError annulus_capacity(Diameter(8.5, inch), Diameter(8.5, inch))
    @test_throws ArgumentError annulus_capacity(Diameter(8.5, inch), Diameter(215.9, mm))   # equal after conversion
    @test_throws ArgumentError annulus_capacity(Diameter(127.0, mm), Diameter(8.5, inch))   # od < id across units
    @test_throws ArgumentError annulus_capacity(Diameter(0.0, inch))                         # zero od, full circle
end

@testset "failure — annulus_capacity and the oilfield wrappers have no untyped form" begin
    @test_throws MethodError annulus_capacity(8.5, 5.0)
    @test_throws MethodError annulus_capacity(8.5, 5.0; unit=inch)
    @test_throws MethodError annulus_capacity(8.5)
    @test_throws MethodError annulus_capacity(OD, 5.0)                                       # mixing typed and bare
    @test_throws MethodError annulus_capacity(8.5, ID)
    @test_throws MethodError hole_capacity(8.5)
    @test_throws MethodError hole_capacity(8.5; unit=inch)
    @test_throws MethodError pipe_capacity(4.892)
    @test_throws MethodError pipe_capacity(4.892; unit=inch, out=bbl_ft)
    @test_throws MethodError pipe_displacement(5.5, 4.892)
    @test_throws MethodError pipe_displacement(D(5.5), 4.892)                                # mixing typed and bare
    @test_throws MethodError circle_capacity(8.5)
    @test_throws MethodError circle_capacity(8.5; unit=inch)
    @test_throws MethodError annulus_volume(8.5, 5.0, 1000.0)
    @test_throws MethodError annulus_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft)
    @test_throws MethodError annulus_volume(OD, ID, 1000.0)                                   # typed diameters, bare length
    @test_throws MethodError circle_volume(8.5, 1000.0)
    @test_throws MethodError circle_volume(D(8.5), 1000.0; length_unit=ft)
    # capacity_volume: the length is a Length, never a bare number with a unit keyword
    @test_throws MethodError capacity_volume(annulus_capacity(OD, ID), 1000.0)
    @test_throws MethodError capacity_volume(annulus_capacity(OD, ID), 1000.0; length_unit=ft)
    @test_throws MethodError capacity_volume(annulus_capacity(OD, ID), Length(1000.0, ft); length_unit=ft)
end

@testset "failure — non-finite diameters rejected by Diameter" begin
    @test_throws InvalidValueError circle_capacity(D(NaN))
    @test_throws InvalidValueError circle_capacity(D(Inf))
end

@testset "failure — washout factor outside [0, 1]" begin
    @test_throws ArgumentError annulus_capacity(OD, ID; xs=1.5)
    @test_throws ArgumentError annulus_capacity(OD, ID; xs=1.0001)
    @test_throws ArgumentError circle_capacity(D(8.5); xs=-0.1)
    @test_throws ArgumentError hole_capacity(OD; xs=-1e-9)
    @test_throws ArgumentError annulus_capacity(OD, ID; xs=NaN)
    @test_throws ArgumentError annulus_capacity(OD, ID; xs=Inf)
    # washout is not an accepted argument for steel or bore
    @test_throws MethodError pipe_capacity(D(4.892); xs=0.1)
    @test_throws MethodError pipe_displacement(D(5.5), D(4.892); xs=0.1)
end

@testset "failure — invalid lengths rejected by Length" begin
    cap = annulus_capacity(OD, ID)
    @test_throws NegativeValueError capacity_volume(cap, Length(-1.0, ft))   # rejected by Length
    @test_throws NegativeValueError annulus_volume(OD, ID, Length(-100.0, ft))
    @test_throws InvalidValueError  capacity_volume(cap, Length(NaN, m))
    @test_throws InvalidValueError  circle_volume(D(8.5), Length(Inf, ft))
end

@testset "failure — unit singletons must be the right family" begin
    @test_throws TypeError   annulus_capacity(OD, ID; out=bbl)            # a VolumeUnit is not a CapacityUnit
    @test_throws TypeError   capacity_volume(annulus_capacity(OD, ID), Length(10.0, ft); out=bbl_ft)
    @test_throws MethodError capacity_volume(0.0459, Length(1000.0, ft))  # bare number is not a Capacity
end
