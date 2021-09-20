using Mimi

@defcomp RegionAggregatorSum begin
    countries = Dimension()
    regions = Dimension()

    region_mapping::Dict{Symbol,Vector{Symbol}} = Parameter()
    input = Parameter(index=[time,inputregions])
    output = Parameter(index=[time,outputregions])
end
