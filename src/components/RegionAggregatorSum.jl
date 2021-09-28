using Mimi

@defcomp RegionAggregatorSum begin
    
    inputregions = Index()
    outputregions = Index()

    # first column has input name and second column has mapped output name
    input_output_mapping = Parameter{String}(index=[inputregions])
    input_output_mapping_int = Variable{Int}(index=[inputregions])

    input_region_names = Parameter{Vector{String}}(index=inputregions)
    output_region_names = Parameter{Vector{String}}(index=outputregions)

    input = Parameter(index=[time, inputregions])
    output = Variable(index=[time, outputregions])

    function init(p,v,d)
        for i in d.input_regions
            v.input_output_mapping_int[i] = findfirst(p.input_output_mapping[i], p.input_region_names)
        end
    end

    function run_timestep(p,v,d,t)
        v.output[t, :] .= 0.

        for i in d.inputregions
            v.output[t, v.input_output_mapping_int[i]] += p.input[t,i]
        end
    end
end
