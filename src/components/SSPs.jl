
using Mimi, CSVFiles, DataFrames, Query, Interpolations

@defcomp SSPs begin

    country = Index()

    SSPmodel   = Parameter{String}() # can be one of IIASA GDP, OECD Env-Growth, PIK GDP_32, and Benveniste
    SSP     = Parameter{String}() # can be one of SSP1, SSP2, SSP3, SSP4, SSP5
    RCPmodel   = Parameter{String}() # can be one of Leach
    RCP     = Parameter{String}() # can be one of RCP1.9, RCP2.6, RCP4.5, RCP7.0, or RCP8.5

    country_names = Parameter{String}(index=[country]) # need the names of the countries from the dimension

    # TODO double check units on gases, do we want any other gases or parameters?
    population      = Variable(index=[time, country], unit="million")
    gdp             = Variable(index=[time, country], unit="billion US\$2005/yr")

    co2_emissions   = Variable(index=[time], unit="GtC/yr")
    ch4_emissions   = Variable(index=[time], unit="MtCH4/yr")
    n2o_emissions   = Variable(index=[time], unit="MtN/yr")
    sf6_emissions   = Variable(index=[time], unit="MtSF6/yr")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Checks

        ssp_model_options = ["IIASA GDP", "OECD Env-Growth", "PIK GDP_23", "Benveniste"]
        !(p.SSPmodel in ssp_model_options) && error("Model $(p.SSPmodel) provided to SSPs component SSPmodel parameter not found in available list: $(ssp_model_options)")
        
        ssp_options = ["SSP1", "SSP2", "SSP3", "SSP5"]
        !(p.SSP in ssp_options) && error("SSP $(p.SSP) provided to SSPs component SSP parameter not found in available list: $(ssp_options)")
        
        rcp_model_options = ["Leach"]
        !(p.RCPmodel in rcp_model_options) && error("Model $(p.RCPmodel) provided to SSPs component RCPmodel parameter not found in available list: $(rcp_model_options)")
        
        rcp_options = ["RCP1.9", "RCP2.6", "RCP7.0", "RCP4.5", "RCP8.5"]
        !(p.RCP in rcp_options) && error("RCP $(p.RCP) provided to SSPs component RCP parameter not found in available list: $(rcp_options)")

        # ----------------------------------------------------------------------
        # Load Socioeconomic Data as Needed
        #   population in millions of individuals
        #   GDP in billions of $2005 USD

        socioeconomic_path = joinpath(@__DIR__, "..", "..", "data", "socioeconomic", "$(p.SSPmodel)_$(p.SSP).csv")
        ssp_dict_key = Symbol(p.SSPmodel, "-", p.SSP)

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

        emissions_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "$(p.RCPmodel)_$(p.RCP).csv")
        rcp_dict_key = Symbol(p.RCPmodel, "-", p.RCP)

        if !haskey(g_rcp_datasets, rcp_dict_key)
            if p.RCPmodel == "Leach"
                emissions_data = load(emissions_path, skiplines_begin = 6)|> 
                        DataFrame |> 
                        i -> rename!(i, Symbol.([:year, names(i)[2:end]...])) |> 
                        DataFrame |>
                        @select(:year, :carbon_dioxide, :nitrous_oxide, :methane, :sf6) |>
                        DataFrame
            else # already perfect formatted
                emissions_data = load(emissions_path)|> DataFrame
            end

            g_rcp_datasets[rcp_dict_key]= emissions_data
        end       
    end

    function run_timestep(p,v,d,t)

        ssp_dict_key = Symbol(p.SSPmodel, "-", p.SSP)
        rcp_dict_key = Symbol(p.RCPmodel, "-", p.RCP)

        year_label = gettime(t)

        # check that we only run the component where we have data
        if !(year_label in g_ssp_datasets[ssp_dict_key].year)
            error("Cannot run SSP component in year $(year_label), SSP socioeconomic variables not available for this model and year.")
        end
        if !(year_label in g_rcp_datasets[rcp_dict_key].year)
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

        # ----------------------------------------------------------------------
        # Emissions

        subset = g_rcp_datasets[rcp_dict_key] |>
                    @filter(_.year == gettime(t)) |>
                    DataFrame

        v.co2_emissions[t] = subset.carbon_dioxide[1]
        v.ch4_emissions[t] = subset.methane[1]
        v.n2o_emissions[t] = subset.nitrous_oxide[1]
        v.sf6_emissions[t] = subset.sf6[1]

    end
end
