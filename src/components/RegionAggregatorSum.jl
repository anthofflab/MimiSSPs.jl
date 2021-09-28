using Mimi

@defcomp RegionAggregatorSum begin
    
    inputregions = Index()
    outputregions = Index()

    # first column has input name and second column has mapped output name
    input_output_mapping = Parameter{String}(index=[inputregions, 2])

    input_region_names = Parameter{Vector{String}}(index=inputregions)
    output_region_names = Parameter{Vector{String}}(index=outputregions)

    input = Parameter(index=[time, inputregions])
    output = Variable(index=[time, outputregions])

    function run_timestep(p,v,d,t)
        for output_region in d.outputregions
            idxs = findall(i -> i ==  p.output_region_names[output_region], p.input_output_mapping[:,2])
            v.output[t, output_region] = sum(p.input[t, idxs])
        end
    end
end
