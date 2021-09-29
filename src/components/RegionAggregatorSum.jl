using Mimi

@defcomp RegionAggregatorSum begin
    
    inputregions = Index()
    outputregions = Index()

    input_output_mapping = Parameter{String}(index=[inputregions]) # one element per input region containing it's corresponding output region
    input_output_mapping_int = Variable{Int}(index=[inputregions]) # internally computed for speed up

    input_region_names = Parameter{Vector{String}}(index=inputregions)
    output_region_names = Parameter{Vector{String}}(index=outputregions)

    input = Parameter(index=[time, inputregions])
    output = Variable(index=[time, outputregions])

    function init(p,v,d)
        idxs = indexin(p.input_output_mapping, p.output_region_names)
        !isnothing(findfirst(i -> isnothing(i), idxs)) ? error("All provided region names in the RegionAggregatorSum's input_output_mapping Parameter must exist in the output_region_names Parameter.") : nothing
        v.input_output_mapping_int[:] = idxs
    end

    function run_timestep(p,v,d,t)
        v.output[t, :] .= 0.

        for i in d.inputregions
            v.output[t, v.input_output_mapping_int[i]] += p.input[t,i]
        end
    end
end
