module SimuUtils

# Include all  functions
include("helpers/numeric.jl");
include("helpers/uom.jl");
include("helpers/regression.jl");
# include all geometry functions
include("geometry/area.jl");
# include plots functions
include("plots/regression.jl");

# export functions
export round_to, area_circle, convert, plot_regression, calculate_r_squared;

end
