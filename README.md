# MimiSSPs.jl 

This repository holds a component using the [Mimi](https://www.mimiframework.org) framework which provides [Shared Socioeconomic Pathways](https://www.carbonbrief.org/explainer-how-shared-socioeconomic-pathways-explore-future-climate-change) parameters, including socioeconomic (population and GDP) and emissions (CO2, CH4, CH4, and SF6), to be connected with as desired with other Mimi components and run in Mimi models. More specifically, the model takes data inputs derived from the SSPs but necessarily with an annual timestep from XX through XX and at the country spatial resolution for socioeconomic variables and global spatial resolution for emissions.

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

```
using Mimi 
using MimiSSPs

# Create the a model
m = Model()

# Set dimensions, including time and the countries you wish to pull SSP data for, noting that you must provide a subset of the three-digit ISO country codes you can find here: `data/keys/MimiSSPs_ISO.csv`.  In this case we will use all of them for illustrative purposes.

set_dimension!(m, :time, 1750:2300)

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "MimiSSPs_ISO.csv")) |> DataFrame
set_dimension!(m, :countries, all_countries.ISO)

# Add the SSPs component as imported from `MimiSSPs`
add_comp!(m, MimiSSPs.SSPs, first = 2010, last = 2300)

# Set parameters for `SSPmodel`, `SSP`, and `RCP` (Strings for inputs) as well as the country names, which should be a copy of what was used ot set the `countries` dimension
update_param!(m, :SSPs, :SSPmodel, "IIASA GDP")
update_param!(m, :SSPs, :SSP, "SSP1")
update_param!(m, :SSPs, :SSPmodel, "Leach")
update_param!(m, :SSPs, :RCP, "RCP1.9")
update_param!(m, :SSPs, :country_names, all_countries.ISO)

# Run the model
run(m)

# Explore interactive plots of all the model output.
explore(m)

# Access a specific variable
ssp_emissions = m[:SSPs, :GDP]
```

## Data and Calibration

As shown above, the `SSPs` component imports socioeconomic data corresponding to a provided SSP model and SSP, and emissions data corresponding to RCP model and Representative Concentration Pathway (RCP).  Note that much work has been done to pair each RCP with an SSP, as described by [Carbon Brief](https://www.carbonbrief.org/explainer-how-shared-socioeconomic-pathways-explore-future-climate-change) so there are customary pairings as noted below, but we leave it to the user to decide which they wish to use.

* `SSP` option: SSP1, SSP2, SSP3, SSP4, SSP5
* `SSPmodel` options: IIASA GDP, OECD Env-Growth, PIK GDP_23, and Benveniste

* `RCP` options: RCP1.9 (suggested pairing with SSP1), RCP2.6 (suggested pairing with SSP1),  RCP4.5 (suggested pairing with SSP2), RCP6.0 (suggested pairing with SSP4), RCP7.0 (suggested pairing with SSP3), and RCP8.5 (suggested pairing with SSP5)
* `RCPmodel` options: Leach, Benveniste*

_* NOTE that this model only provides emissions for CO2, so if chosen the emissions for CH4, SF6, and N2O will be drawn from the Leach source by default_

### Data Sources

The available SSP models are sourced as follows:

* IIASA GDP, OECD Env-Growth, PIK GDP_23: these models draw directly from the IIASA Database [here](https://tntcat.iiasa.ac.at/SspDb/dsd?Action=htmlpage&page=10) and proceed to post-process the data according to a procedure outlined in the Github Repository [openmodels/SSP-Extensions](https://github.com/openmodels/SSP-Extensions), cited in [Kikstra et al., 2021](http://dx.doi.org/10.1088/1748-9326/ac1d0b) and described/replicated in detail in `calibration/src/Kikstra_Rising.ipynb`
* Benvensite: see []()

The available RCP models are sourced as follows:

* Leach: This model draws data directly from the FAIRv2.0 model repository [here](https://github.com/FrankErrickson/MimiFAIRv2.jl) and originally published in [Leach et al., 2021](https://doi.org/10.5194/gmd-14-3007-2021), see `calibration/src/Leach.ipynb` for replication.
* Benvensite*: see [Benveniste et al., 2020](https://doi.org/10.1073/pnas.2007597117)

_* NOTE that this model only provides emissions for CO2, so if chosen the emissions for CH4, SF6, and N2O will be drawn from the Leach source by default_

### Calibration and Data Processing

For futher information on each of these data sources and the related data processing that produces the files the `SSPs` component draws from see the `calibration` folder

SSP models:

* IIASA GDP, OECD Env-Growth, PIK GDP_23: `calibration/src/Kikstra-Rising_Calibration.ipynb` and Kikstra et al. 2021 replication code
* Benvensite: `calibration/Benveniste/Benveniste_Calibration.ipynb` and Benveniste et al., 2020 replication code

RCP Models:
 
* Leach: `calibration/Leach/Leach_Calibration.ipynb` and Leach et al. 2021 replication code
* Benvensite: `calibration/Benveniste/Benveniste_Calibration.ipynb` and Benveniste et al., 2020 replication code
