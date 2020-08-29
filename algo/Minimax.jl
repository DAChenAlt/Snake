# TODO : Docs
# ==============================================================
#                    AbstractTreeReduce
# ==============================================================

abstract type AbstractTreeReduce end

statereduce(t::Type{T}, v::Type{V}, fr::Frame, i::Int) where
	 {T <: AbstractTreeReduce, V <: AbstractValue} =
	error("Not implemented for type $T")

# ==============================================================
#                          BestCase
# ==============================================================

struct BestCase <: AbstractTreeReduce end

statereduce(::Type{BestCase}, ::Type{V},
			fr::Frame, i::Int) where V <: AbstractValue =
bestcase(V, fr, i)[2]

function bestcase(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue

	isempty(fr.children) && return statevalue(V, fr, i), Tuple{Int,Int}[]

	U = 0
	q = Dict{Tuple{Int,Int},Int}()
	for (k, kr) in fr.children
		u, m = bestcase(V, kr, i)
		q[k[i]] = max(get!(q, k[i], 0), u + 1)
	end

	u, v = maxpairs(q)
	return u, v
end

# ==============================================================
#                          Minimax
# ==============================================================

struct Minimax <: AbstractTreeReduce end

statereduce(::Type{Minimax}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue =
	minmaxreduce(V, fr, i)[2]

function minmaxreduce(::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue

	isempty(fr.children) && return statevalue(V, fr, i), [], Dict()

	q = Dict{Tuple{Int,Int},Int}()
	for (k, v) in fr.children
		u, v, w = minmaxreduce(V, v, i)
		if haskey(q, k[i])
			q[k[i]] = min(q[k[i]], u + 1)
		else
			q[k[i]] = u + 1 # bonus point for being alive upto this depth
		end
	end

	u, v = maxpairs(q)
	return u, v, q
end

function maxpairs(q::Dict{Tuple{Int,Int},T}) where T
	Q = collect(pairs(q))
	m = maximum(map(x -> x[2], Q))
	m, map(y -> y[1], filter(x -> x[2] == m, Q))
end

# ==============================================================
#                          NotBad
# ==============================================================


struct NotBad <: AbstractTreeReduce end

function statereduce(::Type{NotBad}, ::Type{V},
	fr::Frame, i::Int) where V <: AbstractValue
	u, v, q = minmaxreduce(V, fr, i)
	betterthanavg(q)[2]
end

function betterthanavg(q::Dict{Tuple{Int,Int},T}) where T
	Q = collect(pairs(q))
	v = map(x -> x[2], Q)
	m = sum(v) / length(v)
	# @show m, v
	m, map(y -> y[1], filter(x -> x[2] >= m, Q))
end

# ==============================================================
#                       Tree search
# ==============================================================

struct TreeSearch{
	R <: AbstractTreeReduce,
	V <: AbstractValue,
	T <: AbstractTorch
	} <: AbstractAlgo end

minimax(N=1) = TreeSearch{Minimax,JazzCop,CandleLight{N}}

function treesearch(::Type{TreeSearch{R,V,T}},
	s::SType, i::Int) where {R, V, T}
	return dir -> begin
		fr = lookahead(T, s, i)
		statereduce(R, V, fr, i)
	end
end

function pipe(algo::Type{TreeSearch{R,V,T}}, s::SType, i::Int) where {R,V,T}
	return flow(pipe(Basic, s, i), treesearch(algo, s, i))
				# closestreachablefood(s, i)
end

function closestreachablefood(s::SType, i::Int, f=listclusters) 
	food = collect(s.food)
	isempty(food) && return identity

	return y -> begin
		c, d, l = f(s, i)
		rf = []
		for i=1:length(food)
			fo = food[i]
			if c[fo[1], fo[2]] in l
				push!(rf, fo)
			end
		end
		astar(cells(s), head(s.snakes[i]), rf, y)
	end
end
