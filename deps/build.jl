using BinDeps
if !isdir(joinpath(@__DIR__,"..", "user_defaults"))
    mkdir(joinpath(@__DIR__,"..", "user_defaults"))
end

if !ispath(joinpath(@__DIR__,"..", "user_defaults", "user_defaults.jl"))
    open(joinpath(@__DIR__,"..", "user_defaults", "user_defaults.jl"), "w") do f
        write(f,"#Generated by DFControl.")
    end
end

relpath = x -> joinpath(@__DIR__, x)
pythonpath = relpath("python2")
if !ispath(pythonpath)
    mkdir(pythonpath)
    dlpath = relpath("downloads")
    if !ispath(dlpath)
        mkdir(dlpath)
    end
    #From Conda installation
    url = "https://repo.continuum.io/miniconda/Miniconda2-latest-"
    if Sys.isapple()
        url *= "MacOSX"
    elseif Sys.islinux()
        url *= "Linux"
    elseif Sys.iswindows()
        url = "https://repo.continuum.io/miniconda/Miniconda2-4.5.4-"
        url *= "Windows"
    else
        error("Unsuported OS.")
    end
    url *= Sys.WORD_SIZE == 64 ? "-x86_64" : "-x86"
    url *= Sys.iswindows() ? ".exe" : ".sh"

    if Sys.isunix()
        installer = joinpath(dlpath, "installer.sh")
    end
    if Sys.iswindows()
        installer = joinpath(dlpath, "installer.exe")
    end
    download(url, installer)
    if Sys.isunix()
        chmod(installer, 33261)  # 33261 corresponds to 755 mode of the 'chmod' program
        run(`$installer -b -f -p $pythonpath`)
    end
    if Sys.iswindows()
        run(Cmd(`$installer /S /AddToPath=0 /RegisterPython=0 /D=$pythonpath`, windows_verbatim=true))
    end

    tarpath = relpath("cif2cell.tar.gz")
    download("https://sourceforge.net/projects/cif2cell/files/latest/download", tarpath)
    run(unpack_cmd("cif2cell.tar.gz", @__DIR__, ".gz",".tar"))
    cif2celldir = relpath("cif2cell-1.2.10")
    cd(cif2celldir)
    pyex = Sys.iswindows() ? joinpath(pythonpath, "python") : joinpath(pythonpath, "bin", "python2")
    run(`$pyex setup.py install --prefix=$pythonpath`)
    cd("..")
#stupid urlopen
    starfile = Sys.iswindows() ? joinpath(pythonpath, "lib", "site-packages", "StarFile.py") : joinpath(pythonpath, "lib", "python2.7", "site-packages", "StarFile.py")
    starsource = read(starfile, String)
    starsource = replace(starsource, "filestream = urlopen(filename)"=>"filestream = urlopen('file:' + filename)")
    write(starfile, starsource)
#
    rm(tarpath)
    rm(relpath("cif2cell-1.2.10"), recursive=true)
    rm(relpath("downloads"), recursive=true)
end

include("asset_init.jl")
