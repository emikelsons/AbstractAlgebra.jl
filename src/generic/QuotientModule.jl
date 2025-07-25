###############################################################################
#
#   QuotientModule.jl : Generic quotients of modules by submodules
#
###############################################################################

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent_type(::Type{QuotientModuleElem{T}}) where T <: RingElement = QuotientModule{T}

elem_type(::Type{QuotientModule{T}}) where T <: RingElement = QuotientModuleElem{T}

parent(v::QuotientModuleElem) = v.parent

base_ring_type(::Type{QuotientModule{T}}) where T <: RingElement = parent_type(T)

base_ring(N::QuotientModule{T}) where T <: RingElement = N.base_ring::parent_type(T)

number_of_generators(N::QuotientModule{T}) where T <: RingElement = length(N.gen_cols)

gens(N::QuotientModule{T}) where T <: RingElement = elem_type(N)[gen(N, i) for i = 1:ngens(N)]

rank(M::QuotientModule{T}) where T <: FieldElement = dim(M)

function gen(N::QuotientModule{T}, i::Int) where T <: RingElement
   @boundscheck 1 <= i <= ngens(N) || throw(ArgumentError("generator index out of range"))
   R = base_ring(N)
   mat = matrix(R, 1, ngens(N),
                [(j == i ? one(R) : zero(R)) for j = 1:ngens(N)])
   return QuotientModuleElem{T}(N, mat)
end

@doc raw"""
    dim(N::QuotientModule{T}) where T <: FieldElement

Return the dimension of the given vector quotient space.
"""
dim(N::QuotientModule{T}) where T <: FieldElement = length(N.gen_cols)
vector_space_dim(N::QuotientModule{T}) where T <: FieldElement = length(N.gen_cols)

@doc raw"""
    supermodule(M::QuotientModule{T}) where T <: RingElement

Return the module that this module is a quotient of.
"""
supermodule(M::QuotientModule{T}) where T <: RingElement = M.m

###############################################################################
#
#   String I/O
#
###############################################################################

function show_gens_rels(io::IO, N::AbstractAlgebra.FPModule{T}) where T <: RingElement
   print(io, " with ", ItemQuantity(ngens(N), "generator"), " and ")
   if length(rels(N)) == 0
      print(io, "no relations")
   else
      println(io, "relations:")
      Nrels = [string(v) for v in rels(N)]
      print(IOContext(io, :compact => true), join(Nrels, ", "))
   end
end

function show(io::IO, N::QuotientModule{T}) where T <: RingElement
   @show_name(io, N)
   @show_special(io, N)
   print(io, "Quotient module over ")
   print(terse(pretty(io)), Lowercase(), base_ring(N))
   show_gens_rels(io, N)
end

function show(io::IO, N::QuotientModule{T}) where T <: FieldElement
   @show_name(io, N)
   @show_special(io, N)
   print(io, "Quotient space over ")
   print(terse(pretty(io)), Lowercase(), base_ring(N))
   show_gens_rels(io, N)
end

function show(io::IO, v::QuotientModuleElem)
   print(io, "(")
   len = ngens(parent(v))
   for i = 1:len - 1
      print(IOContext(io, :compact => true), _matrix(v)[1, i])
      print(io, ", ")
   end
   if len > 0
      print(IOContext(io, :compact => true), _matrix(v)[1, len])
   end
   print(io, ")")
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(M::QuotientModule{T}, N::QuotientModule{T}) where T <: RingElement
   check_parent(M, N)
   return M.m == N.m && M.rels == N.rels
end

###############################################################################
#
#   Parent object call overload
#
###############################################################################

# Reduce the vector v by the relations vrels starting at column start of v
function reduce_mod_rels(v::AbstractAlgebra.MatElem{T}, vrels::Vector{<:AbstractAlgebra.MatElem{T}}, start::Int) where T <: RingElement
   R = base_ring(v)
   v = deepcopy(v) # don't destroy input
   i = 1
   t1 = R()
   for k = 1:length(vrels) # for each relation
      rel = vrels[k]
      while is_zero_entry(rel, 1, i)
         i += 1
      end
      q, v[1, start + i - 1] = divrem(v[1, start + i - 1], rel[1, i])
      q = -q
      for j = i + 1:ncols(rel)
         t1 = mul!(t1, q, rel[1, j])
         v[1, start + j - 1] = add!(v[1, start + j - 1], t1)
      end
      i += 1
   end
   return v 
end

function (N::QuotientModule{T})(v::Vector{T}) where T <: RingElement
   length(v) != ngens(N) && error("Length of vector does not match number of generators")
   mat = matrix(base_ring(N), 1, length(v), v)
   mat = reduce_mod_rels(mat, rels(N), 1)
   return QuotientModuleElem{T}(N, mat)
end

function (M::QuotientModule{T})(a::Vector{Any}) where T <: Union{RingElement, NCRingElem}
   length(a) != 0 && error("Incompatible element")
   return M(T[])
end

function (N::QuotientModule{T})(v::AbstractAlgebra.MatElem{T}) where T <: RingElement
   ncols(v) != ngens(N) && error("Length of vector does not match number of generators")
   nrows(v) != 1 && ("Not a vector in QuotientModuleElem constructor")
   v = reduce_mod_rels(v, rels(N), 1)
   return QuotientModuleElem{T}(N, v)
end

function (M::QuotientModule{T})(a::AbstractAlgebra.FPModuleElem{T}) where T <: RingElement
   N = parent(a)
   R = base_ring(N)
   base_ring(M) != R && error("Incompatible modules")
   if M === N
      return a
   else
      flag, P = is_compatible(M, N)
      if flag && P === M
         while N !== M
            a = N.map(a)
            N = parent(a)
         end
         return a
      end
      Q = supermodule(M)
      return M.map(Q(a))
   end
end

###############################################################################
#
#   QuotientModule constructor
#
###############################################################################

function projection(v::AbstractAlgebra.MatElem{T}, crels::AbstractAlgebra.MatElem{T}, N::QuotientModule{T}) where {T <: RingElement}
   R = base_ring(N)
   # remove zero rows
   nr = nrows(crels)
   while nr > 0 && is_zero_row(crels, nr)
      nr -= 1
   end
   # put into row vectors
   vrels = Vector{dense_matrix_type(T)}(undef, nr)
   for i = 1:nr
      vrels[i] = matrix(R, 1, ncols(crels), [crels[i, j] for j in 1:ncols(crels)])
   end
   # reduce mod relations
   v = reduce_mod_rels(v, vrels, 1)
   # project down to quotient module
   r = zero_matrix(R, 1, ngens(N))
   for i = 1:ngens(N)
      r[1, i] = v[1, N.gen_cols[i]]
   end
   return r
end

function compute_combined_rels(m::AbstractAlgebra.FPModule{T}, srels::Vector{S}) where {T <: RingElement, S <: AbstractAlgebra.MatElem{T}}
   # concatenate relations in m and new rels
   R = base_ring(m)
   old_rels = rels(m)
   combined_rels = zero_matrix(R, length(old_rels) + length(srels), ngens(m))
   for i = 1:length(old_rels)
      for j = 1:ngens(m)
         combined_rels[i, j] = old_rels[i][1, j]
      end
   end
   for i = 1:length(srels)
      for j = 1:ngens(m)
         combined_rels[i + length(old_rels), j] = srels[i][1, j]
      end
   end
   # compute the hnf/rref of the combined relations
   combined_rels = reduced_form(combined_rels)
   return combined_rels
end

function make_direct_sub(m::Submodule{T}, subm::Submodule{T}) where T <: RingElement
  chain_m = []
  up = m
  while isa(up, Submodule)
     push!(chain_m, up.map)
     up = codomain(up.map)
  end

  chain_s = []
  up = subm
  found = false
  while isa(up, Submodule)
     push!(chain_s, up.map)
     up = codomain(up.map)
     if any(x->codomain(x) === up, chain_m)
        found = true
        break
     end
  end

  found || error("module is not a submodule")
  p = 1
  while codomain(chain_m[p]) !== codomain(chain_s[end])
     p += 1
  end
  gns = elem_type(codomain(chain_s[end]))[]
  for g = gens(subm)
     for mp = chain_s
        g = mp(g)
     end
     push!(gns, g)
  end
  for mp = chain_m[p:-1:1]
      gns = preimage(mp, gns)
  end
  return sub(m, gns)
end

function quo(m::AbstractAlgebra.FPModule{T}, subm::Submodule{T}) where T <: RingElement
   if !is_submodule(m, subm) 
     subm = make_direct_sub(m, subm)[1]
     @assert is_submodule(m, subm)
   end

   R = base_ring(m)
   if subm === m # quotient of submodule by itself
      srels = dense_matrix_type(T)[_matrix(v) for v in gens(subm)]
      combined_rels = compute_combined_rels(m, srels)
      M = QuotientModule{T}(m, combined_rels)
      f = ModuleHomomorphism(m, M,
          matrix(R, ngens(m), 0, T[]))
   else
      G = generators(subm)
      S = subm
      if supermodule(S) !== m
         while supermodule(S) !== m
            G = elem_type(typeof(supermodule(S.m)))[S.m.map(v) for v in G]
            S = supermodule(S)
         end
         subm, v = sub(m, G)
         G = generators(subm)
      end
      nrels = ngens(subm)
      srels = Vector{dense_matrix_type(T)}(undef, nrels)
      for i = 1:nrels
         srels[i] = _matrix(G[i])
      end
      combined_rels = compute_combined_rels(m, srels)
      M = QuotientModule{T}(m, combined_rels)
      hvecs = dense_matrix_type(T)[projection(_matrix(x), combined_rels, M) for x in gens(m)]
      hmat = T[hvecs[i][1, j] for i in 1:ngens(m) for j in 1:ngens(M)]
      f = ModuleHomomorphism(m, M, matrix(R, ngens(m), ngens(M), hmat))
   end
   M.map = f
   return M, f
end

function quo(m::AbstractAlgebra.FPModule{T}, subm::AbstractAlgebra.FPModule{T}) where T <: RingElement
   # The only case we need to deal with here is where `m == subm`. In all other
   # cases, subm will be of type Submodule.
   m !== subm && error("Not a submodule in QuotientModule constructor")
   srels = dense_matrix_type(T)[_matrix(v) for v in gens(subm)]
   combined_rels = compute_combined_rels(m, srels)
   M = QuotientModule{T}(m, combined_rels)
   R = base_ring(m)
   f = ModuleHomomorphism(m, M, matrix(R, ngens(m), 0, []))
   M.map = f
   return M, f   
end
