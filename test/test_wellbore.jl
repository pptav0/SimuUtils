using Test
using SimuUtils

using UomDefinitions: Diameter, Length, inch, ft
import Makie.Figure

# Tests for src/oilfield/wellbore.jl (plot_well_schem). Casing itself is
# tested in test_casings.jl.

# Define test casings (typed quantities only)
outer_casings_test = Casing[
    Casing(Diameter(13.375, inch), Diameter(12.415, inch); hanger=Length(550.0, ft), depth=Length(650.0, ft)),
    Casing(Diameter(9.625, inch),  Diameter(8.755, inch);  hanger=Length(550.0, ft), depth=Length(1500.0, ft)),
]

inner_casings_test = Casing[
    Casing(Diameter(7.0, inch), Diameter(6.276, inch); hanger=Length(550.0, ft),  depth=Length(3000.0, ft)),
    Casing(Diameter(5.5, inch), Diameter(4.892, inch); hanger=Length(2900.0, ft), depth=Length(6500.0, ft)),
]

# Test the plot_well_schem function
@testset "Well Schematic Plot" begin
    fig = plot_well_schem(
        outer_casings_test, inner_casings_test;
        airgap=50.0, water_depth=500.0, units=ft)
    @test fig isa Figure
end
