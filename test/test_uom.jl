using Test
include("../src/helpers/uom.jl")

# Test unit conversions
@testset "Unit Conversions" begin
    @test convert(10.0, BBL, M3) ≈ 1.59 atol=1e-3
    @test convert(1.0, M, FT) ≈ 3.28084 atol=1e-3
    @test convert(1.0, KG, LB) ≈ 2.20462 atol=1e-2
    @test convert(1.0, FT_S, M_S) ≈ 0.3048 atol=1e-3

    # Test invalid conversion
    @test_throws ArgumentError convert(10.0, BBL, M)
end

# Test Uom struct and conversions
@testset "Uom Struct and Conversions" begin
    volume1 = Uom(10.0, BBL)
    volume2 = Uom(1.0, M3)
    volume2_converted = convert(volume2, BBL)
    @test volume2_converted.value ≈ 6.28981 atol=1e-3

    length1 = Uom(1.0, M)
    length2 = Uom(3.28084, FT)
    length2_converted = convert(length2, M)
    @test length2_converted.value ≈ 1.0 atol=1e-3
end

# Test arithmetic operations
@testset "Arithmetic Operations" begin
    volume1 = Uom(10.0, BBL)
    volume2 = Uom(1.0, M3)
    total_volume = volume1 + volume2
    @test total_volume.value ≈ 16.28981 atol=1e-3

    length1 = Uom(1.0, M)
    length2 = Uom(3.28084, FT)
    total_length = length1 + length2
    @test total_length.value ≈ 2.0 atol=1e-3

    scaled_volume = volume1 * 2.0
    @test scaled_volume.value ≈ 20.0 atol=1e-3

    divided_volume = volume1 / 2.0
    @test divided_volume.value ≈ 5.0 atol=1e-3
end
