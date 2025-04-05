using Test
using SimuUtils

import SimuUtils: DiameterUnit, LengthUnit
import SimuUtils: IN, MM, FT, M
import Makie.Figure

# Define test casings
outer_casings_test = Casing[
	Casing(13.375, 12.415, IN::DiameterUnit; hanger=(550.0, FT::LengthUnit), depth=(650.0, FT::LengthUnit)),
	Casing(9.625, 8.755, IN::DiameterUnit; hanger=(550.0, FT::LengthUnit), depth=(1500.0, FT::LengthUnit)),
]

inner_casings_test = Casing[
	Casing(7.0, 6.276, IN::DiameterUnit; hanger=(550.0, FT::LengthUnit), depth=(3000.0, FT::LengthUnit)),
	Casing(5.5, 4.892, IN::DiameterUnit; hanger=(2900.0, FT::LengthUnit),depth=(6500.0, FT::LengthUnit)),
]

# Test the plot_well_schem function
@testset "Well Schematic Plot" begin
    fig = plot_well_schem(
    	outer_casings_test, inner_casings_test;
     	airgap=50.0, water_depth=500.0, units=FT::LengthUnit)
    @test fig isa Figure
end

# Test the calc_casing_weight function
@testset "Casing Weight Calculation" begin
    od = 7.0
    id = 6.366
    unit = IN::DiameterUnit
    weight = SimuUtils.calc_casing_weight(od, id, unit)
    @test isapprox(weight, 23.0, atol=0.5)
end

# Test the calc_inner_diameter function
@testset "Inner Diameter Calculation" begin
    od = 7.0
    weight_ppf = 23.0
    unit = IN::DiameterUnit
    id = SimuUtils.calc_casing_id(od, weight_ppf, unit)
    @test isapprox(id, 6.366, atol=0.1)
end

# Define the unit test function
@testset "Casing Constructor Tests" begin
    # Test valid casing
    @testset "Valid Casing" begin
        od = 13.375
        id = 12.415
        hanger = (100.0, FT::LengthUnit)
        depth = (1000.0, FT::LengthUnit)
        casing = Casing(od, id, IN::DiameterUnit; hanger=hanger, depth=depth)
        @test casing.od == (od, IN::DiameterUnit)
        @test casing.id == (id, IN::DiameterUnit)
        @test casing.hanger == hanger
        @test casing.depth == depth
    end

    # Test invalid casing with od <= id
    @testset "Invalid Casing with od <= id" begin
        od = 12.415
        id = 12.415
        hanger = (100.0, FT::LengthUnit)
        depth = (1000.0, FT::LengthUnit)
        @test_throws ArgumentError Casing(od, id, IN::DiameterUnit; hanger=hanger, depth=depth)
    end

    # Test invalid casing with hanger deeper than depth
    @testset "Invalid Casing with hanger deeper than depth" begin
        od = 13.375
        id = 12.415
        hanger = (1100.0, FT::LengthUnit)
        depth = (1000.0, FT::LengthUnit)
        @test_throws ArgumentError Casing(od, id, IN::DiameterUnit; hanger=hanger, depth=depth)
    end
end
