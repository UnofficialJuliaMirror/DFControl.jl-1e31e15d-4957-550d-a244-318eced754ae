using DFControl
import DFControl: searchdir, QEVariableInfo, QEControlBlockInfo, QEInputInfo, QEDataBlockInfo, qevariable

qeassetpath = joinpath(Pkg.dir("DFControl"), "assets/inputs/qe/")
inputinfos = begin
    file_paths = qeassetpath .* searchdir(qeassetpath, "INPUT")
    QEInputInfo.(file_paths)
end


@test qevariable(inputinfos[2], :calculation).typ == Void
@test qevariable(inputinfos[3], :calculation).typ == qevariable(:calculation).typ