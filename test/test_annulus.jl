using Test
using SimuUtils
using UomDefinitions: inch, mm, ft, m, bbl, m3, ltr,
    Capacity, Volume, BBL_PER_FT, GAL_PER_FT, M3_PER_M, L_PER_M, BBL, M3, L,
    bbl_ft, gal_ft, m3_m, l_m, to_bbl_ft, to_l_m, GAL_PER_BBL, L_PER_M3, M_PER_FT

@testset "annular_capacity — 8.5in OH x 5.0in csg, default bbl/ft" begin
    cap = annular_capacity(8.5, 5.0; unit=inch)
    @test cap isa Capacity{BBL_PER_FT}
    # π/4 (8.5² − 5²)/144 ft² = 0.25771 ft² = 0.045896 bbl/ft
    @test cap.value ≈ 0.045896 atol=1e-5
    # same geometry expressed in millimeters gives the same capacity
    @test annular_capacity(215.9, 127.0; unit=mm).value ≈ cap.value atol=1e-9
end

@testset "annular_capacity — every output unit" begin
    ref = annular_capacity(8.5, 5.0; unit=inch)                  # bbl/ft
    g   = annular_capacity(8.5, 5.0; unit=inch, out=gal_ft)
    c   = annular_capacity(8.5, 5.0; unit=inch, out=m3_m)
    l   = annular_capacity(8.5, 5.0; unit=inch, out=l_m)
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

@testset "annular_capacity — washout & validation" begin
    base = annular_capacity(8.5, 5.0; unit=inch)
    wash = annular_capacity(8.5, 5.0; unit=inch, xs=0.10)
    @test wash.value ≈ base.value * 1.10
    @test_throws ArgumentError annular_capacity(5.0, 8.5; unit=inch)
    @test_throws ArgumentError annular_capacity(8.5, 5.0; unit=inch, xs=1.5)
end

@testset "annular_volume — length units and output units" begin
    v_ft = annular_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft)
    v_m  = annular_volume(8.5, 5.0, 304.8;  unit=inch, length_unit=m)
    @test v_ft isa Volume{BBL}
    @test v_ft.value ≈ v_m.value atol=1e-3
    @test v_ft.value ≈ annular_capacity(8.5, 5.0; unit=inch).value * 1000.0 atol=1e-3
    vm3 = annular_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft, out=m3)
    vl  = annular_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft, out=ltr)
    @test vm3 isa Volume{M3} && vl isa Volume{L}
    @test vl.value ≈ vm3.value * L_PER_M3 atol=1e-2
    @test vm3.value ≈ to_l_m(annular_capacity(8.5, 5.0; unit=inch)).value * 304.8 / L_PER_M3 atol=1e-3
end
