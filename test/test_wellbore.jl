using Test
using SimuUtils

using UomDefinitions: Diameter, Length, inch, mm, ft, m, bbl_ft, l_m, Capacity, BBL_PER_FT, L_PER_M, to_bbl_ft
import Makie.Figure

# Define test casings
outer_casings_test = Casing[
	Casing(13.375, 12.415, inch; hanger=(550.0, ft), depth=(650.0, ft)),
	Casing(9.625, 8.755, inch; hanger=(550.0, ft), depth=(1500.0, ft)),
]

inner_casings_test = Casing[
	Casing(7.0, 6.276, inch; hanger=(550.0, ft), depth=(3000.0, ft)),
	Casing(5.5, 4.892, inch; hanger=(2900.0, ft),depth=(6500.0, ft)),
]

# Test the plot_well_schem function
@testset "Well Schematic Plot" begin
    fig = plot_well_schem(
    	outer_casings_test, inner_casings_test;
     	airgap=50.0, water_depth=500.0, units=ft)
    @test fig isa Figure
end

# Test the calc_casing_weight function
@testset "Casing Weight Calculation" begin
    od = 7.0
    id = 6.366
    unit = inch
    weight = SimuUtils.calc_casing_weight(od, id, unit)
    @test isapprox(weight, 23.0, atol=0.5)
end

# Test the calc_inner_diameter function
@testset "Inner Diameter Calculation" begin
    od = 7.0
    weight_ppf = 23.0
    unit = inch
    id = SimuUtils.calc_casing_id(od, weight_ppf, unit)
    @test isapprox(id, 6.366, atol=0.1)
end

# Define the unit test function
@testset "Casing Constructor Tests" begin
    # Test valid casing
    @testset "Valid Casing" begin
        od = 13.375
        id = 12.415
        hanger = (100.0, ft)
        depth = (1000.0, ft)
        casing = Casing(od, id, inch; hanger=hanger, depth=depth)
        @test casing.od isa Diameter && casing.od.value == od
        @test casing.id isa Diameter && casing.id.value == id
        @test casing.hanger isa Length && casing.hanger.value == hanger[1]
        @test casing.depth  isa Length && casing.depth.value  == depth[1]
    end

    # Test invalid casing with od <= id
    @testset "Invalid Casing with od <= id" begin
        od = 12.415
        id = 12.415
        hanger = (100.0, ft)
        depth = (1000.0, ft)
        @test_throws ArgumentError Casing(od, id, inch; hanger=hanger, depth=depth)
    end

    # Test invalid casing with hanger deeper than depth
    @testset "Invalid Casing with hanger deeper than depth" begin
        od = 13.375
        id = 12.415
        hanger = (1100.0, ft)
        depth = (1000.0, ft)
        @test_throws ArgumentError Casing(od, id, inch; hanger=hanger, depth=depth)
    end
end

# Casing accepts typed Length depths as well as (value, unit) tuples
@testset "Casing with Length depths & mm diameters" begin
    c = Casing(244.5, 222.4, mm; hanger=Length(0.0, m), depth=Length(1500.0, m))
    @test c.od isa Diameter{typeof(mm)} || c.od.value == 244.5
    @test c.depth.value == 1500.0
    @test c.wt[1] > 0.0
end

@testset "calc_capacity — legacy factor form and typed form agree" begin
    outer = Casing(9.625, 8.755, inch; hanger=(0.0, ft), depth=(1500.0, ft))
    inner = Casing(5.5, 4.892, inch;   hanger=(0.0, ft), depth=(3000.0, ft))
    # legacy: area in in², f = bbl/ft per in² (1/808.5; the familiar 1029.4 applies to d², i.e. already has π/4)
    leg = calc_capacity(outer, inner, 1/808.5)
    typ = calc_capacity(outer, inner)                  # bbl/ft
    @test typ.annular isa Capacity{BBL_PER_FT}
    @test leg.annular  ≈ typ.annular.value  rtol=1e-4
    @test leg.internal ≈ typ.internal.value rtol=1e-4
    @test leg.displace ≈ typ.displace.value rtol=1e-4
    # single casing, metric output
    one = calc_capacity(inner; out=l_m)
    @test one.internal isa Capacity{L_PER_M}
    @test to_bbl_ft(one.internal).value ≈ typ.internal.value atol=1e-12
    @test one.external.value ≈ one.internal.value + one.displace.value atol=1e-9
    # legacy single-casing form: areas in in² when f = 1
    @test calc_capacity(inner, 1.0).internal ≈ (π/4) * 4.892^2 atol=1e-9
end
