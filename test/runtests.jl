using MessagePassingRulesBase
using Test
using Aqua
using JET
using TestItemRunner

@testset "MessagePassingRulesBase.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(MessagePassingRulesBase)
    end

    @testset "Code linting (JET.jl)" begin
        JET.test_package(MessagePassingRulesBase; target_defined_modules = true)
    end

    TestItemRunner.@run_package_tests()
end
