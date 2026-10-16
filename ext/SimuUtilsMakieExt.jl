"""
    SimuUtilsMakieExt

Package extension that gives `SimuUtils.plot_well_schem`, `plot_regression`
and `plot_rheology` their methods. It loads automatically once **both**
`CairoMakie` and `MakieThemes` are loaded in the session:

    using SimuUtils, CairoMakie, MakieThemes

Without them SimuUtils loads Makie-free and the three functions have no
methods (spec D5).
"""
module SimuUtilsMakieExt

using SimuUtils
using CairoMakie, MakieThemes
using LaTeXStrings, Printf
import SimuUtils: plot_well_schem, plot_regression, plot_rheology   # add methods to the stubs
using UomDefinitions: LengthUnit, FT, M, ft, m

include("wellbore.jl")
include("regression.jl")
include("rheology.jl")

end # module
