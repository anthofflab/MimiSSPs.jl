using Mimi, MimiSSPs, DataFrames, CSVFiles, Query, Test

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_ISO.csv")) |> DataFrame

# BASIC API

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "SSP1")
update_param!(m, :SSPs, :rcp, "RCP1.9")
update_param!(m, :SSPs, :country_names, all_countries.ISO)

run(m)

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :countries, all_countries.ISO[1:10])
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "SSP5")
update_param!(m, :SSPs, :rcp, "RCP8.5")
update_param!(m, :SSPs, :country_names, all_countries.ISO[1:10])

run(m)

# ERRORS

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiSSPs.SSPs)
update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "SSP1")
update_param!(m, :SSPs, :rcp, "RCP1.9")
update_param!(m, :SSPs, :country_names, all_countries.ISO)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Cannot run SSP component in year 1750", error_msg)

dummy_countries = ["Sun", "Rain", "Cloud"]

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :countries, dummy_countries)
add_comp!(m, MimiSSPs.SSPs)
update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "SSP1")
update_param!(m, :SSPs, :rcp, "RCP1.9")
update_param!(m, :SSPs, :country_names, dummy_countries) # error because countries aren't in SSP set

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("All countries in countries parameter must be found in SSPs component Socioeconomic Dataframe, the following were not found:", error_msg)

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :model, "NOT A MODEL")
update_param!(m, :SSPs, :ssp, "SSP1")
update_param!(m, :SSPs, :rcp, "RCP1.9")
update_param!(m, :SSPs, :country_names, all_countries.ISO)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Model NOT A MODEL provided to SSPs component model parameter not found in available list:", error_msg)

update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "NOT A SSP")

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("SSP NOT A SSP provided to SSPs component ssp parameter not found in available list:", error_msg)

update_param!(m, :SSPs, :ssp, "SSP1")
update_param!(m, :SSPs, :rcp, "NOT A RCP")

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("RCP NOT A RCP provided to SSPs component ssp parameter not found in available list:", error_msg)

# DATA OUTPUT CHECK
