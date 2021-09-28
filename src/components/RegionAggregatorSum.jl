using Mimi

@defcomp RegionAggregatorSum begin

    input-regions = Index()
    output-regions = Index()

    # first column has input name and second column has mapped output name
    input_output_mapping = Parameter{String}(index=[input-regions, 2])

    input_region_names = Parameter{Vector{String}}(index=input-regions)
    output_region_names = Parameter{Vector{String}}(index=output-regions)

    input = Parameter(index=[time, input-regions])
    output = Variable(index=[time, output-regions])

    function run_timestep(p,v,d,t)
        for output_region in d.output-regions
            idxs = findall(i -> i ==  p.output_region_names[output_region], p.input_output_mapping[:,2])
            v.output[t, output_region] = sum(p.input[t, idxs])
        end
    end
end
