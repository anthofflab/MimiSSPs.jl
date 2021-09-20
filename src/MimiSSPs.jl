module MimiSSPs

global g_datasets = Dict{Symbol,Any}()

include("components/SSPs.jl")
include("components/RegionAggregatorSum.jl")

export SSPs, RegionAggregatorSum

end # module
