#here all the different input structures for the different calculations go
#TODO should we also create a config file for each job with stuff like server etc? and other config things,
#      which if not supplied could contain the default stuff?
"""
Represents a full DFT job with multiple input files and calculations.
"""
mutable struct DFJob
    id           ::Int #REVIEW: For now ID does nothing but I can see it doing things later
    name         ::String
    structure    ::AbstractStructure
    inputs       ::Vector{DFInput}
    local_dir    ::String
    server       ::String
    server_dir   ::String
    header       ::Vector{String}
    metadata     ::Dict
    function DFJob(name, structure, calculations, local_dir, server, server_dir, header = getdefault_jobheader())
        if local_dir != ""
            local_dir = local_dir
        end

        if server_dir != ""
            server_dir = server_dir
        end
        if !isabspath(local_dir)
            local_dir = abspath(local_dir)
        end
        return new(0, name, structure, calculations, local_dir, server, server_dir, header, Dict())
    end
end

#TODO implement abinit
function DFJob(job_name, local_dir, structure::AbstractStructure, calculations::Vector, common_flags...;
                    server=getdefault_server(),
                    server_dir="",
                    package=QE,
                    bin_dir=joinpath("usr","local","bin"),
                    pseudoset=:default,
                    pseudospecifier="",
                    header=getdefault_jobheader())

    @assert package==QE "Only implemented for Quantum Espresso!"

    job_calcs = DFInput[]
    if typeof(common_flags) != Dict
        common_flags = Dict(common_flags)
    end
    bin_dir = bin_dir
    for (calc, (excs, data)) in calculations
        calc_ = typeof(calc) == String ? Symbol(calc) : calc
        if in(calc_, [:vc_relax, :relax, :scf])
            k_points = get(data, :k_points, [1, 1, 1, 0, 0, 0])
            k_option = :automatic
        elseif calc_ == :nscf
            k_points = kgrid(get(data, :k_points, [1, 1, 1])[1:3]..., QE)
            k_option = :crystal
        elseif calc_ == :bands
            k_points = get(data, :k_points, [[0., 0., 0., 1.]])
            num_k = 0.0
            for point in k_points
                num_k += point[4]
            end
            if num_k > 100.
                if !haskey(data, :flags)
                    data[:flags] = Pair{Symbol, Any}[]
                end
                push!(data[:flags], :verbosity => "high")
            end
            k_option = :crystal_b
        end
        flags  = convert(Vector{Pair{Symbol, Any}}, get(data, :flags, Pair{Symbol, Any}[]))
        if excs[2].exec == "pw.x"
            push!(flags, :calculation => "$(string(calc_))")
            datablocks = [InputData(:k_points, k_option, k_points)]
        else
            datablocks =  InputData[]
        end
        input_ = DFInput{package}(string(calc_), local_dir,
                         Dict{Symbol, Any}(),
                         datablocks, excs, true)
        setflags!(input_, common_flags..., print=false) #This could be changed to use suppressor
        setflags!(input_, flags..., print=false)
        push!(job_calcs, input_)
    end
    out = DFJob(job_name, structure, job_calcs, local_dir, server, server_dir, header)
    setatoms!(out, structure.atoms, pseudoset = pseudoset, pseudospecifier= pseudospecifier)
    if !haskey(common_flags, :ecutwfc)
        @info "No :ecutwfc specified in the flags, determining minimum cutoff from pseudos."
        setcutoffs!(out)
    end
    return out
end

function DFJob(job_name, local_dir, ciffile::String, calculations::Vector, args...; kwargs...)
    structure = Structure(ciffile, name=job_name)
    return DFJob(job_name, local_dir, structure, calculations, args... ; kwargs...)
end

function DFJob(job::DFJob, flagstoset...; cell_=copy(cell(job)), atoms_=copy(atoms(job)), name=job.name,
                                          server_dir = job.server_dir,
                                          local_dir  = job.local_dir,
                                          pseudoset  = nothing,
                                          pseudospecifier = "")
    newjob = deepcopy(job)

    setcell!(newjob, cell_)
    if pseudoset == nothing
        pseudoset, specifier = getpseudoset(job.structure.atoms[1])
        specifier = pseudospecifier == nothing ? specifier : pseudospecifier
        setatoms!(newjob, atoms_, pseudoset = pseudoset, pseudospecifier=specifier)
    else
        setatoms!(newjob, atoms_, pseudoset = pseudoset, pseudospecifier= pseudospecifier)
    end
    setserverdir!(newjob, server_dir)
    setlocaldir!(newjob, local_dir)
    newjob.name = name

    setflags!(newjob, flagstoset..., print=false)
    return newjob
end

"""
    DFJob(job_dir::String, T=Float64; job_fuzzy = "job", new_job_name=nothing, new_local_dir=nothing, server=getdefault_server(),server_dir="")

Loads and returns a local DFJob. If local_dir is not specified the job directory will be registered as the local one.
"""
function DFJob(job_dir::String, T=Float64;
                  job_fuzzy     = "job",
                  new_job_name  = "",
                  new_local_dir = nothing,
                  server        = getdefault_server(),
                  server_dir    = "")
    name, header, inputs, structure = read_job_inputs(joinpath(job_dir, searchdir(job_dir, job_fuzzy)[1]))
    j_name = isempty(new_job_name) ? name : new_job_name
    structure_name = split(j_name, "_")[1]
    structure.name = structure_name

    if new_local_dir != nothing
        return DFJob(j_name, structure, inputs, new_local_dir, server, server_dir, header)
    else
        return DFJob(j_name, structure, inputs, job_dir, server, server_dir, header)
    end
end

"""
    DFJob(server_dir::String, local_dir::String, server=getdefault_server(); job_fuzzy="*job*", new_job_name="")

Pulls a server job to local directory and then loads it. A fuzzy search for the job file will be performed and the found input files will be pulled.
"""
function DFJob(server_dir::String, local_dir::String, server = getdefault_server();
                         job_fuzzy    = "*job*",
                         new_job_name = "")

    pulljob(server, server_dir, local_dir)
    return DFJob(local_dir, server=server, server_dir=server_dir, new_job_name=new_job_name)
end

#-------------------BEGINNING GENERAL SECTION-------------#
scriptpath(job::DFJob) = joinpath(job.local_dir, "job.tt")
starttime(job::DFJob) = mtime(scriptpath(job))

runslocal(job::DFJob) = job.server=="localhost"
structure(job::DFJob) = job.structure
iswannierjob(job::DFJob) = any(x->package(x) == Wannier90, inputs(job)) && any(x->flag(x, :calculation) == "nscf", inputs(job))
getnscfcalc(job::DFJob) = getfirst(x->flag(x, :calculation) == "nscf", inputs(job))
cell(job::DFJob) = cell(structure(job))

input(job::DFJob, n::String) = getfirst(x -> occursin(n, name(x)), inputs(job))
inputs(job::DFJob) = job.inputs

"""
    inputs(job::DFJob, names::Vector)

Returns an array of the inputs that match the names.
"""
inputs(job::DFJob, names::Vector, fuzzy=true) = fuzzy ? filter(x -> any(occursin.(names, name(x))), inputs(job)) : input.(job, names)
inputs(job::DFJob, n::String, fuzzy=true) = inputs(job, [n], fuzzy)
inputs(job::DFJob, package_::Package) = filter(x->package(x)==package_, inputs(job))
inpath(job::DFJob, n) = inpath(input(job,n))
outpath(job::DFJob, n) = outpath(input(job,n))

"Runs some checks on the set flags for the inputs in the job, and sets metadata (:prefix, :outdir etc) related flags to the correct ones. It also checks whether flags in the various inputs are allowed and set to the correct types."
function sanitizeflags!(job::DFJob)
    setflags!(job, :prefix => "$(job.name)", print=false)
    if iswannierjob(job)
        setflags!(job, :num_bands => flag(getnscfcalc(job), :nbnd), print=false)
    end
    sanitizeflags!.(inputs(job))
end

"Checks the last created output file for a certain job."
function runninginput(job::DFJob)
    @assert job.server == "localhost" "Intended use for now is locally."
    t = mtime(scriptpath(job))
    for i in reverse(inputs(job))
        p = outpath(i)
        if ispath(p) && mtime(p) > t
            return i
        end
    end
end

"Finds the input corresponding to the name and returns the full output path."
outpath(job::DFJob, n::String) = outpath(input(job,n))

runslocal_assert(job::DFJob) =
    @assert runslocal(job) "This only works if the job runs on `localhost`."
