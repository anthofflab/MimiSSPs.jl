
using Mimi, CSVFiles, DataFrames, Query, Interpolations

@defcomp SSPs begin

    country = Index()

    SSP_source          = Parameter{String}() # can be one of IIASA GDP, OECD Env-Growth, PIK GDP_32, and Benveniste
    SSP                 = Parameter{String}() # can be one of SSP1, SSP2, SSP3, SSP4, SSP5
    emissions_source    = Parameter{String}() # can be one of Leach
    emissions_scenario  = Parameter{String}() # can be one of SSP119, SSP126, SSP245, SSP370, SSP585

    country_names       = Parameter{String}(index=[country]) # need the names of the countries from the dimension

    population          = Variable(index=[time, country], unit="million")
    population_global   = Variable(index=[time], unit="million")
    gdp                 = Variable(index=[time, country], unit="billion US\$2005/yr")
    gdp_global          = Variable(index=[time], unit="billion US\$2005/yr")

    co2_emissions       = Variable(index=[time], unit="GtC/yr")
    ch4_emissions       = Variable(index=[time], unit="MtCH4/yr")
    n2o_emissions       = Variable(index=[time], unit="MtN/yr")
    sf6_emissions       = Variable(index=[time], unit="MtSF6/yr")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Checks

        ssp_model_options = ["IIASA GDP", "OECD Env-Growth", "PIK GDP_23", "Benveniste"]
        !(p.SSP_source in ssp_model_options) && error("Model $(p.SSP_source) provided to SSPs component SSP_source parameter not found in available list: $(ssp_model_options)")
        
        ssp_options = ["SSP1", "SSP2", "SSP3", "SSP4", "SSP5"]
        !(p.SSP in ssp_options) && error("SSP $(p.SSP) provided to SSPs component SSP parameter not found in available list: $(ssp_options)")
        
        emissions_source_options = ["Leach"]
        !(p.emissions_source in emissions_source_options) && error("Model $(p.emissions_source) provided to SSPs component emissions_source parameter not found in available list: $(emissions_source_options)")
        
        emissions_scenario_options = ["SSP119", "SSP126", "SSP245", "SSP370", "SSP585"]
        !(p.emissions_scenario in emissions_scenario_options) && error("emissions_scenario $(p.emissions_scenario) provided to SSPs component emissions_scenario parameter not found in available list: $(emissions_scenario_options)")

        # ----------------------------------------------------------------------
        # Load Socioeconomic Data as Needed
        #   population in millions of individuals
        #   GDP in billions of $2005 USD

        socioeconomic_path = joinpath(@__DIR__, "..", "..", "data", "socioeconomic", "$(p.SSP_source)_$(p.SSP).csv")
        ssp_dict_key = Symbol(p.SSP_source, "-", p.SSP)

        if !haskey(g_ssp_datasets, ssp_dict_key)
            g_ssp_datasets[ssp_dict_key] = load(socioeconomic_path) |> DataFrame
        end

        # Check Countries - each country found in the model countries parameter
        # must exist in the SSP socioeconomics dataframe 

        missing_countries = []
        unique_country_list = unique(g_ssp_datasets[ssp_dict_key].country)
        for country in p.country_names
            !(country in unique_country_list) && push!(missing_countries, country)
        end
        !isempty(missing_countries) && error("All countries in countries parameter must be found in SSPs component Socioeconomic Dataframe, the following were not found: $(missing_countries)")

        # ----------------------------------------------------------------------
        # Load Emissions Data as Needed
        #   carbon dioxide emissions in GtC
        #   nitrous oxide emissions in MtN
        #   methane emissions in MtCH4
        #   SF6 emissions in MtSF6

        emissions_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "$(p.emissions_source)_$(p.emissions_scenario).csv")
        emissions_scenario_dict_key = Symbol(p.emissions_source, "-", p.emissions_scenario)

        if !haskey(g_emissions_scenario_datasets, emissions_scenario_dict_key)
            if p.emissions_source == "Leach"
                emissions_data = load(emissions_path, skiplines_begin = 6)|> 
                        DataFrame |> 
                        i -> rename!(i, Symbol.([:year, names(i)[2:end]...])) |> 
                        DataFrame |>
                        @select(:year, :carbon_dioxide, :nitrous_oxide, :methane, :sf6) |>
                        DataFrame
            else # already perfect formatted
                emissions_data = load(emissions_path)|> DataFrame
            end

            g_emissions_scenario_datasets[emissions_scenario_dict_key]= emissions_data
        end       
    end

    function run_timestep(p,v,d,t)

        ssp_dict_key = Symbol(p.SSP_source, "-", p.SSP)
        emissions_scenario_dict_key = Symbol(p.emissions_source, "-", p.emissions_scenario)

        year_label = gettime(t)

        # check that we only run the component where we have data
        if !(year_label in g_ssp_datasets[ssp_dict_key].year)
            error("Cannot run SSP component in year $(year_label), SSP socioeconomic variables not available for this model and year.")
        end
        if !(year_label in g_emissions_scenario_datasets[emissions_scenario_dict_key].year)
            error("Cannot run SSP component in year $(year_label), SSP emissions variables not available for this model and year.")
        end

        # ----------------------------------------------------------------------
        # Socioeconomic

        # filter the dataframe for values with the year matching timestep
        # t and only the SSP countries found in the model countries list,
        # already checked that all model countries are in SSP countries list
        subset = g_ssp_datasets[ssp_dict_key] |>
            @filter(_.year == gettime(t) && _.country in p.country_names) |>
            DataFrame

        # get the ordered indices of the SSP countries within the parameter 
        # of the model countries, already checked that all model countries
        # are in SSP countries list
        order = indexin(p.country_names, subset.country)

        v.population[t,:] = subset.pop[order]
        v.gdp[t,:] = subset.gdp[order]
        
        # add global data for future accessibility and quality control
        v.population_global[t] = sum(v.population[t,:])
        v.gdp_global[t] = sum(v.gdp[t,:])

        # ----------------------------------------------------------------------
        # Emissions

        subset = g_emissions_scenario_datasets[emissions_scenario_dict_key] |>
                    @filter(_.year == gettime(t)) |>
                    DataFrame

        v.co2_emissions[t] = subset.carbon_dioxide[1]
        v.ch4_emissions[t] = subset.methane[1]
        v.n2o_emissions[t] = subset.nitrous_oxide[1]
        v.sf6_emissions[t] = subset.sf6[1]

    end
end
