# Structural tests: the src/ tree and the dependency direction
#   helpers → geometry → oilfield → plots   (arrows point left only)
# The layer rule is checked on the raw file text, comments included: a comment
# naming a higher layer is a lie about the dependency direction.
using Test
using SimuUtils

const SRC = normpath(joinpath(@__DIR__, "..", "src"))

"All .jl files under src/<dir>, recursively."
_files(dir) = [joinpath(r, f) for (r, _, fs) in walkdir(joinpath(SRC, dir)) for f in fs if endswith(f, ".jl")]

"""
Names from `names` that occur anywhere in the file at `path`. A name is a whole
word, except that a name ending in `_` is a prefix (`plot_` matches
`plot_well_schem`) and a name ending in `/` is a folder path (`plots/`
matches `plots/wellbore.jl`).
"""
_pattern(n) = Regex("\\b" * n * (endswith(n, "_") || endswith(n, "/") ? "" : "\\b"))
_mentions(path, names) = (txt = read(path, String); [n for n in names if occursin(_pattern(n), txt)])

"Files listed by `include(\"…\")` in a source file, in order."
_includes(path) = [m.captures[1] for m in eachmatch(r"include\(\"([^\"]+)\"\)", read(path, String))]

const GEOMETRY_NAMES = ["annulus_capacity", "hole_capacity", "pipe_capacity", "pipe_displacement",
                        "circle_capacity", "circle_volume", "capacity_volume", "annulus_volume", "geometry/"]
const OILFIELD_NAMES = ["Casing", "CsgWeight", "Thread", "STEEL_DENSITY", "calc_casing_", "calc_capacity",
                        "Fluid", "FluidType", "RheoModel", "Newtonian", "PowerLaw", "Bingham", "HerschelBulkley",
                        "GeneralizedHB", "fit_rheology", "FannReadings", "FannRheology", "FannInputs", "oilfield/"]
const PLOT_NAMES     = ["CairoMakie", "Makie", "MakieThemes", "plot_", "plots/"]

@testset "_mentions — negative controls: prefixes, paths and comments are caught" begin
    mktemp() do path, io
        write(io, "# used by plot_well_schem and plots/wellbore.jl\nx = annulus_capacity(a)\ny = calc_casing_id(b)\n"); close(io)
        @test _mentions(path, PLOT_NAMES) == ["plot_", "plots/"]
        @test _mentions(path, GEOMETRY_NAMES) == ["annulus_capacity"]
        @test _mentions(path, OILFIELD_NAMES) == ["calc_casing_"]
        @test _mentions(path, ["plot", "casing", "annulus"]) == []          # whole words only
    end
end

@testset "helpers/ — files exist and depend on nothing above them" begin
    for f in ["helpers.jl", "numeric.jl", "regression.jl"]
        @test isfile(joinpath(SRC, "helpers", f))
    end
    for path in _files("helpers")
        @test _mentions(path, vcat(GEOMETRY_NAMES, OILFIELD_NAMES, PLOT_NAMES)) == []
    end
end

@testset "geometry/ — files exist and depend on helpers only" begin
    for f in ["geometry.jl", "capacity.jl"]
        @test isfile(joinpath(SRC, "geometry", f))
    end
    for path in _files("geometry")
        @test _mentions(path, vcat(OILFIELD_NAMES, PLOT_NAMES)) == []
    end
end

@testset "oilfield/ — files exist, no plotting, wellbore.jl has moved out" begin
    for f in ["oilfield.jl", "casings.jl", "rheos.jl", "fluids.jl"]
        @test isfile(joinpath(SRC, "oilfield", f))
    end
    @test !isfile(joinpath(SRC, "oilfield", "wellbore.jl"))
    for path in _files("oilfield")
        @test _mentions(path, PLOT_NAMES) == []
    end
    # load order inside the layer: casings first, rheos before fluids
    @test _includes(joinpath(SRC, "oilfield", "oilfield.jl")) == ["casings.jl", "rheos.jl", "fluids.jl"]
end

@testset "plots/ — files exist; the schematic lives here" begin
    for f in ["plots.jl", "wellbore.jl", "regression.jl", "rheology.jl"]
        @test isfile(joinpath(SRC, "plots", f))
    end
    @test _mentions(joinpath(SRC, "plots", "wellbore.jl"), ["plot_well_schem"]) == ["plot_well_schem"]
    @test isdefined(SimuUtils, :plot_well_schem)
end

@testset "SimuUtils.jl — includes exactly the four folder indexes; every export is defined" begin
    @test _includes(joinpath(SRC, "SimuUtils.jl")) == ["helpers/helpers.jl", "geometry/geometry.jl", "oilfield/oilfield.jl", "plots/plots.jl"]
    for dir in ["helpers", "geometry", "oilfield", "plots"]
        index = joinpath(SRC, dir, "$dir.jl")
        @test isfile(index)
        isfile(index) || continue
        for f in _includes(index)
            @test isfile(joinpath(SRC, dir, f))
        end
    end
    exported = names(SimuUtils)
    @test length(exported) == length(unique(exported))
    for n in exported
        @test isdefined(SimuUtils, n)
    end
end
