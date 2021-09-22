using Mimi, MimiSSPs, DataFrames, CSVFiles

regions = load(joinpath(@__DIR__, "..", "data", "ISO3166-1_codes_and_country_names.csv")) |> DataFrame

m = Model()
set_dimension!(m, :time, 1750:2300)
set_dimension!(m, :region, regions.ISO)
set_dimension!(m, :countries, regions.ISO)

add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)
update_param!(m, :SSPs, :model, "IIASA GDP")
update_param!(m, :SSPs, :ssp, "SSP1")

run(m)
