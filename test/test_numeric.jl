using Test
using SimuUtils

@testset "round_to — Normal" begin
    @test round_to(3.14159, 2) == 3.14
    @test round_to(3.14159, 4) == 3.1416
    @test round_to(2.5, 0) == 2.0            # round-half-even
    @test round_to(3.5, 0) == 4.0
    @test round_to(1234.5678, 1) == 1234.6
    @test round_to(3, 2) == 3.0              # Int input
    @test round_to(3, 2) isa Float64
    @test round_to(7 // 2, 0) == 4.0         # Rational input
end

@testset "round_to — Edge" begin
    @test round_to(-1.5, 0) == -2.0          # negative half, half-even
    @test round_to(-2.5, 0) == -2.0
    @test round_to(-3.14159, 2) == -3.14
    @test round_to(0.0, 3) == 0.0
    @test round_to(1e-9, 2) == 0.0
    @test isnan(round_to(NaN, 2))            # NaN passes through
    @test round_to(Inf, 2) == Inf
    @test round_to(0.1 + 0.2, 10) == 0.3
end

@testset "round_to — Failure" begin
    @test_throws ArgumentError round_to(3.14159, -1)
    @test_throws MethodError round_to("3.14", 2)
    @test_throws MethodError round_to(3.14159, 2.0)
    @test_throws MethodError round_to(3.14159)
end
