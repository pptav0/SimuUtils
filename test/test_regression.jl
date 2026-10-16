using Test
using SimuUtils
using UomDefinitions: InvalidValueError

@testset "regression — Normal" begin
    # exported helpers
    @test Base.isexported(SimuUtils, :linear_regression)
    @test Base.isexported(SimuUtils, :non_linear_regression)
    @test Base.isexported(SimuUtils, :calculate_r_squared)
    # known line y = 2x + 1
    X = [0.0, 1.0, 2.0, 3.0, 4.0]
    slope, intercept = linear_regression(X, 2 .* X .+ 1)
    @test slope ≈ 2.0 atol=1e-12
    @test intercept ≈ 1.0 atol=1e-12
    # least squares on noisy line: symmetric noise leaves the fit unchanged
    s2, i2 = linear_regression(X, 2 .* X .+ 1 .+ [0.1, -0.1, 0.0, 0.1, -0.1])
    @test s2 ≈ 2.0 atol=0.05
    @test i2 ≈ 1.0 atol=0.1
    # known quadratic y = 1 + 0x + 2x²
    c = non_linear_regression([0.0, 1.0, 2.0, 3.0], [1.0, 3.0, 9.0, 19.0])
    @test length(c) == 3
    @test c[1] ≈ 1.0 atol=1e-9
    @test c[2] ≈ 0.0 atol=1e-9
    @test c[3] ≈ 2.0 atol=1e-9
    # R² = 1 for an exact fit, < 1 otherwise
    Y = 2 .* X .+ 1
    @test calculate_r_squared(Y, Y) == 1.0
    r2 = calculate_r_squared(Y, Y .+ [0.5, -0.5, 0.5, -0.5, 0.5])
    @test 0.0 < r2 < 1.0
    # integer vectors and ranges are accepted
    @test linear_regression(1:4, [3, 5, 7, 9])[1] ≈ 2.0
    @test calculate_r_squared([1, 2, 3], [1, 2, 3]) == 1.0
end

@testset "regression — Edge" begin
    # two points define the line exactly
    @test all(linear_regression([1.0, 2.0], [3.0, 5.0]) .≈ (2.0, 1.0))
    # three points define the quadratic exactly
    c = non_linear_regression([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
    @test c ≈ [0.0, 0.0, 1.0] atol=1e-9
    # constant Y: exact fit -> 1.0, any residual -> 0.0 (not NaN / -Inf)
    @test calculate_r_squared([5.0, 5.0, 5.0], [5.0, 5.0, 5.0]) == 1.0
    @test calculate_r_squared([5.0, 5.0, 5.0], [5.0, 5.0 + 1e-15, 5.0]) == 1.0   # float round-trip counts as exact
    @test calculate_r_squared([5.0, 5.0, 5.0], [4.0, 5.0, 6.0]) == 0.0
    # flat Y still fits a horizontal line
    @test all(linear_regression([1.0, 2.0, 3.0], [5.0, 5.0, 5.0]) .≈ (0.0, 5.0))
    # unsorted X is fine
    @test linear_regression([3.0, 1.0, 2.0], [7.0, 3.0, 5.0])[1] ≈ 2.0
    # negative R² is possible for a fit worse than the mean
    @test calculate_r_squared([1.0, 2.0, 3.0], [3.0, 2.0, 1.0]) < 0.0
end

@testset "regression — Failure" begin
    # structural
    @test_throws ArgumentError linear_regression([1.0, 2.0, 3.0], [1.0, 2.0])
    @test_throws ArgumentError linear_regression(Float64[], Float64[])
    @test_throws ArgumentError linear_regression([1.0], [2.0])
    @test_throws ArgumentError linear_regression([2.0, 2.0, 2.0], [1.0, 2.0, 3.0])   # no distinct X
    @test_throws ArgumentError non_linear_regression([1.0, 2.0], [1.0, 4.0])          # < 3 points
    @test_throws ArgumentError non_linear_regression([1.0, 1.0, 2.0], [1.0, 1.0, 4.0]) # < 3 distinct X
    @test_throws ArgumentError non_linear_regression([1.0, 2.0, 3.0], [1.0, 4.0])
    @test_throws ArgumentError calculate_r_squared([1.0, 2.0], [1.0])
    @test_throws ArgumentError calculate_r_squared([1.0], [1.0])
    @test_throws ArgumentError calculate_r_squared(Float64[], Float64[])
    # values
    @test_throws InvalidValueError linear_regression([1.0, NaN, 3.0], [1.0, 2.0, 3.0])
    @test_throws InvalidValueError linear_regression([1.0, 2.0, 3.0], [1.0, Inf, 3.0])
    @test_throws InvalidValueError non_linear_regression([1.0, 2.0, 3.0, 4.0], [1.0, 4.0, NaN, 16.0])
    @test_throws InvalidValueError calculate_r_squared([1.0, 2.0, 3.0], [1.0, 2.0, NaN])
    # types
    @test_throws MethodError linear_regression(["a", "b"], [1.0, 2.0])
    @test_throws MethodError calculate_r_squared([1.0, 2.0], 1.0)
end
