module MimiSSPs

global g_datasets = Dict{Symbol,Any}()

# TODO note these components can only run from 1750 to 2500 for emissions and 
# from 2010 to 2500 for socioeconomic!

include("components/SSPs.jl")
include("components/RegionAggregatorSum.jl")

export SSPs, RegionAggregatorSum

end # module
