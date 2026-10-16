# Plotting is a package extension (spec D5): SimuUtils must load and work
# without CairoMakie / MakieThemes; the plot functions gain methods only when
# both are loaded. This file must run FIRST in runtests.jl, before any test
# file does `using CairoMakie`.
using Test
using SimuUtils

const EXT = :SimuUtilsMakieExt
const PLOT_STUBS = (:plot_well_schem, :plot_regression, :plot_rheology)

@testset "extension — Normal: core loads without Makie, stubs exist" begin
    @test Base.get_extension(SimuUtils, EXT) === nothing
    for s in PLOT_STUBS
        @test isdefined(SimuUtils, s)
        @test isempty(methods(getfield(SimuUtils, s)))
    end
    @test !haskey(Base.loaded_modules, Base.PkgId(Base.UUID("13f3f980-e62b-5c42-98c6-ff1f3baf88f0"), "CairoMakie"))
    # fresh process: SimuUtils alone never pulls Makie in
    script = """
        using SimuUtils
        ext_free = Base.get_extension(SimuUtils, :SimuUtilsMakieExt) === nothing
        no_makie = !any(k -> k.name in ("CairoMakie", "Makie", "MakieThemes"), keys(Base.loaded_modules))
        stubs = isempty(methods(SimuUtils.plot_regression))
        exit(ext_free && no_makie && stubs ? 0 : 1)
        """
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    @test success(cmd)
end

@testset "extension — Failure: stubs without the extension throw MethodError" begin
    @test_throws MethodError plot_regression([1.0, 2.0], [1.0, 2.0], [1.0, 2.0], [1.0, 2.0], :linear)
    @test_throws MethodError plot_rheology(FannReadings(60, 35, 28, 19, 14, 10, 4, 3), :linear)
    @test_throws MethodError plot_well_schem(Casing[], Casing[])
end

# The triggers are test-target dependencies ([extras]/[targets] in Project.toml),
# so they are visible under `Pkg.test()` but not under `julia --project=.`.
# Skip the Edge block cleanly in that case instead of aborting the whole run.
const MAKIE_AVAILABLE = Base.identify_package("CairoMakie") !== nothing &&
                        Base.identify_package("MakieThemes") !== nothing

if !MAKIE_AVAILABLE
    @warn "CairoMakie/MakieThemes are not in the active environment; the extension Edge tests are skipped — run `Pkg.test()` for the full suite"
    @testset "extension — Edge (skipped: CairoMakie/MakieThemes unavailable)" begin
        @test_skip MAKIE_AVAILABLE
    end
else

using CairoMakie, MakieThemes            # triggers the extension for this and every later test file
using UomDefinitions: Diameter, Length, inch, ft

@testset "extension — Edge: loading both triggers activates the extension" begin
    ext = Base.get_extension(SimuUtils, EXT)
    @test ext !== nothing
    @test ext isa Module
    for s in PLOT_STUBS
        @test !isempty(methods(getfield(SimuUtils, s)))
    end
    # a figure renders headless and saves
    X = [1.0, 2.0, 3.0, 4.0]; Y = 2 .* X .+ 1
    fig = plot_regression(X, Y, X, Y, :linear)
    @test fig isa CairoMakie.Figure
    mktempdir() do dir
        path = joinpath(dir, "fit.png")
        save(path, fig)
        @test isfile(path) && filesize(path) > 0
    end
    schem = plot_well_schem(
        Casing[Casing(Diameter(9.625, inch), Diameter(8.755, inch); hanger=Length(0.0, ft), depth=Length(1500.0, ft))],
        Casing[Casing(Diameter(7.0, inch), Diameter(6.276, inch); hanger=Length(0.0, ft), depth=Length(3000.0, ft))];
        units=ft)
    @test schem isa CairoMakie.Figure
end

end # MAKIE_AVAILABLE
