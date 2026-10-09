using Test
using SimuUtils
using UomDefinitions: inch, mm, ft, m, FT3_PER_BBL, GAL_PER_BBL, M3_PER_FT3

@testset "annular_capacity — 8.5in OH x 5.0in csg" begin
    caps = annular_capacity(8.5, 5.0; unit=inch)
    # π/4 (8.5² − 5²)/144 ft² = 0.25771 ft²
    @test caps.ft2    ≈ 0.257709 atol=1e-5
    @test caps.ft3_ft ≈ caps.ft2
    @test caps.bbl_ft ≈ caps.ft2 / FT3_PER_BBL
    @test caps.gal_ft ≈ caps.bbl_ft * GAL_PER_BBL
    # same geometry expressed in millimeters gives the same capacity
    caps_mm = annular_capacity(215.9, 127.0; unit=mm)
    @test caps_mm.bbl_ft ≈ caps.bbl_ft atol=1e-9
end

@testset "annular_capacity — washout, area-only, validation" begin
    base = annular_capacity(8.5, 5.0; unit=inch)
    wash = annular_capacity(8.5, 5.0; unit=inch, xs=0.10)
    @test wash.ft2 ≈ base.ft2 * 1.10
    area_only = annular_capacity(8.5, 5.0; unit=inch, per_length=false)
    @test area_only isa NamedTuple
    @test area_only.ft2 ≈ base.ft2
    @test_throws ArgumentError annular_capacity(5.0, 8.5; unit=inch)
    @test_throws ArgumentError annular_capacity(8.5, 5.0; unit=inch, xs=1.5)
end

@testset "annular_volume — length units and metric output" begin
    v_ft = annular_volume(8.5, 5.0, 1000.0; unit=inch, length_unit=ft)
    v_m  = annular_volume(8.5, 5.0, 304.8;  unit=inch, length_unit=m)
    @test v_ft.bbl ≈ v_m.bbl atol=1e-9
    @test v_ft.ft3 ≈ annular_capacity(8.5, 5.0; unit=inch).ft3_ft * 1000.0
    @test v_ft.m3  ≈ v_ft.ft3 * M3_PER_FT3
    @test v_ft.gal ≈ v_ft.bbl * GAL_PER_BBL
end
