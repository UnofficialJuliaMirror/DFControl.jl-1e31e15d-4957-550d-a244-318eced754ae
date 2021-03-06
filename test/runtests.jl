using DFControl, Test, Suppressor

testdir = joinpath(dirname(dirname(pathof(DFControl))), "test")
@time begin
@time @testset "constants"         begin @suppress include("constant_tests.jl")      end
@time @testset "documenation"      begin @suppress include("documentation_tests.jl") end
@time @testset "Setting defaults"  begin @suppress include("defaults_tests.jl")      end
@time @testset "Job from CIF file" begin @suppress include("jobfromcif_tests.jl")    end
@time @testset "Job control tests" begin @suppress include("job_control_tests.jl")   end
@time @testset "Remove defaults"   begin @suppress include("rmdefaults_tests.jl")    end
end
