nchannels(fr::SignalFrame{NCh})  where {NCh} = NCh
bitdepth(fr::SignalFrame{NCh,T}) where {NCh,T} = T
nframes(ss::SignalFrame) = 1

function show(io::IO, fr::SignalFrame)
    # println(io, typeof(fr))
    @printf io "("
    for i in 1:nchannels(fr)
       @printf io "%s %2.2f%s" tick_string(fr[i]) real2dbfs(fr[i]) i == nchannels(fr) ? "" : ", "
    end
    @printf io " dBFS)"
end

# hack to make certain things work with fixed precision numbers for ::FP / ::Int
# (Base.promote_type)(::Type{<:FixedPointNumbers.FixedPoint}, ::Type{<:Integer}) = Float32

zero(::Type{SignalFrame{NCh, T}}) where {NCh,T} = SignalFrame{NCh, T}(ntuple(_->zero(T), NCh))
zero(::SignalFrame{NCh, T})       where {NCh,T} = zero(SignalFrame{NCh, T})
one(::Type{SignalFrame{NCh, T}})  where {NCh,T} = SignalFrame{NCh, T}(ntuple(_->one(T), NCh))
one(::SignalFrame{NCh, T})        where {NCh,T} = one(SignalFrame{NCh, T})
for f in (:(Base.length), :(Base.size), :(Base.start), :(Base.endof))
    @eval $f(fr::SignalFrame) = $f(fr.frame)
end
for f in (:(Base.getindex), :(Base.next), :(Base.done))
    @eval $f(fr::SignalFrame, i::Int) = $f(fr.frame, i::Int)
end
getindex(fr::SignalFrame, iter) = SignalFrame(fr.frame[iter]...)

# unary operators
for op in (:-, :(Base.abs), :(Base.sqrt), :(Base.log), :(Base.sum))
    @eval ($op)(fr::SignalFrame) = SignalFrame(map($op, fr.frame))
end

# binary operations
# — distributative
for op in (:*, :/)
    @eval ($op)(fr::SignalFrame, x::T) where {T<:Real} = SignalFrame(map(y -> ($op)(y, x), fr.frame))
    @eval ($op)(x::T, fr::SignalFrame) where {T<:Real} = ($op)(fr, x)
end
# — associative
absmax(a::Real, b::Real) = abs(a) >= abs(b) ? a : b
absmin(a::Real, b::Real) = abs(a) >= abs(b) ? b : a

for op in (:+, :-, :(Base.max), :(Base.min), :absmax, :absmin)
    @eval ($op)(fr1::SignalFrame{NCh,T}, fr2::SignalFrame{NCh,T}) where {NCh,T} = SignalFrame(map($op, fr1.frame, fr2.frame))
end

Base.convert(::Type{SignalFrame{NCh,T}}, frame::NTuple{NCh,<:Real}) where {NCh,T} = SignalFrame{NCh,T}(Base.convert(NTuple{NCh,T}, frame))
Base.convert(::Type{SignalFrame{NCh,T}}, r::Real) where {NCh,T}                   = SignalFrame{NCh,T}(r)
Base.convert(::Type{SignalFrame{NCh,T}}, vec::Vector{<:Real})     where {NCh,T}   = Base.convert(SignalFrame{NCh,T}, (vec...))

Base.convert(::Type{SignalFrame{NCh,T}}, fr::SignalFrame{NCh,U})  where {NCh,T,U} = SignalFrame{NCh,T}(Base.convert(NTuple{NCh,T}, fr.frame))

# need a generated function here, we're scaling back each channel by -3dBFS
Base.convert(::Type{SignalFrame{1,T}},   fr::SignalFrame{2,T})    where T         = SignalFrame{NCh,T}(0.7079457843841379*fr[1] + 0.7079457843841379*fr[2])
Base.convert(::Type{SignalFrame{NCh,T}}, fr::SignalFrame{1,T})    where {NCh, T}  = SignalFrame{NCh,T}(ntuple(_->fr[1], NCh))

# should eventually replace this construction with a generated function so that branching is not required at runtime
@inline function Base.convert(::Type{SignalFrame{NChOut,TOut}}, fr::SignalFrame{NChIn,TIn}) where {NChOut,TOut, NChIn,TIn}
    # if widening the headroom, do this before upmixing/downmixing channels
    return if promote_type(TOut, TIn) == TOut
        convert(SignalFrame{NChOut,TOut}, convert(SignalFrame{NChIn,TOut}, fr))
    else
        convert(SignalFrame{NChOut,TOut}, convert(SignalFrame{NChOut,TIn}, fr))
    end
end