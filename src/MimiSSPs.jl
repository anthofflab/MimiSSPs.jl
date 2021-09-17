module MimiSSPs

global g_datasets = Dict{Symbol,Any}()

@defcomp SSPs begin
    countries = Dimension()

    population = Variable(index=[time,region])
    income = Variable(index=[time,region])
    co2_emissions = Variable(index=[time,region])

    scenario::Symbol = Parameter()

    function init(p,v,d)
        if scenario==:SSP1
            if haskey(g_datasets, :ssp1_population)
                # Load from files in the `../data` folder
                g_datasets[:ssp1_population] = load_from_disc()
            end

            populuation = g_datasets[:ssp1_population]

            # Here try to look at d.time to figure out which years we need
            # and then filter `population` to only include required years
            population = filtered_population()

            v.population[:,:] = population
        end
    end

    function run_timestep(p,v,d,t)
        # if fixed_timestep and timestep_length==1
        # elseif fixed_timestep and timestep_length==5
        # elseif variabletimesteplength
        # end
    end
end

@defcomp RegionAggregatorSum begin
    countries = Dimension()
    regions = Dimension()

    region_mapping::Dict{Symbol,Vector{Symbol}} = Parameter()
    input = Parameter(index=[time,inputregions])
    output = Parameter(index=[time,outputregions])
end

function foo()
    m = Model()

    set_dimension!(m, :countries, [....])
    set_dimension!(m, :regions, [....])


end # module
