using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_dummyInputOutput.csv")) |> DataFrame

input-regions = dummy_input_output.Input_Region
output-regions = sort(unique(dummy_input_output.Output_Region))

m = Model()
set_dimension!(m, :time, 1750:2300)

# Handle the MimiSSPs.SSPs component
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
set_dimension!(m, :countries, input-regions)
update_param!(m, :SSPs, :country_names, input-regions)

update_param!(m, :SSPs, :SSPmodel, "IIASA GDP")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :RCPmodel, "Leach")
update_param!(m, :SSPs, :RCP, "RCP1.9")

# Handle the MimiSSPs.RegionAggregatorSum component
add_comp!(m, MimiSSPs.RegionAggregatorSum)

set_dimension!(m, :input-regions, input-regions)
set_dimension!(m, :output-regions, output-regions)

update_param!(m, :RegionAggregatorSum, :input_region_names, input-regions)
update_param!(m, :RegionAggregatorSum, :output_region_names, output-regions)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, Matrix(dummy_input_output))

backup_pop = zeros(length(1750:2300), length(input-regions))
connect_param!(m, :RegionAggregatorSum, :input, :SSPs, :population, backup_pop, ignoreunits=true)

run(m)
