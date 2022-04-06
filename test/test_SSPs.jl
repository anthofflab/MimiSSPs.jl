using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test, Missings
import MimiSSPs: SSPs

# BASIC API

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "OECD Env-Growth_ISO3.csv")) |> DataFrame

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :SSP_source, "OECD Env-Growth")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")
update_param!(m, :SSPs, :country_names, all_countries.ISO3)

run(m)

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3[1:10])
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :SSP_source, "OECD Env-Growth")
update_param!(m, :SSPs, :SSP, "SSP5")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP585")
update_param!(m, :SSPs, :country_names, all_countries.ISO3[1:10])

run(m)

# ERRORS

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiSSPs.SSPs)
update_param!(m, :SSPs, :SSP_source, "OECD Env-Growth")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")
update_param!(m, :SSPs, :country_names, all_countries.ISO3)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Cannot run SSP component in year 1750", error_msg)

dummy_countries = ["Sun", "Rain", "Cloud"]

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, dummy_countries)
add_comp!(m, MimiSSPs.SSPs)
update_param!(m, :SSPs, :SSP_source, "OECD Env-Growth")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")
update_param!(m, :SSPs, :country_names, dummy_countries) # error because countries aren't in SSP set

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("All countries in countries parameter must be found in SSPs component Socioeconomic Dataframe, the following were not found:", error_msg)

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :SSP_source, "NOT A MODEL")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")
update_param!(m, :SSPs, :country_names, all_countries.ISO3)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Model NOT A MODEL provided to SSPs component SSP_source parameter not found in available list:", error_msg)

update_param!(m, :SSPs, :SSP_source, "IIASA GDP")
update_param!(m, :SSPs, :SSP, "NOT A SSP")

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("SSP NOT A SSP provided to SSPs component SSP parameter not found in available list:", error_msg)

update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_scenario, "NOT A emissions_scenario")

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("emissions_scenario NOT A emissions_scenario provided to SSPs component emissions_scenario parameter not found in available list:", error_msg)

# VALIDATION

# Leach and Benveniste

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "Benveniste_ISO3.csv")) |> DataFrame

emissions_source = "Leach"
emissions_scenario = "SSP245"
SSP_source = "Benveniste"
SSP = "SSP2"

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiSSPs.SSPs, first = 1950, last = 2300)
update_param!(m, :SSPs, :SSP_source, SSP_source)
update_param!(m, :SSPs, :SSP, SSP)
update_param!(m, :SSPs, :emissions_source, emissions_source)
update_param!(m, :SSPs, :emissions_scenario, emissions_scenario)
update_param!(m, :SSPs, :country_names, all_countries.ISO3)

run(m)

emissions_path = joinpath(@__DIR__, "..", "data", "emissions", "$(emissions_source)_$(emissions_scenario).csv")
emissions_data = load(emissions_path, skiplines_begin = 6)|> 
    DataFrame |> 
    i -> rename!(i, Symbol.([:year, names(i)[2:end]...])) |> 
    DataFrame |>
    @select(:year, :carbon_dioxide, :nitrous_oxide, :methane, :sf6) |>
    DataFrame |>
    @filter(_.year in 1950:2300) |>
    DataFrame

@test m[:SSPs, :co2_emissions][findfirst(i -> i == 1950, collect(1750:2300)):end] ≈ emissions_data.carbon_dioxide  atol = 1e-9
@test m[:SSPs, :ch4_emissions][findfirst(i -> i == 1950, collect(1750:2300)):end] ≈ emissions_data.methane  atol = 1e-9
@test m[:SSPs, :sf6_emissions][findfirst(i -> i == 1950, collect(1750:2300)):end] ≈ emissions_data.sf6  atol = 1e-9
@test m[:SSPs, :n2o_emissions][findfirst(i -> i == 1950, collect(1750:2300)):end] ≈ emissions_data.nitrous_oxide atol = 1e-9

socioeconomic_path = joinpath(@__DIR__, "..", "data", "socioeconomic", "$(SSP_source)_$(SSP).csv")
socioeconomic_data = load(socioeconomic_path) |> DataFrame

for country in all_countries.ISO3

    pop_data_model = getdataframe(m, :SSPs, :population) |>
        @filter(_.time in collect(1950:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    gdp_data_model = getdataframe(m, :SSPs, :gdp) |>
        @filter(_.time in collect(1950:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    socioeconomic_data_country = socioeconomic_data |>
        @filter(_.year in collect(1950:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:year) |>
        DataFrame

    @test pop_data_model.population  ≈ socioeconomic_data_country.pop  atol = 1e-9
    @test collect(skipmissing(gdp_data_model.gdp))  ≈ collect(skipmissing(socioeconomic_data_country.gdp))  atol = 1e-9 # some missing data ex. TWN
end

# IIASA GDP and Leach

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "IIASA GDP_ISO3.csv")) |> DataFrame

emissions_source = "Leach"
emissions_scenario = "SSP245"
SSP_source = "IIASA GDP"
SSP = "SSP2"

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :SSP_source, SSP_source)
update_param!(m, :SSPs, :SSP, SSP)
update_param!(m, :SSPs, :emissions_source, emissions_source)
update_param!(m, :SSPs, :emissions_scenario, emissions_scenario)
update_param!(m, :SSPs, :country_names, all_countries.ISO3)

run(m)

Mimi.set_first_last!(m, :SSPs, first = 1950)
@test_throws ErrorException run(m) # can't run starting in 1950
Mimi.set_first_last!(m, :SSPs, first = 2010)
run(m)

emissions_path = joinpath(@__DIR__, "..", "data", "emissions", "$(emissions_source)_$(emissions_scenario).csv")
emissions_data = load(emissions_path, skiplines_begin = 6)|> 
    DataFrame |> 
    i -> rename!(i, Symbol.([:year, names(i)[2:end]...])) |> 
    DataFrame |>
    @select(:year, :carbon_dioxide, :nitrous_oxide, :methane, :sf6) |>
    DataFrame |>
    @filter(_.year in 2010:2300) |>
    DataFrame

@test m[:SSPs, :co2_emissions][findfirst(i -> i == 2010, collect(1750:2300)):end] ≈ emissions_data.carbon_dioxide  atol = 1e-9
@test m[:SSPs, :ch4_emissions][findfirst(i -> i == 2010, collect(1750:2300)):end] ≈ emissions_data.methane  atol = 1e-9
@test m[:SSPs, :sf6_emissions][findfirst(i -> i == 2010, collect(1750:2300)):end] ≈ emissions_data.sf6  atol = 1e-9
@test m[:SSPs, :n2o_emissions][findfirst(i -> i == 2010, collect(1750:2300)):end] ≈ emissions_data.nitrous_oxide atol = 1e-9

socioeconomic_path = joinpath(@__DIR__, "..", "data", "socioeconomic", "$(SSP_source)_$(SSP).csv")
socioeconomic_data = load(socioeconomic_path) |> DataFrame

for country in all_countries.ISO3

    pop_data_model = getdataframe(m, :SSPs, :population) |>
        @filter(_.time in collect(2010:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    gdp_data_model = getdataframe(m, :SSPs, :gdp) |>
        @filter(_.time in collect(2010:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    socioeconomic_data_country = socioeconomic_data |>
        @filter(_.year in collect(2010:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:year) |>
        DataFrame

    @test pop_data_model.population  ≈ socioeconomic_data_country.pop  atol = 1e-9
    @test gdp_data_model.gdp  ≈ socioeconomic_data_country.gdp  atol = 1e-9
end
