using Test
using SimuUtils
using UomDefinitions: inch, mm, ft, m, bbl, m3, ltr,
    Capacity, Volume, BBL_PER_FT, GAL_PER_FT, M3_PER_M, L_PER_M, BBL, M3, L,
    bbl_ft, gal_ft, m3_m, l_m, to_bbl_ft, to_l_m, GAL_PER_BBL, L_PER_M3, M_PER_FT

@testset "annulus_capacity — 8.5in OH x 5.0in csg, default bbl/ft" begin
    cap = annulus_capacity(8.5, 5.0; unit=inch)
    @test cap isa Capacity{BBL_PER_FT}
    # π/4 (8.5² − 5²)/144 ft² = 0.25771 ft² = 0.045896 bbl/ft
    @test cap.value ≈ 0.045896 atol=1e-5
    # same geometry expressed in millimeters gives the same capacity
    @test annulus_capacity(215.9, 127.0; unit=mm).value ≈ cap.value atol=1e-9
end

@testset "annulus_capacity — every output unit" begin
    ref = annulus_capacity(8.5, 5.0; unit=inch)                  # bbl/ft
    g   = annulus_capacity(8.5, 5.0; unit=inch, out=gal_ft)
    c   = annulus_capacity(8.5, 5.0; unit=inch, out=m3_m)
    l   = annulus_capacity(8.5, 5.0; unit=inch, out=l_m)
    @test g isa Capacity{GAL_PER_FT} && g.value ≈ ref.value * GAL_PER_BBL
    @test c isa Capacity{M3_PER_M}
    @test l isa Capacity{L_PER_M}   && l.value ≈ c.value * L_PER_M3
    # m³/m is numerically the area in m²: 0.25771 ft² × 0.3048²
    @test c.value ≈ 0.257709 * M_PER_FT^2 atol=1e-6
    # all four agree once converted back to bbl/ft
    @test to_bbl_ft(g).value ≈ ref.value atol=1e-12
    @test to_bbl_ft(c).value ≈ ref.value atol=1e-12
    @test to_bbl_ft(l).value ≈ ref.value atol=1e-12
end

@testset "circle_capacity — open hole / pipe bore" begin
    # π/4 · 8.5² / 144 ft² = 0.39406 ft² = 0.070185 bbl/ft
    c = circle_capacity(8.5; unit=inch)
    @test c isa Capacity{BBL_PER_FT}
    @test c.value ≈ 0.070185 atol=1e-5
    # circle == annulus + inner circle
    @test c.value ≈ annulus_capacity(8.5, 5.0).value + circle_capacity(5.0).value atol=1e-12
    @test circle_capacity(215.9; unit=mm).value ≈ c.value atol=1e-9
    @test circle_capacity(8.5; out=l_m).value ≈ to_l_m(c).value atol=1e-9
end

@testset "oilfield wrappers" begin
    @test hole_capacity(8.5).value ≈ circle_capacity(8.5).value
    @test hole_capacity(8.5; xs=0.10).value ≈ circle_capacity(8.5).value * 1.10
    @test pipe_capacity(4.892).value ≈ circle_capacity(4.892).value
    @test pipe_displacement(5.5, 4.892).value ≈ annulus_capacity(5.5, 4.892).value
    # steel + bore == full OD circle
    @test pipe_displacement(5.5, 4.892).value + pipe_capacity(4.892).value ≈ circle_capacity(5.5).value atol=1e-12
    # washout is not an accepted argument for steel or bore
    @test_throws MethodError pipe_capacity(4.892; xs=0.1)
    @test_throws MethodError pipe_displacement(5.5, 4.892; xs=0.1)
end

@testset "validation" begin
    base = annulus_capacity(8.5, 5.0; unit=inch)
    wash = annulus_capacity(8.5, 5.0; unit=inch, xs=0.10)
    @test wash.value ≈ base.value * 1.10
    @test_throws ArgumentError annulus_capacity(5.0, 8.5; unit=inch)
    @test_throws ArgumentError annulus_capacity(8.5, 5.0; unit=inch, xs=1.5)
    @test_throws ArgumentError circle_capacity(0.0)
    @test_throws ArgumentError circle_capacity(8.5; xs=-0.1)
end

@testset "volumes — capacity_volume, annulus_volume, circle_volume" begin
    v_ft = annulus_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft)
    v_m  = annulus_volume(8.5, 5.0, 304.8;  unit=inch, length_unit=m)
    @test v_ft isa Volume{BBL}
    @test v_ft.value ≈ v_m.value atol=1e-3
    @test v_ft.value ≈ annulus_capacity(8.5, 5.0; unit=inch).value * 1000.0 atol=1e-3
    vm3 = annulus_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft, out=m3)
    vl  = annulus_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft, out=ltr)
    @test vm3 isa Volume{M3} && vl isa Volume{L}
    @test vl.value ≈ vm3.value * L_PER_M3 atol=1e-2
    # generic volume from any capacity, any unit
    @test capacity_volume(annulus_capacity(8.5, 5.0; out=l_m), 1000.0).value ≈ v_ft.value atol=1e-3
    @test circle_volume(8.5, 1000.0).value ≈ circle_capacity(8.5).value * 1000.0 atol=1e-3
    @test circle_volume(8.5, 1000.0).value ≈ v_ft.value + circle_volume(5.0, 1000.0).value atol=1e-3
end

@testset "annulus_capacity — id defaults to 0 (full circle)" begin
    @test annulus_capacity(8.5).value ≈ circle_capacity(8.5).value
    @test annulus_capacity(8.5, 0.0).value ≈ circle_capacity(8.5).value
    # m³/m is the area in m²: π/4 · (0.2159² − 0.127²)
    @test annulus_capacity(8.5, 5.0; out=m3_m).value ≈ (π/4) * ((8.5*0.0254)^2 - (5.0*0.0254)^2) atol=1e-15
    @test_throws ArgumentError annulus_capacity(8.5, -1.0)
end
