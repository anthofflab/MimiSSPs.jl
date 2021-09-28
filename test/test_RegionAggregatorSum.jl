using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_dummyInputOutput.csv")) |> DataFrame

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
update_param!(m, :RegionAggregatorSum, :input_output_mapping, Matrix(dummy_input_output))

run(m)

expected_output = zeros(length(2000:2010), length(outputregions))
for (i, output_region) in enumerate(outputregions)
    idxs = findall(i -> i ==  output_region, dummy_input_output[:,2])
    expected_output[:, i] = sum(data[:, idxs], dims = 2)
end

@test (m[:RegionAggregatorSum, :output]) ≈ expected_output atol = 1e-9
