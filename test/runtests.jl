using CassandraBacktest
using SafeTestsets
using Test

@safetestset "Router" begin
    include("router_test.jl")
end

@safetestset "Runner" begin
    include("runner_test.jl")
end
