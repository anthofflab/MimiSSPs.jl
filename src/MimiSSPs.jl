module MimiSSPs

global g_datasets = Dict{Symbol,Any}()

include("components/SSPs.jl") # contains data for 1750 to 2500 for emissions and 2010 to 2500 for socioeconomic
# include("components/RegionAggregatorSum.jl")

export SSPs, RegionAggregatorSum

end # module
