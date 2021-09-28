using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_dummyInputOutput.csv")) |> DataFrame

inputregions = dummy_input_output.Input_Region
outputregions = sort(unique(dummy_input_output.Output_Region))

m = Model()
set_dimension!(m, :time, 1750:2300)

# Handle the MimiSSPs.SSPs component
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
set_dimension!(m, :countries, inputregions)
update_param!(m, :SSPs, :country_names, inputregions)

update_param!(m, :SSPs, :SSPmodel, "IIASA GDP")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :RCPmodel, "Leach")
update_param!(m, :SSPs, :RCP, "RCP1.9")

# Handle the MimiSSPs.RegionAggregatorSum component
add_comp!(m, MimiSSPs.RegionAggregatorSum, first = 2010, last = 2300)

set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

update_param!(m, :RegionAggregatorSum, :input_region_names, inputregions)
update_param!(m, :RegionAggregatorSum, :output_region_names, outputregions)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, Matrix(dummy_input_output))

connect_param!(m, :RegionAggregatorSum, :input, :SSPs, :population, ignoreunits=true)

run(m)
