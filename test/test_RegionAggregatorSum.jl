using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_dummyInputOutput.csv")) |> DataFrame

input-regions = dummy_input_output.Input_Region
output-regions = sort(unique(dummy_input_output.Output_Region))
data = round.(rand(length(2000:2010), length(input-regions)) * 1000)

m = Model()
set_dimension!(m, :time, 2000:2010)
set_dimension!(m, :input-regions, input-regions)
set_dimension!(m, :output-regions, output-regions)

add_comp!(m, MimiSSPs.RegionAggregatorSum)
update_param!(m, :RegionAggregatorSum, :input_region_names, input-regions)
update_param!(m, :RegionAggregatorSum, :output_region_names, output-regions)
update_param!(m, :RegionAggregatorSum, :input, data)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, Matrix(dummy_input_output))

run(m)

expected_output = zeros(length(2000:2010), length(output-regions))
for (i, output_region) in enumerate(output-regions)
    idxs = findall(i -> i ==  output_region, dummy_input_output[:,2])
    expected_output[:, i] = sum(data[:, idxs], dims = 2)
end

@test (m[:RegionAggregatorSum, :output]) ≈ expected_output atol = 1e-9
