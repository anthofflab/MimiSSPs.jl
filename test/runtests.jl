using Test

@testset "SSPs Component" begin
    include("test_SSPs.jl")
end

@testset "RegionAggregatorSum Component" begin
    include("test_RegionAggregatorSum.jl")
end

@testset "Coupled" begin
    include("test_Coupled.jl")
end
