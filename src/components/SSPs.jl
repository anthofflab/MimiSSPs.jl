
using Mimi, CSVFiles, DataFrames, Query, Interpolations

@defcomp SSPs begin

    countries = Index()

    model   = Parameter{String}() # can be one of IIASA GDP, OECD Env-Growth, and PIK GDP_32
    ssp     = Parameter{String}() # can be one of SSP1, SSP2, SSP3, SSP5

    # TODO double check units on gases, do we want any other gases or parameters?
    population      = Variable(index=[time,region], unit="million")
    gdp             = Variable(index=[time,region], unit="billion US\$2005/yr")

    co2_emissions   = Variable(index=[time], unit="GtC")
    ch4_emissions   = Variable(index=[time], unit="MtCH4")
    n2o_emissions   = Variable(index=[time], unit="MtN")
    sf6_emissions   = Variable(index=[time], unit="MtSF6")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Checks
        println("\n-- CHECKS --\n")

        model_options = ["IIASA GDP", "OECD Env-Growth", "PIK GDP_23"]
        !(p.model in model_options) && error("Model $(p.model) provided to SSPs component model parameter not found in available list: $(model_options)")
        ssp_options = ["SSP1", "SSP2", "SSP3", "SSP5"]
        !(p.ssp in ssp_options) && error("Model $(p.ssp) provided to SSPs component ssp parameter not found in available list: $(ssp_options)")

        # ----------------------------------------------------------------------
        # Settings
        println("\n-- SETTINGS --\n")

        emissions_path_dict = Dict(
            :SSP1 => "ssp126",  # paired with ssp1 RCP 2.6
            :SSP2 => "ssp245",  # paired with ssp2 RCP 4.5
            :SSP3 => "ssp370",  # paired with ssp3 RCP 3.70
            :SSP5 => "ssp585"   # paired with ssp5 RCP8.5
        )

        socioeconomic_path = joinpath(@__DIR__, "..", "..", "data", "socioeconomic", "ssp_projections_$(p.model)_$(p.ssp).csv")
        emissions_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "rcmip_$(emissions_path_dict[Symbol(p.ssp)])_emissions_1750_to_2500.csv")

        # ----------------------------------------------------------------------
        # Load Data as Needed
        println("\n-- LOAD DATA --\n")

        key = Symbol(p.model, "-", p.ssp)
        if !haskey(g_datasets, key)

            # interpolate socioeconomic data to annual
            
            # TODO we can do this outside of the function in calibration, but for 
            # now it's cleaner to keep input data as Bryan's outputs with units etc.
            # and do this here -- it is quite fast and only done once per dataset key

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
            g_datasets[key] = Dict(
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
        # Output Variables

        # d is a DimValueDict where most keys have the labels of that dimension,
        # but :time is a vector of AbstractTimesteps, each of which we can call
        # Mimi.gettime on to get the year

        ## SOCIOECONOMIC -- annual 2010 to 2015 by IIASA 3-letter country code
        # TOOD we have missing data for some countries
        println("\n-- SETTING SOCIOECONOMIC DATA --\n")

        # loop over all model timesteps (years)
        for t in d.time
            println("running time $(gettime(t))")
            if gettime(t) in unique(g_datasets[key][:socioeconomic].year)

                # loop over all model regions (countries)
                for c in d.countries
                    if c in unique(g_datasets[key][:socioeconomic].region) # only proceed if this country is in the data

                        v.population[t, c] = (g_datasets[key][:socioeconomic] |>
                                        @filter(_.year == gettime(t) && _.region == c) |>
                                        DataFrame).pop
                        
                        v.gdp[t, c] = (g_datasets[key][:socioeconomic] |>
                                        @filter(_.year == gettime(t) && _.region == c) |>
                                        DataFrame).pop

                    end
                end
            end
        end

        ## EMISSIONS -- annual 1750 to 2500
        println("\n-- SETTING EMISSIONS DATA --\n")

        for t in d.time
            if gettime(t) in unique(g_datasets[key][:emissions].year)

                v.co2_emissions[t] = (g_datasets[key][:emissions] |>
                                    @filter(_.year == gettime(t)) |>
                                    DataFrame).carbon_dioxide
                v.ch4_emissions[t] = (g_datasets[key][:emissions] |>
                                    @filter(_.year == gettime(t)) |>
                                    DataFrame).methane
                v.n2o_emissions[t] = (g_datasets[key][:emissions] |>
                                    @filter(_.year == gettime(t)) |>
                                    DataFrame).nitrous_oxide
                v.sf6_emissions[t] = (g_datasets[key][:emissions] |>
                                    @filter(_.year == gettime(t)) |>
                                    DataFrame).sf6

            end
        end
    end

    function run_timestep(p,v,d,t)
    end

end
