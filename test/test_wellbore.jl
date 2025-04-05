using Test
using SimuUtils

import SimuUtils: DiameterUnit, LengthUnit
import SimuUtils: IN, MM, FT, M
import Makie.Figure

# Define test casings
outer_casings_test = Casing[
	Casing(13.375, 12.415, IN::DiameterUnit; depth=(1000.0, FT::LengthUnit)),
	Casing(9.625, 8.755, IN::DiameterUnit; depth=(5000.0, FT::LengthUnit)),
]

inner_casings_test = Casing[
	Casing(7.0, 6.276, IN::DiameterUnit; depth=(3000.0, FT::LengthUnit)),
	Casing(5.5, 4.892, IN::DiameterUnit; depth=(10000.0, FT::LengthUnit)),
]

# Test the plot_well_schem function
@testset "Well Schematic Plot" begin
    fig = plot_well_schem(outer_casings_test, inner_casings_test; airgap=50.0, water_depth=500.0, units=FT::LengthUnit)
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
