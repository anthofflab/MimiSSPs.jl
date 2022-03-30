# MimiSSPs.jl 

This repository holds a component using the [Mimi](https://www.mimiframework.org) framework which provides [Shared Socioeconomic Pathways](https://www.carbonbrief.org/explainer-how-shared-socioeconomic-pathways-explore-future-climate-change) parameters, including socioeconomic (population and GDP) and emissions (CO2, CH4, CH4, and SF6), to be connected with as desired with other Mimi components and run in Mimi models. More specifically, the model takes data inputs derived from the SSPs but necessarily with an annual timestep and at the country spatial resolution for socioeconomic variables and global spatial resolution for emissions.

The goal is a template where users can open a PR to add their own datasets, or do so locally, and employ the component.  We welcome this please feel free to open a PR, or an issue, to further discuss use cases or contributions. As repository authors **we do not** formally gaurantee the sources available, but do provide information on source, cited literature, pre-processing/post-processing, and calibration and require that from those hoping to add more options to the repository (which we welcome!).  

## Preparing the Software Environment

To add the package to your current environment, run the following command at the julia package REPL:
```julia
pkg> add https://github.com/anthofflab/MimiSSPs.jl.git
```
You probably also want to install the Mimi package into your julia environment, so that you can use some of the tools in there:
```
pkg> add Mimi
```

## Running the Model

The model uses the Mimi framework and it is highly recommended to read the Mimi documentation first to understand the code structure. This model presents two components, which will most often be used in tandem. The basic way to access the MimiSSPs components, both `SSPs` and `RegionAggregatorSum` and explore the results is the following:

```julia
using Mimi 
using MimiSSPs

# Create the a model
m = Model()

# Set the time dimension for the whole model, which can run longer than an individual component if desired
set_dimension!(m, :time, 1750:2300)

# Add the SSPs component as imported from `MimiSSPs`
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)

# Set country dimension and related parameter: this should indicate all the countries you wish to pull SSP data for, noting that you must provide a subset of the three-digit ISO country codes you can find here: `data/keys` with one file per model labeled <model>_ISO3.csv.  In this case we will use all of them for illustrative purposes.
all_countries = load(joinpath(@__DIR__, "data", "keys", "OECD Env-Growth_ISO3.csv")) |> DataFrame
set_dimension!(m, :country, all_countries.ISO3)
update_param!(m, :SSPs, :country_names, all_countries.ISO3) # should match the dimension

# Set parameters for `SSP_source`, `SSP`, `emissions_source`, and `emissions_scenario` (Strings for inputs) as well as the country names, which should be a copy of what was used ot set the `countries` dimension
update_param!(m, :SSPs, :SSP_source, "Benveniste")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :emissions_source, "Leach")
update_param!(m, :SSPs, :emissions_scenario, "SSP119")

# Run the model
run(m)

# Explore interactive plots of all the model output.
explore(m)

# Access a specific variable
ssp_emissions = m[:SSPs, :gdp]
```

Now say you want to connect the `m[:SSPs, :population]` output variable to another Mimi component that requires population at a regional level.  This is where the `RegionAggregatorSum` component can be helpful, which, as the name indicates, aggregates countries to regions with a provided mapping via the `sum` function (other functions can be added as desired, this is a relatively new and nimble component).  You will need to provide a mapping between the input regions (countries here) and output regions (regions here) in a Vector of the length of the input regions and each element being one of the output regions.

```julia
# Start with the model `m` from above and add the component with the name `:PopulationAggregator`
add_comp!(m, MimiSSPs.RegionAggregatorSum, :PopulationAggregator, first = 2010, last = 2300)

# Bring in a dummy mapping between the countries list from the model above and our current one. Note that this DataFrame has two columns, `InputRegion` and `OutputRegion`, where `InputRegion` is identical to `all_countries.ISO3` above but we will reset here for clarity.
mapping = load(joinpath(@__DIR__, "data", "keys", "OECD Env-Growth_dummyInputOutput.csv")) |> DataFrame
inputregions = mapping.Input_Region
outputregions = sort(unique(mapping.Output_Region))

# Set the region dimensions
set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

# Provide the mapping parameter as well as the the names of the input regions and output regions, which should just take copies of what you provided to `set_dimension!` above
update_param!(m, :PopulationAggregator, :input_region_names, inputregions)
update_param!(m, :PopulationAggregator, :output_region_names, outputregions)
update_param!(m, :PopulationAggregator, :input_output_mapping, mapping.Output_Region) # Vector with length of input regions, each element matching an output region in the output_region_names parameter (and outputregions dimension)

# Make SSPs component `:population` variable the feed into the `:input` variable of the `PopulationAggregator` component
connect_param!(m, :PopulationAggregator, :input, :SSPs, :population)

run(m)

# View the aggregated population variable, aggregated from 171 countries to 11 regions
getdataframe(m, :PopulationAggregator, :output)

```

## Data and Calibration

As shown above, the `SSPs` component imports the following with the following options. For contextual information and details see [Carbon Brief](https://www.carbonbrief.org/explainer-how-shared-socioeconomic-pathways-explore-future-climate-change).


1. socioeconomic data for which the user specifies (1) a SSP source and (2) an SSP
* `SSP_source` options: Benveniste, IIASA GDP*, OECD Env-Growth*, PIK GDP_32*
* `SSP` option: SSP1, SSP2, SSP3, SSP4, SSP5

_***IMPORTANT** Please note that the IIASA GDP, OECD Env-Growth, and PIK GDP_23 options are currently experimental implementations of Kikstra et al., 2021 and are under development, we advise using Benveniste for now and contacting the authors of this repository if you are interested in using the other three._

2. emissions data for which the user specifies (1) an emissions source and (2) an emissions scenario made up an SSP **combined** with a mitigation target as defined by a Representative Concentration Pathway (RCP).
* `emissions_scenario` options: Leach
* `emissions_source` options:  SSP119, SSP126, SSP245, SSP370, SSP585

### Data Sources

The available SSP sources are as follows:

* Benvensite: Benveniste, H., Oppenheimer, M., & Fleurbaey, M. (2020). Effect of border policy on exposure and vulnerability to climate change. Proceedings of the National Academy of Sciences, 117(43), 26692-26702.
* IIASA GDP, OECD Env-Growth, PIK GDP-32: these models draw directly from the IIASA Database [here](https://tntcat.iiasa.ac.at/SspDb/dsd?Action=htmlpage&page=10) from Riahi et al., 2017 and proceed to post-process the data according to a procedure outlined in the Github Repository [openmodels/SSP-Extensions](https://github.com/openmodels/SSP-Extensions), cited in [Kikstra et al., 2021](http://dx.doi.org/10.1088/1748-9326/ac1d0b) and described/replicated in detail in `calibration/src/Kikstra_Rising.ipynb`.  Again, as stated above, **please note** that these three options are currently experimental implementations of Kikstra et al., 2021 and are under development, we advise using Benveniste for now and contacting the authors of this repository if you are interested in using the other three.

The available emissions sources are as follows:

* Leach: This model draws data directly from the FAIRv2.0 model repository [here](https://github.com/FrankErrickson/MimiFAIRv2.jl) and originally published in [Leach et al., 2021](https://doi.org/10.5194/gmd-14-3007-2021), see `calibration/src/Leach.ipynb` for replication.

### Calibration and Data Processing

For futher information on each of these data sources and the related data processing that produces the files the `SSPs` component draws from see the `calibration` folder

SSP models:

* IIASA GDP, OECD Env-Growth, PIK GDP_23: `calibration/src/Kikstra-Rising_Calibration.ipynb` (_in progress, not all replication code available yet_)
* Benvensite: `calibration/Benveniste/Benveniste_Calibration.ipynb` and Benveniste et al., 2020 replication code

Emissions Sources:
 
* Leach: `calibration/Leach/Leach_Calibration.ipynb` and Leach et al. 2021 replication code

## News/Upcoming

* We have preliminary emissions data from Benveniste et al., 2020 available, although these run 1950 to 3000 and are only available for the one gas (not CH4, N2O, and SF6) so we have not yet determined how to properly incorporate them
