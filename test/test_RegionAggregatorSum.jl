using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "OECD Env-Growth_dummyInputOutput.csv")) |> DataFrame

inputregions = dummy_input_output.Input_Region
outputregions = sort(unique(dummy_input_output.Output_Region))
data = round.(rand(length(2000:2010), length(inputregions)) * 1000)

m = Model()
set_dimension!(m, :time, 2000:2010)
set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

add_comp!(m, MimiSSPs.RegionAggregatorSum)
update_param!(m, :RegionAggregatorSum, :input_region_names, inputregions)
update_param!(m, :RegionAggregatorSum, :output_region_names, outputregions)
update_param!(m, :RegionAggregatorSum, :input, data)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, dummy_input_output.Output_Region)

run(m)

expected_output = zeros(length(2000:2010), length(outputregions))
for (i, output_region) in enumerate(outputregions)
    idxs = findall(i -> i ==  output_region, dummy_input_output[:,2])
    expected_output[:, i] = sum(data[:, idxs], dims = 2)
end

@test (m[:RegionAggregatorSum, :output]) ≈ expected_output atol = 1e-9

bad_mapping = dummy_input_output.Output_Region
bad_mapping[5] = "Region-MISSING" # this does not exist in the output regions list
update_param!(m, :RegionAggregatorSum, :input_output_mapping, bad_mapping)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("All provided region names in the RegionAggregatorSum's input_output_mapping Parameter must exist in the output_region_names Parameter.", error_msg)
