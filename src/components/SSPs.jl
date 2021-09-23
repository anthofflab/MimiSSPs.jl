
using Mimi, CSVFiles, DataFrames, Query, Interpolations

@defcomp SSPs begin

    model   = Parameter{String}() # can be one of IIASA GDP, OECD Env-Growth, and PIK GDP_32
    ssp     = Parameter{String}() # can be one of SSP1, SSP2, SSP3, SSP5
    rcp     = Parameter{String}() # can be one of RCP1.9, RCP2.6, RCP3.7, RCP4.5, or RCP8.5

    country_names = Parameter{String}(index=[countries]) # need the names of the countries from the dimension

    # TODO double check units on gases, do we want any other gases or parameters?
    population      = Variable(index=[time, countries], unit="million")
    gdp             = Variable(index=[time, countries], unit="billion US\$2005/yr")

    co2_emissions   = Variable(index=[time], unit="GtC")
    ch4_emissions   = Variable(index=[time], unit="MtCH4")
    n2o_emissions   = Variable(index=[time], unit="MtN")
    sf6_emissions   = Variable(index=[time], unit="MtSF6")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Checks

        model_options = ["IIASA GDP", "OECD Env-Growth", "PIK GDP_23"]
        !(p.model in model_options) && error("Model $(p.model) provided to SSPs component model parameter not found in available list: $(model_options)")
        
        ssp_options = ["SSP1", "SSP2", "SSP3", "SSP5"]
        !(p.ssp in ssp_options) && error("SSP $(p.ssp) provided to SSPs component ssp parameter not found in available list: $(ssp_options)")

        rcp_options = ["RCP1.9", "RCP2.6", "RCP3.7", "RCP4.5", "RCP8.5"]
        !(p.rcp in rcp_options) && error("RCP $(p.rcp) provided to SSPs component rcp parameter not found in available list: $(rcp_options)")

        # ----------------------------------------------------------------------
        # Settings

        emissions_path_keys = Dict(
            "RCP1.9" => "ssp119",  # generally paired with SSP1
            "RCP2.6" => "ssp126",  # generally paired with SSP1
            "RCP4.5"=> "ssp245",  # generally paired with SSP2
            "RCP3.7" => "ssp370",  # generally paired with SSP3
            "RCP8.5" => "ssp585"   # generally paired with SSP4
        )

        socioeconomic_path = joinpath(@__DIR__, "..", "..", "data", "socioeconomic", "ssp_projections_$(p.model)_$(p.ssp).csv")
        emissions_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "rcmip_$(emissions_path_keys[p.ssp])_emissions_1750_to_2500.csv")

        # ----------------------------------------------------------------------
        # Load Data as Needed

        dict_key = Symbol(p.model, "-", p.ssp)
        if !haskey(g_datasets, dict_key)

            # interpolate socioeconomic data to annual

            socioeconomic_data = load(socioeconomic_path) |> 
                DataFrame|> 
                @select(:year, :region, :pop, :gdp) |>
                DataFrame

            socioeconomic_data_interp = DataFrame(:year => [], :region => [], :pop => [], :gdp => [])
            all_years = collect(minimum(socioeconomic_data.year):maximum(socioeconomic_data.year))
            for region in unique(socioeconomic_data.region)

                region_data = socioeconomic_data |> @filter(_.region == region) |> @orderby(:year) |> DataFrame
                pop_itp = LinearInterpolation(region_data.year, region_data.pop)
                gdp_itp = LinearInterpolation(region_data.year, region_data.gdp)   
                
                append!(socioeconomic_data_interp, DataFrame(
                    :year => all_years,
                    :region => fill(region, length(all_years)),
                    :pop => pop_itp[all_years],
                    :gdp => gdp_itp[all_years]
                ))
            end
            for (i, type) in enumerate([Int64, String, Float64, Float64])
                socioeconomic_data_interp[:,i] = convert.(type, socioeconomic_data_interp[:,i])
            end

            # add interpolated socioeconomic data, and emissions data which is already
            # annual, to the datasets global variable
            g_datasets[dict_key] = Dict(
                :socioeconomic => socioeconomic_data_interp,
                :emissions => load(emissions_path, skiplines_begin = 6)|> 
                    DataFrame |> 
                    i -> rename!(i, Symbol.([:year, names(i)[2:end]...])) |> 
                    DataFrame |>
                    @select(:year, :carbon_dioxide, :nitrous_oxide, :methane, :sf6) |>
                    DataFrame
                )
        end

        # ----------------------------------------------------------------------
        # Check Countries - each country found in the model countries parameter
        # must exist in the ssp socioeconomics dataframe 

        missing_countries = []
        for country in p.country_names
            !(country in unique(g_datasets[dict_key][:socioeconomic].region)) && push!(missing_countries, country)
        end
        !isempty(missing_countries) && error("All countries in countries parameter must be found in SSPs component Socioeconomic Dataframe, the following were not found: $(missing_countries)")
    end

    function run_timestep(p,v,d,t)

        dict_key = Symbol(p.model, "-", p.ssp)
        year_label = gettime(t)

        # check that we only run the component where we have data
        if !(year_label in unique(g_datasets[dict_key][:socioeconomic].year))
            error("Cannot run SSP component in year $(year_label), SSP socioeconomic variables only available for 2010 through 2300.")
        end
        if !(year_label in unique(g_datasets[dict_key][:emissions].year))
            error("Cannot run SSP component in year $(year_label), SSP emissions variables only available for 1750 through 2500.")
        end

        # ----------------------------------------------------------------------
        # Socioeconomic

        # filter the dataframe for values with the year matching timestep
        # t and only the ssp countries found in the model countries list,
        # already checked that all model countries are in ssp countries list
        subset = g_datasets[dict_key][:socioeconomic] |>
            @filter(_.year == gettime(t) && _.region in p.country_names) |>
            DataFrame

        # get the ordered indices of the ssp countries within the parameter 
        # of the model countries, already checked that all model countries
        # are in ssp countries list
        order = indexin(p.country_names, subset.region)

        v.population[t,:] = subset.pop[order]
        v.gdp[t,:] = subset.gdp[order]

        # ----------------------------------------------------------------------
        # Emissions

        subset = g_datasets[dict_key][:emissions] |>
                    @filter(_.year == gettime(t)) |>
                    DataFrame

        v.co2_emissions[t] = subset.carbon_dioxide[1]
        v.ch4_emissions[t] = subset.methane[1]
        v.n2o_emissions[t] = subset.nitrous_oxide[1]
        v.sf6_emissions[t] = subset.sf6[1]

    end
end
