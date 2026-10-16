using SimuUtils
using Test

@testset "SimuUtils" begin
    include("./test_capacity.jl")
    include("./test_numeric.jl")
    include("./test_regression.jl")
    include("./test_casings.jl")
    include("./test_wellbore.jl")
    include("./test_rheos.jl")
    include("./test_fluids.jl")
end
