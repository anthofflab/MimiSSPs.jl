module MimiSSPs

global g_ssp_datasets = Dict{Symbol,Any}()
global g_emissions_scenario_datasets = Dict{Symbol,Any}()

include("components/SSPs.jl")
include("components/RegionAggregatorSum.jl")

end # module
