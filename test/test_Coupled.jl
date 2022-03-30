using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "OECD Env-Growth_dummyInputOutput.csv")) |> DataFrame

inputregions = dummy_input_output.Input_Region
outputregions = sort(unique(dummy_input_output.Output_Region))

m = Model()
set_dimension!(m, :time, 1750:2300)

# Handle the MimiSSPs.SSPs component
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
set_dimension!(m, :country, inputregions)
update_param!(m, :SSPs, :country_names, inputregions)

update_param!(m, :SSPs, :SSP_source, "OECD Env-Growth")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")

# Handle the MimiSSPs.RegionAggregatorSum component
add_comp!(m, MimiSSPs.RegionAggregatorSum, first = 2010, last = 2300)

set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

update_param!(m, :RegionAggregatorSum, :input_region_names, inputregions)
update_param!(m, :RegionAggregatorSum, :output_region_names, outputregions)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, dummy_input_output.Output_Region)

connect_param!(m, :RegionAggregatorSum, :input, :SSPs, :population)

run(m)

# Should also work if Aggregator runs long, using backup data
Mimi.set_first_last!(m, :RegionAggregatorSum, first = 1750)
backup = zeros(551, 184)
connect_param!(m, :RegionAggregatorSum, :input, :SSPs, :population, backup, ignoreunits=true)

run(m)
