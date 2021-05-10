"""
The ColorSchemes module provides simple access to color schemes (arrays of colors).

Use `get(cscheme, n)` with n varying from 0 to 1 to find a color at that point
in the color scheme `cscheme`, where 0 is the leftmost color, and 1 the rightmost.

Access the scheme's colors directly using `cscheme.colors`.

See also `getinverse()`.
"""
module ColorSchemes

import Base.get, Base.reverse

using Colors, ColorTypes, FixedPointNumbers, StaticArrays

export ColorScheme,
       get,
       getinverse,
       colorschemes,
       loadcolorscheme,
       findcolorscheme

"""
    ColorScheme(colors, category, notes)

Create a ColorScheme from an array of colors. You can also name it, assign a
category to it, and add notes.

```julia
myscheme = ColorScheme([Colors.RGB(0.0, 0.0, 0.0), Colors.RGB(1.0, 1.0, 1.0)],
    "custom", "twotone, black and white")
```

"""
struct ColorScheme{V <: AbstractVector{<:Colorant},S1 <: AbstractString,S2 <: AbstractString}
    colors::V
    category::S1
    notes::S2
end
ColorScheme(colors::V, category::S1="", notes::S2="") where {V,S1,S2} =
    ColorScheme{V,S1,S2}(colors, category, notes)

Base.getindex(cs::ColorScheme, i::AbstractFloat) = get(cs, i)
Base.getindex(cs::ColorScheme, i::AbstractVector{<: AbstractFloat}) = get(cs, i)


"""
    loadcolorscheme(vname, colors, cat="", notes="")

Define a ColorScheme from a symbol and an array of colors,
and add it to the `colorschemes` dictionary. Optionally
speify a category and some notes.

### Example

This is an example (from `ColorsSchemes/data/flags.jl`) of how the supplied colorschemes are
loaded into the ColorSchemes dictionary.

```
loadcolorscheme(:flag_nu, [
        RGB(0.7843137254901961, 0.06274509803921569, 0.1803921568627451),
        RGB(0.00392156862745098, 0.12941176470588237, 0.4117647058823529),
        RGB(1.0, 1.0, 1.0),
        RGB(0.996078431372549, 0.8666666666666667, 0.0),
    ], "flags", "The flag of Niue")
```
"""
function loadcolorscheme(vname, colors, cat="", notes="")
    haskey(colorschemes, vname) && println("$vname overwritten")
    colorschemes[vname] = ColorSchemes.ColorScheme(colors, cat, notes)
    return colorschemes[vname]
end

"""
    colorschemes

An exported dictionary of pre-defined colorschemes:

```
colorschemes[:summer] |> show
   ColorScheme(
      ColorTypes.RGB{Float64}[
          RGB{Float64}(0.0,0.5,0.4), RGB{Float64}(0.01,0.505,0.4), RGB{Float64}(0.02,0.51,0.4), RGB{Float64}(0.03,0.515,0.4),
          ...
```

To choose a random ColorScheme:

```
scheme = rand(keys(colorschemes))
```

"""
const colorschemes = Dict{Symbol,ColorScheme}()

function loadallschemes()
    # load the installed schemes
    datadir = joinpath(dirname(@__DIR__), "data")
    include(joinpath(datadir, "allcolorschemes.jl"))
    include(joinpath(datadir, "colorbrewerschemes.jl"))
    include(joinpath(datadir, "matplotlib.jl"))
    include(joinpath(datadir, "cmocean.jl"))
    include(joinpath(datadir, "sampledcolorschemes.jl"))
    include(joinpath(datadir, "gnu.jl"))
    include(joinpath(datadir, "colorcetdata.jl"))
    include(joinpath(datadir, "scicolor.jl"))
    include(joinpath(datadir, "seaborn.jl"))
    include(joinpath(datadir, "tableau.jl"))
    include(joinpath(datadir, "cvd.jl"))
    include(joinpath(datadir, "cividis.jl"))
    include(joinpath(datadir, "flags.jl"))

    # create them as constants...
    for key in keys(colorschemes)
        @eval const $key = colorschemes[$(QuoteNode(key))]
    end
end

loadallschemes()

"""
    findcolorscheme(str)

Find all color schemes matching `str`. `str` is interpreted as a regular expression (case-insensitive).

To read the notes of built-in colorscheme `cscheme`:

```
colorschemes[:cscheme].notes
```
"""
function findcolorscheme(str)
    println("\ncolorschemes containing \"$str\"\n")
    counter = 0
    for (k, v) in colorschemes
        if occursin(Regex(str, "i"), string(k))
            printstyled("$(rpad(k, 20))\n", bold=true)
            counter += 1
        elseif occursin(Regex(str, "i"), string(v.category))
            printstyled("$(rpad(k, 20))", bold=true)
            println(" (category) $(v.category)")
            counter += 1
        end
        if occursin(Regex(str, "i"), string(v.notes))
            printstyled("$(rpad(k, 20))", bold=true)
            l = min(30, length(v.notes))
            println(" (notes) $(v.notes[1:l])...")
            counter += 1
        end
    end
    counter > 0 ?
        println("\n\nfound $counter result$(counter > 1 ? "s" : "") for \"$str\"") :
        println("\n\nnothing found for \"$str\"")
    return nothing
end

# displaying swatches
Base.show(io::IO, m::MIME"image/svg+xml", cscheme::ColorScheme) = show(io, m, cscheme.colors)

# Interfaces
Base.length(cscheme::ColorScheme) = length(cscheme.colors)
Base.getindex(cscheme::ColorScheme, I) = cscheme.colors[I]
Base.size(cscheme::ColorScheme) = length(cscheme.colors)
Base.IndexStyle(::Type{<:ColorScheme}) = IndexLinear()

# iterable
function Base.iterate(cscheme::ColorScheme)
    if length(cscheme.colors) == 0
        return nothing
    end
    return (first(cscheme.colors), 1)
end

function Base.iterate(cscheme::ColorScheme, state)
    if state >= length(cscheme.colors)
        return nothing
    else
        return (cscheme.colors[state + 1], state + 1)
    end
end

Base.lastindex(cscheme::ColorScheme) = lastindex(cscheme.colors)

# utility lerping function to convert a value between oldmin/oldmax to equivalent value between newmin/newmax
remap(value, oldmin, oldmax, newmin, newmax) =
    ((value .- oldmin) ./ (oldmax .- oldmin)) .* (newmax .- newmin) .+ newmin

const AllowedInput = Union{<:Real,AbstractArray{<:Real}}

defaultrange(x::Real) = zero(x), oneunit(x)
defaultrange(x::AbstractArray) = zero(eltype(x)), oneunit(eltype(x))

"""
    get(cscheme::ColorScheme, inData :: Array{Number, 2}, rangescale=:clamp)
    get(cscheme::ColorScheme, inData :: Array{Number, 2}, rangescale=(minVal, maxVal))

Return an RGB array of colors generated by applying the
colorscheme to the 2D input data.

If `rangescale` is `:clamp` the colorscheme is applied to
values between 0.0-1.0, and values outside this range get
clamped to the ends of the colorscheme.

Else, if `rangescale` is `:extrema`, the colorscheme is
applied to the range `minimum(indata)..maximum(indata)`.

TODO: this function expects the colorscheme to consist of
RGB [0.0-1.0] values. It should work with more colortypes.

# Examples

```
img = get(colorschemes[:leonardo], rand(10,10)) # displays in Juno Plots window, but
save("testoutput.png", img)      # you'll need FileIO or similar to do this

img2 = get(colorschemes[:leonardo], 10.0 * rand(10, 10), :extrema)
img3 = get(colorschemes[:leonardo], 10.0 * rand(10, 10), (1.0, 9.0))

# Also works with PerceptualColourMaps
using PerceptualColourMaps # warning, installs PyPlot, PyCall, LaTeXStrings
img4 = get(PerceptualColourMaps.cmap("R1"), rand(10,10))
```
"""
function get(cscheme::ColorScheme, x::AllowedInput, rangemode::Symbol)
    rangescale = if rangemode == :clamp
        defaultrange(x)
    elseif rangemode == :extrema
        extrema(x)
    else
        error("rangescale ($rangemode) not supported, should be :clamp, :extrema or tuple (minVal, maxVal)")
    end
    get(cscheme, x, rangescale)
end
function get(cscheme::ColorScheme, x::AllowedInput, rangescale::NTuple{2,<:Real}=defaultrange(x))
    x isa AbstractRange && (x = collect(x))
    # check for empty range
    if iszero(first(rangescale) - last(rangescale))
        rangescale = zero(first(rangescale)), oneunit(last(rangescale))
    end
    x = clamp.(x, rangescale...)
    before_fp = remap(x, rangescale..., 1, length(cscheme))
    before = round.(Int, before_fp, RoundDown)
    after =  min.(before .+ 1, length(cscheme))
    #  blend between the two colors adjacent to the point
    cpt = before_fp - before
    return weighted_color_mean.(1 .- cpt, cscheme.colors[before], cscheme.colors[after])
end
# Boolean just takes the start and end values of the scheme. Also avoid using a branch.
function get(cscheme::ColorScheme, x::Union{Bool,AbstractArray{Bool}})
    i = x .* (length(cscheme) .- 1) .+ 1
    return getindex.(Ref(cscheme.colors), i)
end

"""
    get(cs::ColorScheme, g::Color{T,1} where T<:Union{Bool, AbstractFloat, FixedPoint})

Return the color in `cs` that corresponds to the gray value `g`.
"""
function get(cs::ColorScheme, g::Color{T,1} where T <: Union{Bool,AbstractFloat,FixedPoint})
    get(cs, ColorTypes.gray(g)) # don't confuse with the 'grays' colorscheme
end

"""
    getinverse(cscheme::ColorScheme, c, range=(0.0, 1.0))

Computes where the provided Color `c` would fit in `cscheme`.

This is the inverse of `get()` — it returns the value `x` in the provided `range`
for which `get(scheme, x)` would most closely match the provided Color `c`.

# Examples

The first example asks: "where in the `leonardo` colorscheme will I find the nearest
color to red?":

```
julia> getinverse(colorschemes[:leonardo], RGB(1, 0, 0))
0.6248997995654847

julia> getinverse(ColorScheme([Colors.RGB(0,0,0), Colors.RGB(1,1,1)]),  Colors.RGB(.5,.5,.5))
0.5432555858022048

julia> cs = ColorScheme(range(Colors.RGB(0,0,0), stop=Colors.RGB(1,1,1), length=5))

julia> getinverse(cs, cs[3])
0.5
```
"""
function getinverse(cscheme::ColorScheme, c, rangescale::Tuple{Number,Number}=(0.0, 1.0))
    # TODO better error handling please
    length(cscheme) <= 1 && throw(ErrorException("ColorScheme of length $(length(cscheme)) is not long enough"))
    cdiffs = map(c_i -> colordiff(promote(c, c_i)...), cscheme.colors)
    closest = argmin(cdiffs)
    left = right = 0
    if closest == 1 ; left = closest; right = closest + 1;
    elseif closest == length(cscheme) ; left = closest - 1; right = closest;
    else
        next_closest = cdiffs[closest - 1] < cdiffs[closest + 1] ? closest - 1 : closest + 1
        left = min(closest, next_closest)
        right = max(closest, next_closest)
    end
    v = left
    if cdiffs[left] != cdiffs[right] # prevents divide by zero
        v += ( cdiffs[left] / (cdiffs[left] + cdiffs[right]))
    end
    return remap(v, 1, length(cscheme), rangescale...)
end

"""
    reverse(cscheme)

Make a new ColorScheme with the same colors as `cscheme` but in reverse order.
"""
Base.reverse(cscheme::ColorScheme) =
    ColorScheme(reverse(cscheme.colors), cscheme.category, cscheme.notes)

end
