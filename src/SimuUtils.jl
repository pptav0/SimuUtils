module SimuUtils

using Printf
using LaTeXStrings

# Include all  functions
include("helpers/numeric.jl")
include("helpers/uom.jl")
include("helpers/regression.jl")
# include all geometry functions
include("geometry/area.jl")

# include Oilfield module
include("oilfield/wellbore.jl")
include("oilfield/fluids.jl")

# include plots functions
include("plots/regression.jl")

# export functions
export round_to, area_circle, convert,
    Casing, calc_capacity,
    plot_well_schem,
    plot_regression, calculate_r_squared,
    Fluid, FluidType

end
