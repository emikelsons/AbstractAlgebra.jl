###############################################################################
#
#   Submodule.jl : Generic submodules of modules
#
###############################################################################

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent_type(::Type{SubmoduleElem{T}}) where T <: RingElement = Submodule{T}

elem_type(::Type{Submodule{T}}) where T <: RingElement = SubmoduleElem{T}

parent(v::SubmoduleElem) = v.parent

base_ring_type(::Type{Submodule{T}}) where T <: RingElement = parent_type(T)

base_ring(N::Submodule{T}) where T <: RingElement = N.base_ring::parent_type(T)

number_of_generators(N::Submodule{T}) where T <: RingElement = length(N.gen_cols)

gens(N::Submodule{T}) where T <: RingElement = [gen(N, i) for i = 1:ngens(N)]

function gen(N::Submodule{T}, i::Int) where T <: RingElement
   @boundscheck 1 <= i <= ngens(N) || throw(ArgumentError("generator index out of range"))
   R = base_ring(N)
   return N([(j == i ? one(R) : zero(R)) for j = 1:ngens(N)])
end

@doc raw"""
    dim(N::Submodule{T}) where T <: FieldElement

Return the dimension of the given vector subspace.
"""
dim(N::Submodule{T}) where T <: FieldElement = length(N.gen_cols)
vector_space_dim(N::Submodule{T}) where T <: FieldElement = length(N.gen_cols)

# Generators as elements of supermodule. Used internally.
generators(N::Submodule{T}) where T <: RingElement = N.gens::Vector{elem_type(N.m)}

@doc raw"""
    supermodule(M::Submodule{T}) where T <: RingElement

Return the module that this module is a submodule of.
"""
supermodule(M::Submodule{T}) where T <: RingElement = M.m

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, N::Submodule{T}) where T <: RingElement
   @show_name(io, N)
   @show_special(io, N)
   print(io, "Submodule over ")
   print(terse(pretty(io)), Lowercase(), base_ring(N))
   show_gens_rels(io, N)
end

function show(io::IO, N::Submodule{T}) where T <: FieldElement
   @show_name(io, N)
   @show_special(io, N)
   print(io, "Subspace over ")
   print(terse(pretty(io)), Lowercase(), base_ring(N))
   show_gens_rels(io, N)
end

function show(io::IO, v::SubmoduleElem)
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
#   Parent object call overload
#
###############################################################################

function (N::Submodule{T})(v::Vector{T}) where T <: RingElement
   length(v) != ngens(N) && error("Length of vector does not match number of generators")
   mat = matrix(base_ring(N), 1, length(v), v)
   mat = reduce_mod_rels(mat, rels(N), 1)
   return SubmoduleElem{T}(N, mat)
end

function (N::Submodule{T})(v::Vector{Any}) where T <: RingElement
   length(v) != 0 && error("Incompatible element")
   return N(T[])
end

function (N::Submodule{T})(v::AbstractAlgebra.MatElem{T}) where T <: RingElement
   ncols(v) != ngens(N) && error("Length of vector does not match number of generators")
   nrows(v) != 1 && ("Not a vector in SubmoduleElem constructor")
   v = reduce_mod_rels(v, rels(N), 1)
   return SubmoduleElem{T}(N, v)
end

function (M::Submodule{T})(a::SubmoduleElem{T}) where T <: RingElement
   R = parent(a)
   base_ring(R) != base_ring(M) && error("Incompatible modules")
   if R === M
      return a
   else
      return M(R.map(a))
   end
end

# Fallback for all other kinds of modules
function (M::Submodule{T})(a::AbstractAlgebra.FPModuleElem{T}) where T <: RingElement
   error("Unable to coerce into given module")
end

###############################################################################
#
#   Submodule constructor
#
###############################################################################

function sub(m::AbstractAlgebra.FPModule{T}, gens::Vector{S}) where {T <: RingElement, S <: AbstractAlgebra.FPModuleElem{T}}
   R = base_ring(m)
   r = length(gens)
   while r > 0 && is_zero_row(_matrix(gens[r]), 1) # check that not all gens are zero
      r -= 1
   end
   if r == 0
      gens = Vector{S}(undef, 0) # original may have generators that are zero
      M = Submodule{T}(m, gens, Vector{dense_matrix_type(T)}(undef, 0),
                       Vector{Int}(undef, 0), Vector{Int}(undef, 0))
      f = ModuleHomomorphism(M, m, matrix(R, 0, ngens(m), []))
      M.map = f
      return M, f
   end
   # Make generators rows of a matrix
   s = ngens(m)
   local mat::dense_matrix_type(T)
   mat = zero_matrix(base_ring(m), r, s)
   for i = 1:r
      parent(gens[i]) !== m && error("Incompatible module elements")
      for j = 1:s
         mat[i, j] = _matrix(gens[i])[1, j]
      end
   end
   # Reduce matrix (hnf/rref), ensuring we remain reduced mod old relations
   old_rels = rels(m)
   while !isreduced_form(mat)
      # Reduce matrix (hnf/rref)
      mat = reduced_form(mat)
      # Remove zero rows
      num = r
      while num > 0 && is_zero_row(mat, num)
         num -= 1
      end
      # Reduce modulo old relations
      for i = 1:num
         Mi = @view mat[i:i, :]
         g = reduce_mod_rels(Mi, old_rels, 1)
         for j = 1:ncols(Mi)
            Mi[1, j] = g[1, j]
         end
      end 
   end
   # Remove zero rows
   num = r
   while num > 0 && is_zero_row(mat, num)
      num -= 1
   end
   # Rewrite matrix without zero rows and add old relations as rows
   # We flip the rows so the output of kernel is upper triangular with
   # respect to the original data, which saves time in reduced_form
   nr = num + length(old_rels)
   new_mat = zero_matrix(base_ring(m), nr, s)
   for i = 1:num
      for j = 1:s
         new_mat[nr - i + 1, j] = mat[i, j]
      end
   end
   for i = 1:length(old_rels)
      for j = 1:s
         new_mat[nr - i - num + 1, j] = old_rels[i][1, j]
      end
   end
   # Rewrite old relations in terms of generators of new submodule
   K = kernel(new_mat)
   num_rels = nrows(K)
   new_rels = zero_matrix(base_ring(m), num_rels, num)
   # we flip rows and columns so that input is in terms of original data and
   # in upper triangular form, to save time in reduced_form below
   for j = 1:num_rels
      for k = 1:num
         new_rels[num_rels - j + 1, k] = K[j, nr - k + 1]
      end
   end
   # Compute reduced form of new rels
   new_rels = reduced_form(new_rels)::dense_matrix_type(T)
   # remove rows and columns corresponding to unit pivots
   gen_cols, culled, pivots = cull_matrix(new_rels)
   # put all the culled relations into new relations
   srels = Vector{dense_matrix_type(T)}(undef, length(culled))
   for i = 1:length(culled)
      srels[i] = matrix(R, 1, length(gen_cols),
                    T[new_rels[culled[i], gen_cols[j]]
                       for j in 1:length(gen_cols)])
   end
   # Make submodule whose generators are the nonzero rows of mat
   nonzero_gens = elem_type(m)[m(T[mat[i, j] for j = 1:s]) for i = 1:num]
   M = Submodule{T}(m, nonzero_gens, srels, gen_cols, pivots)
   # Compute map from elements of submodule into original module
   hmat = T[_matrix(nonzero_gens[gen_cols[i]])[1, j] for i in 1:ngens(M) for j in 1:ngens(m)]
   f = ModuleHomomorphism(M, m, matrix(R, ngens(M), ngens(m), hmat))
   M.map = f
   return M, f
end

function sub(m::AbstractAlgebra.FPModule{T}, gens::Vector{Any}) where T <: RingElement
   length(gens) != 0 && error("Incompatible module elements")
   return sub(m, elem_type(m)[])
end

function sub(m::AbstractAlgebra.FPModule{T}, subs::Vector{Submodule{T}}) where T <: RingElement
   for N in subs
      flag, P = is_compatible(m, N)
      (!flag || P !== m) && error("Incompatible submodules")
   end
   gens = vcat((generators(s) for s in subs)...)
   return sub(m, gens)
end

