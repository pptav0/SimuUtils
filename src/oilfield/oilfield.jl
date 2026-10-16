# Oilfield domain types: casings, rheology models and fluids. May use helpers
# and geometry; never the plotting layer (the well schematic drawing lives there).
# Order matters: casings.jl first (Casing is used by calc_capacity wrappers);
# rheos.jl before fluids.jl because Fluid holds a RheoModel.
include("casings.jl")
include("rheos.jl")
include("fluids.jl")
