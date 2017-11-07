"Point in 3D space in cartesian coordinates with specified float type"
struct Point3D{T<:AbstractFloat}
  x::T
  y::T
  z::T
end
(Point3D(x::T) where T<:AbstractFloat) = Point3D(T(x),T(x),T(x))
Point3D(::Type{T},x) where T<:AbstractFloat = Point3D(T(x),T(x),T(x))
Point3D(x::Array{<:AbstractFloat,1}) = Point3D(x[1],x[2],x[3])

import Base: +, -, *, /, convert, promote_rule, show, zero, norm
+(x::Point3D,y::Point3D) = Point3D(x.x+y.x,x.y+y.y,x.z+y.z)
+(y::Number,x::Point3D) = Point3D(x.x+y,x.y+y,x.z+y)
+(x::Point3D,y::Number) = Point3D(x.x+y,x.y+y,x.z+y)
-(x::Point3D,y::Point3D) = Point3D(x.x-y.x,x.y-y.y,x.z-y.z)
-(y::Number,x::Point3D) = Point3D(x.x-y,x.y-y,x.z-y)
*(x::Point3D,y::Point3D) = Point3D(x.x*y.x,x.y*y.y,x.z*y.z)
*(x::Point3D,y::Number) = Point3D(x.x*y,x.y*y,x.z*y)
*(y::Number,x::Point3D) = Point3D(x.x*y,x.y*y,x.z*y)
/(a::Point3D,b::Point3D) = Point3D(a.x/b.x,a.y/b.y,a.z/b.z)
/(a::Point3D,b::Number) = Point3D(a.x/b,a.y/b,a.z/b)
@inline norm(a::Point3D) = sqrt(a.x^2+a.y^2+a.z^2)
zero(::Type{Point3D{T}}) where T = Point3D(zero(T),zero(T),zero(T))
zero(::Type{Point3D}) = Point3D(zero(Float64),zero(Float64),zero(Float64))

convert(::Type{Point3D},x::Point3D) = x
convert(::Type{Array},x::Point3D) = [x.x,x.y,x.z]
convert(::Type{Point3D},x::T) where T<:AbstractFloat = Point3D{T}(x,x,x)
convert(::Type{Point3D{T}},x::Real) where T<:AbstractFloat = Point3D{T}(x,x,x)
convert(::Type{Point3D{T}},x::Point3D) where T<:AbstractFloat = Point3D{T}(x.x,x.y,x.z)
convert(::Type{Point3D{T}},x::Array{T,1}) where T<:AbstractFloat = Point3D{T}(x[1],x[2],x[3])
promote_rule(::Type{Point3D{S}},::Type{Point3D{T}}) where {S<:AbstractFloat,T<:AbstractFloat} = Point3D{promote_type(S,T)}
promote_rule(::Type{Point3D{S}},::Type{T}) where {S<:AbstractFloat,T<:Real} = Point3D{promote_type(S,T)}

show(io::IO,x::Point3D)=print(io,"x = $(x.x), y = $(x.y), z = $(x.z)")

abstract type Band end

"""
Energy band from DFT calculation.
"""
mutable struct DFBand{T<:AbstractFloat} <: Band
  k_points_cart::Array{Array{T,1},1}
  k_points_cryst::Array{Array{T,1},1}
  eigvals::Array{T,1}
end

function Base.display(band::DFBand{T}) where T <: AbstractFloat
  println("DFBand{$T}:")
  println("  k_points of length $(length(band.k_points_cart)):")
  println("    cart:  $(band.k_points_cart[1]) -> $(band.k_points_cart[end])")
  println("    cryst: $(band.k_points_cryst[1]) -> $(band.k_points_cryst[end])")
  println("  eigvals: $(band.eigvals[1]) -> $(band.eigvals[end])")
end

function Base.display(bands::Array{<:DFBand})
  map(display,bands)
end

#these are all the control blocks, they hold the flags that guide the calculation
abstract type Block end
abstract type ControlBlock<:Block end

mutable struct QEControlBlock<:ControlBlock
  name::Symbol
  flags::Dict{Symbol,Any}
end

function Base.display(block::ControlBlock)
  println("Block name: $(block.name)")
  println("Block flags:")
  display(block.flags)
end

#these are all the data blocks, they hold the specific data for the calculation
abstract type DataBlock<:Block end

mutable struct QEDataBlock <: DataBlock
  name::Symbol
  option::Symbol
  data::Any
end

mutable struct WannierDataBlock <: DataBlock
  name::Symbol
  option::Symbol
  data::Any
end

function Base.display(block::Block)
  println("Block name: $(block.name)")
  println("Block option: $(block.option)")
  println("Block data:")
  display(block.data)
  println("")
end

function Base.display(blocks::Array{<:Block})
  map(display,blocks)
end
#here all the different input structures for the different calculations go
"""
Represents an input for DFT calculation.

Fieldnames: backend::Symbol -> the DFT package that reads this input.
            control_blocks::Dict{Symbol,Dict{Symbol,Any}} -> maps different control blocks to their dict of flags and values.
            pseudos::Dict{Symbol,String} -> maps atom symbol to pseudo input file.
            cell_param::Dict{Symbol,Any} -> maps the option of cell_parameters to the cell parameters.
            atoms::Dict{Symbol,Any} -> maps atom symbol to position.
            k_points::Dict{Symbol,Any} -> maps option of k_points to k_points.
"""
abstract type DFInput end

mutable struct QEInput<:DFInput
  filename::String
  control_blocks::Array{QEControlBlock,1}
  data_blocks::Array{QEDataBlock,1}
  run_command::String  #everything before < in the job file
  run::Bool
end

mutable struct WannierInput<:DFInput
  filename::String
  flags::Dict{Symbol,Any}
  data_blocks::Array{WannierDataBlock,1}
  run_command::String
  run::Bool
  preprocess::Bool
end

function Base.display(input::DFInput)
  print_info(input)
end

"""
Represents a full DFT job with multiple input files and calculations.

Fieldnames: name::String
            calculations::Dict{String,DFInput} -> calculation type to DFInput
            flow::Array{Tuple{String,String},1} -> flow chart of calculations. The tuple is (calculation type, input file).
            local_dir::String -> directory on local machine.
            server::String -> server in full host@server t.
            server_dir::String -> directory on server.
"""
mutable struct DFJob
  name::String
  calculations::Array{DFInput,1}
  local_dir::String
  server::String
  server_dir::String
  function DFJob(name,calculations,local_dir,server,server_dir)
    if local_dir != ""
      local_dir = form_directory(local_dir)
    end
    if server_dir != ""
      server_dir = form_directory(server_dir)
    end
    new(name,calculations,local_dir,server,server_dir)
  end
end

function Base.display(job::DFJob)
  print_info(job)
end

"""
Represents an element.
"""
struct Element
  Z::Int64
  Name::String
  atomic_weight::Float64
end

"""
Reads all the elements from the file.
"""
const ELEMENTS = Dict()
open(joinpath(@__DIR__,"../assets/elements.txt"),"r") do f
  while !eof(f)
    line = split(readline(f))
    ELEMENTS[Symbol(line[4])] = Element(parse(Int64,line[1]),line[9],parse(Float64,line[10]))
  end
end
