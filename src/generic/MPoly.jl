###############################################################################
#
#   MPoly.jl : Generic sparse distributed multivariate polynomials over rings
#
###############################################################################

###############################################################################
#
#   Data type and parent object methods
#
###############################################################################

parent(a::MPoly{T}) where T <: RingElement = a.parent

parent_type(::Type{MPoly{T}}) where T <: RingElement = MPolyRing{T}

elem_type(::Type{MPolyRing{T}}) where T <: RingElement = MPoly{T}

base_ring(R::MPolyRing{T}) where T <: RingElement = R.base_ring::parent_type(T)

is_trivial(R::MPolyRing) = R.istrivial

@doc raw"""
    symbols(a::MPolyRing)

Return an array of symbols representing the variable names for the given
polynomial ring.
"""
symbols(a::MPolyRing) = a.S

@doc raw"""
    number_of_variables(x::MPolyRing)

Return the number of variables of the polynomial ring.
"""
number_of_variables(a::MPolyRing) = a.num_vars

number_of_generators(a::MPolyRing) = a.num_vars

@doc raw"""
    gens(a::MPolyRing{T}) where {T <: RingElement}

Return an array of all the generators (variables) of the given polynomial
ring.
"""
function gens(a::MPolyRing{T}) where {T <: RingElement}
   n = a.num_vars
   return elem_type(a)[gen(a, i) for i in 1:n]
end

@doc raw"""
    gen(a::MPolyRing{T}, i::Int) where {T <: RingElement}

Return the $i$-th generator (variable) of the given polynomial
ring.
"""
function gen(a::MPolyRing{T}, i::Int) where {T <: RingElement}
   is_trivial(a) && return zero(a)
   n = nvars(a)
   @boundscheck 1 <= i <= n || throw(ArgumentError("variable index out of range"))

   ord = internal_ordering(a)
   if ord == :lex
      exps = zeros(UInt, n, 1)
      exps[n - i + 1] = 1
   elseif ord == :deglex
      exps = zeros(UInt, n + 1, 1)
      exps[n - i + 1] = 1
      exps[end] = 1
   elseif ord == :degrevlex
      exps = zeros(UInt, n + 1, 1)
      exps[i] = 1
      exps[end] = 1
   else
      error("invalid ordering")
   end
   return a([one(base_ring(a))], exps)
end

function vars(p::MPoly{T}) where {T <: RingElement}
   vars_in_p = Vector{MPoly{T}}(undef, 0)
   n = nvars(p.parent)
   exps = p.exps
   gen_list = gens(p.parent)
   for j = 1:n
      for i = 1:length(p)
         if exps[j, i] > 0
            if p.parent.ord == :degrevlex
               push!(vars_in_p, gen_list[j])
            else
               push!(vars_in_p, gen_list[n - j + 1])
            end
            break
         end
      end
   end
   if p.parent.ord != :degrevlex
      vars_in_p = reverse(vars_in_p)
   end
   return(vars_in_p)
end

@doc raw"""
    internal_ordering(a::MPolyRing{T}) where {T <: RingElement}

Return the ordering of the given polynomial ring as a symbol. The options are
`:lex`, `:deglex` and `:degrevlex`.
"""
function internal_ordering(a::MPolyRing{T}) where {T <: RingElement}
   return a.ord
end

###############################################################################
#
#   Manipulating terms and monomials
#
###############################################################################

@doc raw"""
    exponent_vector(a::MPoly{T}, i::Int) where T <: RingElement

Return a vector of exponents, corresponding to the exponent vector of the
i-th term of the polynomial. Term numbering begins at $1$ and the exponents
are given in the order of the variables for the ring, as supplied when the
ring was created.
"""
function exponent_vector(a::MPoly{T}, i::Int) where T <: RingElement
   A = a.exps
   N = size(A, 1)

   ord = internal_ordering(parent(a))
   if ord == :lex
      return [Int(A[j, i]) for j in N:-1:1]
   elseif ord == :deglex
      return [Int(A[j, i]) for j in N - 1:-1:1]
   elseif ord == :degrevlex
      return [Int(A[j, i]) for j in 1:N - 1]
   else
      error("invalid ordering")
   end
end

@doc raw"""
    exponent{T <: RingElem}(a::MPoly{T}, i::Int, j::Int)

Return exponent of the j-th variable in the i-th term of the polynomial.
Term and variable numbering begins at $1$ and variables are ordered as
during the creation of the ring.
"""
function exponent(a::MPoly{T}, i::Int, j::Int) where T <: RingElement
   A = a.exps
   N = size(A, 1)

   ord = internal_ordering(parent(a))
   if ord == :lex
      return Int(a.exps[N + 1 - j, i])
   elseif ord == :deglex
      return Int(a.exps[N - j, i])
   elseif ord == :degrevlex
      return Int(a.exps[j, i])
   else
      error("invalid ordering")
   end
end

@doc raw"""
    set_exponent_vector!(a::MPoly{T}, i::Int, exps::Vector{Int}) where T <: RingElement

Set the i-th exponent vector to the supplied vector, where the entries
correspond to the exponents of the variables in the order supplied when
the ring was created. The modified polynomial is returned.
"""
function set_exponent_vector!(a::MPoly{T}, i::Int, exps::Vector{Int}) where T <: RingElement
   fit!(a, i)
   A = a.exps

   ord = internal_ordering(parent(a))
   if ord == :lex
      A[:, i] = exps[end:-1:1]
   elseif ord == :deglex
      A[1:end - 1, i] = exps[end:-1:1]
      A[end, i] = sum(exps)
   elseif ord == :degrevlex
      A[1:end - 1, i] = exps
      A[end, i] = sum(exps)
   else
      error("invalid ordering")
   end

   if i > length(a)
      a.length = i
   end
   return a
end

@doc raw"""
    coeff(a::MPoly{T}, exps::Vector{Int}) where T <: RingElement

Return the coefficient of the term with the given exponent vector, or zero
if there is no such term.
"""
function coeff(a::MPoly{T}, exps::Vector{Int}) where T <: RingElement
   A = a.exps
   N = size(A, 1)
   exp2 = Vector{UInt}(undef, N)
   ord = parent(a).ord
   if ord == :lex
      exp2[:] = exps[end:-1:1]
   elseif ord == :deglex
      exp2[1:end - 1] = exps[end:-1:1]
      exp2[end] = sum(exps)
   else
      exp2[1:end - 1] = exps[1:end]
      exp2[end] = sum(exps)
   end
   exp2 = reshape(exp2, N, 1)
   lo = 1
   hi = length(a)
   n = div(hi - lo + 1, 2)
   while hi >= lo
      v = monomial_cmp(A, lo + n, exp2, 1, N, parent(a), UInt(0))
      if v == 0
         return a.coeffs[lo + n]
      elseif v < 0
         hi = lo + n - 1
      else
         lo = lo + n + 1
      end
      n = div(hi - lo + 1, 2)
   end
   return base_ring(a)()
end

@doc raw"""
    setcoeff!(a::MPoly, exps::Vector{Int}, c::S) where S <: RingElement

Set the coefficient of the term with the given exponent vector to the given
value $c$. This function takes $O(\log n)$ operations if a term with the given
exponent already exists, or if the term is inserted at the end of the
polynomial. Otherwise it can take $O(n)$ operations in the worst case.
"""
function setcoeff!(a::MPoly, exps::Vector{Int}, c::S) where S <: RingElement
   c = base_ring(a)(c)
   A = a.exps
   N = size(A, 1)
   exp2 = Vector{UInt}(undef, N)
   ord = parent(a).ord
   if ord == :lex
      exp2[:] = exps[end:-1:1]
   elseif ord == :deglex
      exp2[1:end - 1] = exps[end:-1:1]
      exp2[end] = sum(exps)
   else
      exp2[1:end - 1] = exps[1:end]
      exp2[end] = sum(exps)
   end
   exp2 = reshape(exp2, N, 1)
   lo = 1
   hi = length(a)
   if hi > 0
      n = div(hi - lo + 1, 2)
      while hi >= lo
         v = monomial_cmp(A, lo + n, exp2, 1, N, parent(a), UInt(0))
         if v == 0
            if !iszero(c) # just insert the coefficient
               a.coeffs[lo + n] = c
            else # coefficient is zero, shift everything
               for i = lo + n:length(a) - 1
                  a.coeffs[i] = a.coeffs[i + 1]
                  monomial_set!(A, i, A, i + 1, N)
               end
               a.coeffs[length(a)] = c # zero final coefficient
               a.length -= 1
            end
            return a
         elseif v < 0
            hi = lo + n - 1
         else
            lo = lo + n + 1
         end
         n = div(hi - lo + 1, 2)
      end
   end
   # exponent not found, must insert at lo
   if !iszero(c)
      lena = length(a)
      fit!(a, lena + 1)
      A = a.exps
      for i = lena:-1:lo
         a.coeffs[i + 1] = a.coeffs[i]
         monomial_set!(A, i + 1, A, i, N)
      end
      a.coeffs[lo] = c
      monomial_set!(A, lo, exp2, 1, N)
      a.length += 1
   end
   return a
end

@doc raw"""
    sort_terms!(a::MPoly{T}) where {T <: RingElement}

Sort the terms of the given polynomial according to the polynomial ring
ordering. Zero terms and duplicate exponents are ignored. To deal with those
call `combine_like_terms`. The sorted polynomial is returned.
"""
function sort_terms!(a::MPoly{T}) where {T <: RingElement}
   N = parent(a).N
   # The reverse order is the fastest order if already sorted
   V = [(ntuple(i -> a.exps[i, r], Val(N)), r) for r in length(a):-1:1]
   ord = parent(a).ord
   if ord == :lex || ord == :deglex
      sort!(V, lt = is_less_lex)
   else
      sort!(V, lt = is_less_degrevlex)
   end
   Rc = [a.coeffs[V[i][2]] for i in length(V):-1:1]
   Re = zeros(UInt, N, length(V))
   for i = 1:length(V)
      for j = 1:N
         Re[j, length(V) - i + 1] = V[i][1][j]
      end
   end
   a.coeffs = Rc
   a.exps = Re
   return a
end

###############################################################################
#
#   Monomial operations
#
###############################################################################

# Computes a degrevlex xor mask for the most significant word of an exponent
# vector. Requires the number of bits per field and the polynomial ring.
function monomial_drmask(R::MPolyRing{T}, bits::Int) where T <: RingElement
   vars_per_word = div(sizeof(Int)*8, bits)
   n = rem(nvars(R), vars_per_word)
   return reinterpret(UInt, (1 << (bits*n)) - 1)
end

# Sets the i-th exponent vector of the exponent array A to zero
function monomial_zero!(A::Matrix{UInt}, i::Int, N::Int)
   for k = 1:N
      A[k, i] = UInt(0)
   end
   nothing
end

# Returns true if the i-th exponent vector of the exponent array A is zero
# For degree orderings, this inefficiently also checks the degree field
function monomial_iszero(A::Matrix{UInt}, i::Int, N::Int)
   for k = 1:N
      if A[k, i] != UInt(0)
         return false
      end
   end
   return true
end

# Returns true if the i-th and j-th exponent vectors of the array A are equal
# For degree orderings, this inefficiently also checks the degree fields
function monomial_isequal(A::Matrix{UInt}, i::Int, j::Int, N::Int)
   for k = 1:N
      if A[k, i] != A[k, j]
         return false
      end
   end
   return true
end

# Returns true if the i-th exponent vector of the array A is less than that of
# the j-th, according to the ordering of R
function monomial_isless(A::Matrix{UInt}, i::Int, j::Int, N::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
   return monomial_isless(A, i, A, j, N, R, drmask)
end

# Return true if the i-th exponent vector of the array A is less than the j-th
# exponent vector of the array B
function monomial_isless(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, N::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
  return monomial_cmp(A, i, B, j, N, R, drmask) < 0
end

# Set the i-th exponent vector of the array A to the word by word minimum of
# itself and the j-th exponent vector of B. Used for lexical orderings only.
function monomial_vecmin!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, N::Int)
   for k = 1:N
      if B[k, j] < A[k, i]
         A[k, i] = B[k, j]
      end
   end
   nothing
end

# Set the i-th exponent vector of the array A to the j-th exponent vector of B
function monomial_set!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, N::Int)
   for k = 1:N
      A[k, i] = B[k, j]
   end
   nothing
end

# Set the i-th exponent vector of the array A to the word by word reverse of
# the j-th exponent vector of B, excluding the degree. (Used for printing
# degrevlex only.)
function monomial_reverse!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, N::Int)
   for k = 1:N - 1
      A[N - k, i] = B[k, j]
   end
   nothing
end

# Set the i-th exponent vector of the array A to the word by word sum of the
# j1-th exponent vector of B and the j2-th exponent vector of C
function monomial_add!(A::Matrix{UInt}, i::Int,
                B::Matrix{UInt}, j1::Int, C::Matrix{UInt}, j2::Int, N::Int)
   for k = 1:N
      A[k, i] = B[k, j1] + C[k, j2]
   end
   nothing
end

# Set the i-th exponent vector of the array A to the word by word difference of
# the j1-th exponent vector of B and the j2-th exponent vector of C
function monomial_sub!(A::Matrix{UInt}, i::Int,
                B::Matrix{UInt}, j1::Int, C::Matrix{UInt}, j2::Int, N::Int)
   for k = 1:N
      A[k, i] = B[k, j1] - C[k, j2]
   end
   nothing
end

# Set the i-th exponent vector of the array A to the scalar product of the j-th
# exponent vector of the array B with the non-negative integer n. (Used for
# raising a monomial to a power.)
function monomial_mul!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, n::Int, N::Int)
   for k = 1:N
      A[k, i] = B[k, j]*reinterpret(UInt, n)
   end
   nothing
end

# Return true if the j1-th exponent vector of the array B has all components
# greater than or equal to those of the j2-th exponent vector of C. If so, the
# difference is returned as the i-th exponent vector of the array A. Note that
# a mask must be supplied which has 1's in all bit positions that correspond to
# an overflow of the corresponding exponent field. (Used for testing
# divisibility of monomials, and returning the quotient monomial.)
function monomial_divides!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j1::Int, C::Matrix{UInt}, j2::Int, mask::UInt, N::Int)
   flag = true
   for k = 1:N
     A[k, i] = reinterpret(UInt, reinterpret(Int, B[k, j1]) - reinterpret(Int, C[k, j2]))
      if (A[k, i] & mask != 0)
         flag = false
      end
   end
   return flag
end

# Return true is the j-th exponent vector of the array B can be halved
# If so the i-th exponent i-th exponent vector of A is set to the half
function monomial_halves!(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, mask::UInt, N::Int)
   flag = true
   for k = 1:N
      b = reinterpret(Int, B[k, j])
      if isodd(b)
         flag = false
      else
         A[k, i] = reinterpret(UInt, div(b, 2))
      end
      if A[k, i] & mask != 0
         flag = false
      end
   end
   return flag
end

# Return true if the i-th exponent vector of the array A is in an overflow
# condition. Note that a mask must be supplied which has 1's in all bit
# positions that correspond to an overflow of the corresponding exponent field.
# Used for overflow detection inside algorithms.
function monomial_overflows(A::Matrix{UInt}, i::Int, mask::UInt, N::Int)
   for k = 1:N
      if (A[k, i] & mask) != UInt(0)
         return true
      end
   end
   return false
end

# Return a positive integer if the i-th exponent vector of the array A is
# bigger than the j-th exponent vector of B with respect to the ordering,
# zero if it is equal and a negative integer if it is less. (Used to compare
# monomials with respect to an ordering.)
function monomial_cmp(A::Matrix{UInt}, i::Int, B::Matrix{UInt}, j::Int, N::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
   if N == 0
      return 0
   end
   k = N
   while k > 1 && A[k, i] == B[k, j]
      k -= 1
   end
   if R.ord == :degrevlex
      return k == N ? reinterpret(Int, (xor(drmask, A[k, i])) - (xor(drmask, B[k, j]))) : reinterpret(Int, B[k, j] - A[k, i])
   else
      return reinterpret(Int, A[k, i] - B[k, j])
   end
end

###############################################################################
#
#   Basic manipulation
#
###############################################################################

function Base.hash(x::MPoly{T}, h::UInt) where {T <: RingElement}
   b = 0x53dd43cd511044d1%UInt
   b = xor(b, xor(Base.hash(x.exps, h), h))
   for i in 1:length(x)
      b = xor(b, xor(hash(x.coeffs[i], h), h))
      b = (b << 1) | (b >> (sizeof(Int)*8 - 1))
   end
   return b
end

@doc raw"""
    is_gen(x::MPoly{T}) where {T <: RingElement}

Return `true` if the given polynomial is a generator (variable) of the
polynomial ring it belongs to.
"""
function is_gen(x::MPoly{T}) where {T <: RingElement}
   if length(x) != 1
      return false
   end
   if !isone(coeff(x, 1))
      return false
   end

   N = size(x.exps, 1)
   ord = internal_ordering(parent(x))
   if ord == :lex
      exps = x.exps
      for k = 1:N
         exp = exps[k, 1]
         if exp != UInt(0)
            if exp != UInt(1)
               return false
            end
            for j = k + 1:N
               if exps[j, 1] != UInt(0)
                  return false
               end
            end
            return true
         end
      end
      return false
   elseif ord == :deglex
      return x.exps[N, 1] == UInt(1)
   elseif ord == :degrevlex
      return x.exps[N, 1] == UInt(1)
   else
      error("invalid ordering")
   end
end

function AbstractAlgebra._is_gen_with_index(x::MPoly)
   ord = internal_ordering(parent(x))
   N = nvars(parent(x))
   if length(x) != 1
      return false, 0
   end
   if !isone(coeff(x, 1))
      return false, 0
   end
   if ord === :degrevlex || ord === :deglex
     if x.exps[N + 1, 1] != UInt(1)
       return false, 0
     end
   end
   exps = x.exps
   for k = 1:N
     exp = exps[k, 1]
     if exp != UInt(0)
       if exp != UInt(1)
         return false, 0
       end
       for j = k + 1:N
         if exps[j, 1] != UInt(0)
           return false, 0
         end
       end
       if ord === :degrevlex
         return true, k
       else
         # in the :lex and :deglex case, the "last" variables come frst in the row
         return true, N - k + 1
       end
     end
   end
   return false, 0
 end

@doc raw"""
    is_homogeneous(x::MPoly{T}) where {T <: RingElement}

Return `true` if the given polynomial is homogeneous with respect to the standard grading and `false` otherwise.
"""
function is_homogeneous(x::MPoly{T}) where {T <: RingElement}
   last_deg = 0
   is_first = true

   for e in exponent_vectors(x)
      d = sum(e)
      if !is_first
         if d != last_deg
            return false
         else
            last_deg = d
         end
      else
         is_first = false
         last_deg = d
      end
   end
   return true
end

@doc raw"""
    coeff(x::MPoly, i::Int)

Return the coefficient of the $i$-th term of the polynomial.
"""
function coeff(x::MPoly, i::Int)
   return x.coeffs[i]
end

function trailing_coefficient(p::MPoly{T}) where T <: RingElement
   if iszero(p)
      return zero(base_ring(p))
   else
      return coeff(p, length(p))
   end
end

@doc raw"""
    monomial(x::MPoly, i::Int)

Return the monomial of the $i$-th term of the polynomial (as a polynomial
of length $1$ with coefficient $1$).
"""
function monomial(x::MPoly, i::Int)
   R = base_ring(x)
   N = size(x.exps, 1)
   exps = Matrix{UInt}(undef, N, 1)
   monomial_set!(exps, 1, x.exps, i, N)
   return parent(x)([one(R)], exps)
end

@doc raw"""
    monomial!(m::Mpoly{T}, x::MPoly{T}, i::Int) where T <: RingElement

Set $m$ to the monomial of the $i$-th term of the polynomial (as a
polynomial of length $1$ with coefficient $1$.
"""
function monomial!(m::MPoly{T}, x::MPoly{T}, i::Int) where T <: RingElement
   N = size(x.exps, 1)
   fit!(m, 1)
   monomial_set!(m.exps, 1, x.exps, i, N)
   m.coeffs[1] = one(base_ring(x))
   m.length = 1
   return m
end

@doc raw"""
    term(x::MPoly, i::Int)

Return the $i$-th nonzero term of the polynomial $x$ (as a polynomial).
"""
function term(x::MPoly, i::Int)
   R = base_ring(x)
   N = size(x.exps, 1)
   exps = Matrix{UInt}(undef, N, 1)
   monomial_set!(exps, 1, x.exps, i, N)
   return parent(x)([deepcopy(x.coeffs[i])], exps)
end

@doc raw"""
    max_fields(f::MPoly{T}) where {T <: RingElement}

Return a tuple `(degs, biggest)` consisting of an array `degs` of the maximum
exponent for each field in the exponent vectors of `f` and an integer which
is the largest of the entries in `degs`. The array `degs` will have `n + 1`
entries in the case of a degree ordering, or `n` otherwise, where `n` is the
number of variables of the polynomial ring `f` belongs to. The fields are
returned in the order they exist in the internal representation (which is not
intended to be specified, and not needed for current applications).
"""
function max_fields(f::MPoly{T}) where {T <: RingElement}
   A = f.exps
   N = size(A, 1)
   if N == 0
      return Int[], 0
   end
   biggest = zeros(Int, N)
   for i = 1:length(f)
      for k = 1:N
         if reinterpret(Int, A[k, i]) > biggest[k]
            biggest[k] = reinterpret(Int, A[k, i])
         end
      end
   end
   b = biggest[1]
   for k = 2:N
      if biggest[k] > b
         b = biggest[k]
      end
   end
   return biggest, b
end

function degree(f::MPoly{T}, i::Int) where T <: RingElement
   A = f.exps
   N = size(A, 1)

   ord = internal_ordering(parent(f))
   if ord == :lex
      if i == 1   # small optimization
         return length(f) == 0 ? -1 : Int(A[N, 1])
      end
      i = N - i + 1
   elseif ord == :deglex
      i = N - i
   elseif ord == :degrevlex
      # do nothing
   else
      error("invalid ordering")
   end

   biggest = -1
   for j = 1:length(f)
      d = Int(A[i, j])
      if d > biggest
         biggest = d
      end
   end
   return biggest
end

@doc raw"""
    total_degree(f::MPoly{T}) where {T <: RingElement}

Return the total degree of `f`.
"""
function total_degree(f::MPoly{T}) where {T <: RingElement}
   A = f.exps
   N = size(A, 1)
   ord = internal_ordering(parent(f))
   if ord == :lex
      if N == 1
         return length(f) == 0 ? -1 : Int(A[1, N])
      end
      max_deg = -1
      for i = 1:length(f)
         sum_deg = 0
         for k = 1:N
            sum_deg += A[k, i]
            sum_deg < A[k, i] && error("Integer overflow in total_degree")
         end
         if sum_deg > max_deg
            max_deg = sum_deg
         end
      end
      return Int(max_deg) # Julia already checks this for overflow
   elseif ord == :deglex || ord == :degrevlex
      return length(f) == 0 ? -1 : Int(A[N, 1])
   else
      error("total_degree is not implemented for this ordering.")
   end
end

@doc raw"""
    length(x::MPoly)

Return the number of terms of the polynomial.
"""
length(x::MPoly) = x.length

isone(x::MPoly) = is_trivial(parent(x)) || (x.length == 1 && monomial_iszero(x.exps, 1, size(x.exps, 1)) && is_one(x.coeffs[1]))

is_constant(x::MPoly) = x.length == 0 || (x.length == 1 && monomial_iszero(x.exps, 1, size(x.exps, 1)))

function Base.deepcopy_internal(a::MPoly{T}, dict::IdDict) where {T <: RingElement}
   Re = deepcopy_internal(a.exps, dict)
   Rc = Vector{T}(undef, a.length)
   for i = 1:a.length
      Rc[i] = deepcopy(a.coeffs[i])
   end
   return parent(a)(Rc, Re)
end

Base.copy(f::Generic.MPoly) = deepcopy(f)

###############################################################################
#
#   Iterators
#
###############################################################################

function Base.iterate(x::MPolyCoeffs)
   if length(x.poly) >= 1
      return coeff(x.poly, 1), 1
   else
      return nothing
   end
end

function Base.iterate(x::MPolyCoeffs, state)
   state += 1
   if length(x.poly) >= state
      return coeff(x.poly, state), state
   else
      return nothing
   end
end

function Base.iterate(x::MPolyExponentVectors)
   if length(x.poly) >= 1
      return exponent_vector(x.poly, 1), 1
   else
      return nothing
   end
end

function Base.iterate(x::MPolyExponentVectors, state)
   state += 1
   if length(x.poly) >= state
      return exponent_vector(x.poly, state), state
   else
      return nothing
   end
end

function Base.iterate(x::MPolyTerms)
   if length(x.poly) >= 1
      return term(x.poly, 1), 1
   else
      return nothing
   end
end

function Base.iterate(x::MPolyTerms, state)
   state += 1
   if length(x.poly) >= state
      return term(x.poly, state), state
   else
      return nothing
   end
end

function Base.iterate(x::MPolyMonomials)
   if length(x.poly) >= 1
      return monomial(x.poly, 1), 1
   else
      return nothing
   end
end

function Base.iterate(x::MPolyMonomials, state)
   state += 1
   if length(x.poly) >= state
      return monomial(x.poly, state), state
   else
      return nothing
   end
end

function Base.length(x::Union{MPolyCoeffs, MPolyExponentVectors, MPolyTerms, MPolyMonomials})
   return length(x.poly)
end

function Base.eltype(::Type{MPolyCoeffs{T}}) where T <: AbstractAlgebra.MPolyRingElem{S} where S <: RingElement
   return S
end

function Base.eltype(::Type{MPolyExponentVectors{T}}) where T <: AbstractAlgebra.MPolyRingElem{S} where S <: RingElement
   return Vector{Int}
end

function Base.eltype(::Type{MPolyMonomials{T}}) where T <: AbstractAlgebra.MPolyRingElem{S} where S <: RingElement
   return T
end

function Base.eltype(::Type{MPolyTerms{T}}) where T <: AbstractAlgebra.MPolyRingElem{S} where S <: RingElement
   return T
end

###############################################################################
#
#   Geobuckets
#
###############################################################################

mutable struct geobucket{T}
   len::Int
   buckets::Vector{T}

   function geobucket(R::Ring)
      return new{elem_type(R)}(1, [R(), R()])
   end
end

function Base.push!(G::geobucket{T}, p::T) where T
   R = parent(p)
   i = max(1, ndigits(length(p), base=4))
   l = length(G.buckets)
   if length(G.buckets) < i
     resize!(G.buckets, i)
     for j in (l + 1):i
       G.buckets[j] = zero(R)
     end
   end
   G.buckets[i] = add!(G.buckets[i], p)
   while i <= G.len
      if length(G.buckets[i]) >= 4^i
         G.buckets[i + 1] = add!(G.buckets[i + 1], G.buckets[i])
         G.buckets[i] = R()
         i += 1
      end
      break
   end
   if i == G.len + 1
      Base.push!(G.buckets, R())
      G.len += 1
   end
end

function finish(G::geobucket{T}) where T
   p = G.buckets[1]
   for i = 2:length(G.buckets)
      p = add!(p, G.buckets[i])
   end
   return p::T
end

###############################################################################
#
#   Arithmetic functions
#
###############################################################################

function -(a::MPoly{T}) where {T <: RingElement}
   N = size(a.exps, 1)
   r = zero(a)
   fit!(r, length(a))
   for i = 1:length(a)
      r.coeffs[i] = -a.coeffs[i]
      monomial_set!(r.exps, i, a.exps, i, N)
   end
   r.length = a.length
   return r
end

function +(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   N = size(a.exps, 1)
   par = parent(a)
   r = par()
   fit!(r, length(a) + length(b))
   i = 1
   j = 1
   k = 1
   while i <= length(a) && j <= length(b)
      cmpexp = monomial_cmp(a.exps, i, b.exps, j, N, par, UInt(0))
      if cmpexp > 0
         r.coeffs[k] = a.coeffs[i]
         monomial_set!(r.exps, k, a.exps, i, N)
         i += 1
      elseif cmpexp == 0
         c = a.coeffs[i] + b.coeffs[j]
         if !iszero(c)
            r.coeffs[k] = c
            monomial_set!(r.exps, k, a.exps, i, N)
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         r.coeffs[k] = b.coeffs[j]
         monomial_set!(r.exps, k, b.exps, j, N)
         j += 1
      end
      k += 1
   end
   while i <= length(a)
      r.coeffs[k] = a.coeffs[i]
      monomial_set!(r.exps, k, a.exps, i, N)
      i += 1
      k += 1
   end
   while j <= length(b)
      r.coeffs[k] = b.coeffs[j]
      monomial_set!(r.exps, k, b.exps, j, N)
      j += 1
      k += 1
   end
   r.length = k - 1
   return r
end

function -(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   N = size(a.exps, 1)
   par = parent(a)
   r = par()
   fit!(r, length(a) + length(b))
   i = 1
   j = 1
   k = 1
   while i <= length(a) && j <= length(b)
      cmpexp = monomial_cmp(a.exps, i, b.exps, j, N, par, UInt(0))
      if cmpexp > 0
         r.coeffs[k] = a.coeffs[i]
         monomial_set!(r.exps, k, a.exps, i, N)
         i += 1
      elseif cmpexp == 0
         c = a.coeffs[i] - b.coeffs[j]
         if !iszero(c)
            r.coeffs[k] = c
            monomial_set!(r.exps, k, a.exps, i, N)
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         r.coeffs[k] = -b.coeffs[j]
         monomial_set!(r.exps, k, b.exps, j, N)
         j += 1
      end
      k += 1
   end
   while i <= length(a)
      r.coeffs[k] = a.coeffs[i]
      monomial_set!(r.exps, k, a.exps, i, N)
      i += 1
      k += 1
   end
   while j <= length(b)
      r.coeffs[k] = -b.coeffs[j]
      monomial_set!(r.exps, k, b.exps, j, N)
      j += 1
      k += 1
   end
   r.length = k - 1
   return r
end

function do_copy(Ac::Vector{T}, Bc::Vector{T},
               Ae::Matrix{UInt}, Be::Matrix{UInt},
        s1::Int, r::Int, n1::Int, par::MPolyRing{T}) where {T <: RingElement}
   N = size(Ae, 1)
   for i = 1:n1
      Bc[r + i] = Ac[s1 + i]
      monomial_set!(Be, r + i, Ae, s1 + i, N)
   end
   return n1
end

function do_merge(Ac::Vector{T}, Bc::Vector{T},
               Ae::Matrix{UInt}, Be::Matrix{UInt},
        s1::Int, s2::Int, r::Int, n1::Int, n2::Int, par::MPolyRing{T}) where {T <: RingElement}
   i = 1
   j = 1
   k = 1
   N = size(Ae, 1)
   while i <= n1 && j <= n2
      cmpexp = monomial_cmp(Ae, s1 + i, Ae, s2 + j, N, par, UInt(0))
      if cmpexp > 0
         Bc[r + k] = Ac[s1 + i]
         monomial_set!(Be, r + k, Ae, s1 + i, N)
         i += 1
      elseif cmpexp == 0
         Ac[s1 + i] = add!(Ac[s1 + i], Ac[s2 + j])
         if !iszero(Ac[s1 + i])
            Bc[r + k] = Ac[s1 + i]
            monomial_set!(Be, r + k, Ae, s1 + i, N)
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         Bc[r + k] = Ac[s2 + j]
         monomial_set!(Be, r + k, Ae, s2 + j, N)
         j += 1
      end
      k += 1
   end
   while i <= n1
      Bc[r + k] = Ac[s1 + i]
      monomial_set!(Be, r + k, Ae, s1 + i, N)
      i += 1
      k += 1
   end
   while j <= n2
      Bc[r + k] = Ac[s2 + j]
      monomial_set!(Be, r + k, Ae, s2 + j, N)
      j += 1
      k += 1
   end
   return k - 1
end

function mul_classical(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   if m == 0 || n == 0
      return par()
   end
   a_alloc = max(m, n) + n
   b_alloc = max(m, n) + n
   Ac = Vector{T}(undef, a_alloc)
   Bc = Vector{T}(undef, b_alloc)
   N = parent(a).N
   Ae = zeros(UInt, N, a_alloc)
   Be = zeros(UInt, N, b_alloc)
   Am = zeros(Int, 64) # 64 is upper bound on max(Base.log m, Base.log n)
   Bm = zeros(Int, 64) # ... num polys merged (power of 2)
   Ai = zeros(Int, 64) # index of polys in A minus 1
   Bi = zeros(Int, 64) # index of polys in B minus 1
   An = zeros(Int, 64) # lengths of polys in A
   Bn = zeros(Int, 64) # lengths of polys in B
   Anum = 0 # number of polys in A
   Bnum = 0 # number of polys in B
   sa = 0 # number of used locations in A
   sb = 0 # number of used locations in B
   for i = 1:m # loop over monomials in a
      # check space
      if sa + n > a_alloc
         a_alloc = max(2*a_alloc, sa + n)
         resize!(Ac, a_alloc)
         Ae = resize_exps!(Ae, a_alloc)
      end
      # compute monomial by polynomial product and store in A
      c = a.coeffs[i]
      k = 1
      for j = 1:n
         s = Ac[sa + k] = c*b.coeffs[j]
         if !iszero(s)
            monomial_add!(Ae, sa + k, b.exps, j, a.exps, i, N)
            k += 1
         end
      end
      k -= 1
      Anum += 1
      Am[Anum] = 1
      Ai[Anum] = sa
      An[Anum] = k
      sa += k
      # merge similar sized polynomials from A to B...
      while Anum > 1 && (Am[Anum] == Am[Anum - 1])
         # check space
         want = sb + An[Anum] + An[Anum - 1]
         if want > b_alloc
            b_alloc = max(2*b_alloc, want)
            resize!(Bc, b_alloc)
            Be = resize_exps!(Be, b_alloc)
         end
         # do merge to B
         k = do_merge(Ac, Bc, Ae, Be, Ai[Anum - 1], Ai[Anum],
                                               sb, An[Anum - 1], An[Anum], par)
         Bnum += 1
         Bm[Bnum] = 2*Am[Anum]
         Bi[Bnum] = sb
         Bn[Bnum] = k
         sb += k
         sa -= An[Anum]
         sa -= An[Anum - 1]
         Anum -= 2
         # merge similar sized polynomials from B to A...
         if Bnum > 1 && (Bm[Bnum] == Bm[Bnum - 1])
            # check space
            want = sa + Bn[Bnum] + Bn[Bnum - 1]
            if want > a_alloc
               a_alloc = max(2*a_alloc, want)
               resize!(Ac, a_alloc)
               Ae = resize_exps!(Ae, a_alloc)
            end
            # do merge to A
            k = do_merge(Bc, Ac, Be, Ae, Bi[Bnum - 1], Bi[Bnum],
                                               sa, Bn[Bnum - 1], Bn[Bnum], par)
            Anum += 1
            Am[Anum] = 2*Bm[Bnum]
            Ai[Anum] = sa
            An[Anum] = k
            sa += k
            sb -= Bn[Bnum]
            sb -= Bn[Bnum - 1]
            Bnum -= 2
         end
      end
   end
   # Add all irregular sized polynomials together
   while Anum + Bnum > 1
      # Find the smallest two polynomials
      if Anum == 0 || Bnum == 0
         c1 = c2 = (Anum == 0) ? 2 : 1
      elseif Anum + Bnum == 2
         c1 = (Am[Anum] < Bm[Bnum]) ? 1 : 2
         c2 = 3 - c1
      elseif Am[Anum] < Bm[Bnum]
         c1 = 1
         c2 = (Anum == 1 || (Bnum > 1 && Bm[Bnum] < Am[Anum - 1])) ? 2 : 1
      else
         c1 = 2
         c2 = (Bnum == 1 || (Anum > 1 && Am[Anum] < Bm[Bnum - 1])) ? 1 : 2
      end
      # If both polys are on side A, merge to side B
      if c1 == 1 && c2 == 1
         # check space
         want = sb + An[Anum] + An[Anum - 1]
         if want > b_alloc
            b_alloc = max(2*b_alloc, want)
            resize!(Bc, b_alloc)
            Be = resize_exps!(Be, b_alloc)
         end
         # do merge to B
         k = do_merge(Ac, Bc, Ae, Be, Ai[Anum - 1], Ai[Anum],
                                               sb, An[Anum - 1], An[Anum], par)
         Bnum += 1
         Bm[Bnum] = 2*Am[Anum - 1]
         Bi[Bnum] = sb
         Bn[Bnum] = k
         sb += k
         sa -= An[Anum]
         sa -= An[Anum - 1]
         Anum -= 2
      # If both polys are on side B, merge to side A
      elseif c1 == 2 && c2 == 2
         # check space
         want = sa + Bn[Bnum] + Bn[Bnum - 1]
         if want > a_alloc
            a_alloc = max(2*a_alloc, want)
            resize!(Ac, a_alloc)
            Ae = resize_exps!(Ae, a_alloc)
         end
         # do merge to A
         k = do_merge(Bc, Ac, Be, Ae, Bi[Bnum - 1], Bi[Bnum],
                                            sa, Bn[Bnum - 1], Bn[Bnum], par)
         Anum += 1
         Am[Anum] = 2*Bm[Bnum - 1]
         Ai[Anum] = sa
         An[Anum] = k
         sa += k
         sb -= Bn[Bnum]
         sb -= Bn[Bnum - 1]
         Bnum -= 2
      # Polys are on different sides, move from smallest side to largest
      else
         # smallest poly on side A, move to B
         if c1 == 1
            # check space
            want = sb + An[Anum]
            if want > b_alloc
               b_alloc = max(2*b_alloc, want)
               resize!(Bc, b_alloc)
               Be = resize_exps!(Be, b_alloc)
            end
            # do copy to B
            k = do_copy(Ac, Bc, Ae, Be, Ai[Anum], sb, An[Anum], par)
            Bnum += 1
            Bm[Bnum] = Am[Anum]
            Bi[Bnum] = sb
            Bn[Bnum] = k
            sb += k
            sa -= An[Anum]
            Anum -= 1
         # smallest poly on side B, move to A
         else
            # check space
            want = sa + Bn[Bnum]
            if want > a_alloc
               a_alloc = max(2*a_alloc, want)
               resize!(Ac, a_alloc)
               Ae = resize_exps!(Ae, a_alloc)
            end
            # do copy to A
            k = do_copy(Bc, Ac, Be, Ae, Bi[Bnum], sa, Bn[Bnum], par)
            Anum += 1
            Am[Anum] = Bm[Bnum]
            Ai[Anum] = sa
            An[Anum] = k
            sa += k
            sb -= Bn[Bnum]
            Bnum -= 1
         end
      end
   end
   # Result is on side A
   if Anum == 1
      resize!(Ac, An[1])
      Ae = resize_exps!(Ae, An[1])
      return parent(a)(Ac, Ae)
   # Result is on side B
   else
      resize!(Bc, Bn[1])
      Be = resize_exps!(Be, Bn[1])
      return parent(a)(Bc, Be)
   end
end

abstract type heap end

struct heap_s
   exp::Int
   n::Int
end

struct heap_t
   i::Int
   j::Int
   next::Int
end

struct nheap_t
   i::Int
   j::Int
   p::Int # polynomial, for heap algorithms that work with multiple polynomials
   next::Int
end

heapleft(i::Int) = 2i
heapright(i::Int) = 2i + 1
heapparent(i::Int) = div(i, 2)

# either chain (exp, x) or insert into heap
function heapinsert!(xs::Vector{heap_s}, ys::Vector{heap_t}, m::Int, exp::Int, exps::Matrix{UInt}, N::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
   i = n = length(xs) + 1
   @inbounds if i != 1 && monomial_isequal(exps, exp, xs[1].exp, N)
      ys[m] = heap_t(ys[m].i, ys[m].j, xs[1].n)
      xs[1] = heap_s(xs[1].exp, m)
      return false
   end
   @inbounds while (j = heapparent(i)) >= 1
      if monomial_isequal(exps, exp, xs[j].exp, N)
         ys[m] = heap_t(ys[m].i, ys[m].j, xs[j].n)
         xs[j] = heap_s(xs[j].exp, m)
         return false
      elseif monomial_isless(exps, xs[j].exp, exp, N, R, drmask)
         i = j
      else
         break
      end
   end
   push!(xs, heap_s(exp, 0))
   @inbounds while n > i
      xs[n] = xs[heapparent(n)]
      n >>= 1
   end
   xs[i] = heap_s(exp, m)
   return true
end

function nheapinsert!(xs::Vector{heap_s}, ys::Vector{nheap_t}, m::Int, exp::Int, exps::Matrix{UInt}, N::Int, p::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
   i = n = length(xs) + 1
   @inbounds if i != 1 && monomial_isequal(exps, exp, xs[1].exp, N)
      ys[m] = nheap_t(ys[m].i, ys[m].j, p, xs[1].n)
      xs[1] = heap_s(xs[1].exp, m)
      return false
   end
   @inbounds while (j = heapparent(i)) >= 1
      if monomial_isequal(exps, exp, xs[j].exp, N)
         ys[m] = nheap_t(ys[m].i, ys[m].j, p, xs[j].n)
         xs[j] = heap_s(xs[j].exp, m)
         return false
      elseif monomial_isless(exps, xs[j].exp, exp, N, R, drmask)
         i = j
      else
         break
      end
   end
   push!(xs, heap_s(exp, 0))
   @inbounds while n > i
      xs[n] = xs[heapparent(n)]
      n >>= 1
   end
   xs[i] = heap_s(exp, m)
   return true
end

function heappop!(xs::Vector{heap_s}, exps::Matrix{UInt}, N::Int, R::MPolyRing{T}, drmask::UInt) where {T <: RingElement}
   s = length(xs)
   x = xs[1]
   i = 1
   j = 2
   @inbounds while j < s
      if !monomial_isless(exps, xs[j + 1].exp, xs[j].exp, N, R, drmask)
         j += 1
      end
      xs[i] = xs[j]
      i = j
      j *= 2
   end
   exp = xs[s].exp
   j = i >> 1
   @inbounds while i > 1 && monomial_isless(exps, xs[j].exp, exp, N, R, drmask)
      xs[i] = xs[j]
      i = j
      j >>= 1
   end
   xs[i] = xs[s]
   pop!(xs)
   return x.exp
end

function mul_johnson(a::MPoly{T}, b::MPoly{T}, bits::Int) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   if m == 0 || n == 0
      return par()
   end
   drmask = monomial_drmask(par, bits)
   N = size(a.exps, 1)
   H = Vector{heap_s}(undef, 0)
   I = Vector{heap_t}(undef, 0)
   Exps = zeros(UInt, N, m + 1)
   Viewn = [i for i in 1:m + 1]
   viewc = m + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_add!(Exps, vw, a.exps, 1, b.exps, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, heap_t(1, 1, 0))
   r_alloc = max(m, n) + n
   Rc = Vector{T}(undef, r_alloc)
   Re = zeros(UInt, N, r_alloc)
   k = 0
   c = R()
   Q = zeros(Int, 0)
   @inbounds while !isempty(H)
      exp = H[1].exp
      k += 1
      if k > r_alloc
         r_alloc *= 2
         resize!(Rc, r_alloc)
         Re = resize_exps!(Re, r_alloc)
      end
      first = true
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if first
            Rc[k] = a.coeffs[v.i]*b.coeffs[v.j]
            monomial_set!(Re, k, Exps, exp, N)
            first = false
         else
            Rc[k] = addmul_delayed_reduction!(Rc[k], a.coeffs[v.i], b.coeffs[v.j], c)
         end
         if v.j < n || v.j == 1
            push!(Q, x.n)
         end
         while (xn = v.next) != 0
            v = I[xn]
            Rc[k] = addmul_delayed_reduction!(Rc[k], a.coeffs[v.i], b.coeffs[v.j], c)
            if v.j < n || v.j == 1
               push!(Q, xn)
            end
         end
      end
      Rc[k] = reduce!(Rc[k])
      @inbounds while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.j == 1 && v.i < m
            push!(I, heap_t(v.i + 1, 1, 0))
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, a.exps, v.i + 1, b.exps, 1, N)
            if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
               viewc -= 1
            end
         end
         if v.j < n
            I[xn] = heap_t(v.i, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, a.exps, v.i, b.exps, v.j + 1, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert v into heap
               viewc -= 1
            end
         end
      end
      if iszero(Rc[k])
         k -= 1
      end
   end
   resize!(Rc, k)
   Re = resize_exps!(Re, k)
   return parent(a)(Rc, Re)
end

# Pack the monomials from the array b into an array a, with k entries packed
# into each word, and where each field is the given number of bits
function pack_monomials(a::Matrix{UInt}, b::Matrix{UInt}, k::Int, bits::Int, len::Int)
   for i = 1:len
      m = 0
      n = 1
      v = UInt(0)
      N = size(b, 1)
      for j = 1:N
         v += (b[j, i] << (bits*m))
         m += 1
         if m == k
            m = 0
            a[n, i] = v
            n += 1
            v = UInt(0)
         end
      end
      if m != 0
         a[n, i] = v
      end
   end
   nothing
end

# Unpack the monomials from the array b into the array a, where there are k
# entries packed into each word, in fields of the given number of bits
function unpack_monomials(a::Matrix{UInt}, b::Matrix{UInt}, k::Int, bits::Int, len::Int)
   mask = (UInt(1) << bits) - UInt(1)
   for i = 1:len
      m = 0
      n = 1
      N = size(a, 1)
      for j = 1:N
         a[j, i] = ((b[n, i] >> (m*bits)) & mask)
         m += 1
         if m == k
            m = 0
            n += 1
         end
      end
   end
end

function *(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   v1, d1 = max_fields(a)
   v2, d2 = max_fields(b)
   v = v1 + v2
   d = 0
   for i = 1:length(v)
      if v[i] < 0
         error("Exponent overflow in mul_johnson")
      end
      if v[i] > d
         d = v[i]
      end
   end
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         max_e = 2^(exp_bits - 1)
         break
      else
         max_e = 2^(exp_bits - 1)
      end
   end
   word_bits = sizeof(Int)*8
   k = div(word_bits, exp_bits)
   N = parent(a).N
   if k != 1
      M = div(N + k - 1, k)
      e1 = zeros(UInt, M, length(a))
      e2 = zeros(UInt, M, length(b))
      pack_monomials(e1, a.exps, k, exp_bits, length(a))
      pack_monomials(e2, b.exps, k, exp_bits, length(b))
      par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
      a1 = par(a.coeffs, e1)
      b1 = par(b.coeffs, e2)
      a1.length = a.length
      b1.length = b.length
      if a1.length < b1.length
         r1 = mul_johnson(a1, b1, exp_bits)
      else
         r1 = mul_johnson(b1, a1, exp_bits)
      end
      er = zeros(UInt, N, length(r1))
      unpack_monomials(er, r1.exps, k, exp_bits, length(r1))
   else
      r1 = mul_johnson(a, b, exp_bits)
      er = r1.exps
   end
   return parent(a)(r1.coeffs, er)
end

###############################################################################
#
#   Square root
#
###############################################################################

function sqrt_classical_char2(a::MPoly{T}; check::Bool=true) where {T <: RingElement}
   par = parent(a)
   m = length(a)
   if m == 0
      return true, par()
   end
   # number of words in (possibly packed) exponent
   N = size(a.exps, 1)
   # compute mask
   bits = sizeof(Int)*8
   mask = UInt(1) << (bits - 1)
   # alloc arrays for result coeffs/exps
   Qc = Vector{T}(undef, m)
   Qe = zeros(UInt, N, m)
   # compute square root
   for i = 1:m
      d1 = monomial_halves!(Qe, i, a.exps, i, mask, N)
      if check
         d2 = is_square(a.coeffs[i])
      end
      if check && !d1 || !d2
         return false, par()
      end
      Qc[i] = sqrt(a.coeffs[i]; check=check)
   end
   return true, par(Qc, Qe) # return result
end

function sqrt_heap(a::MPoly{T}, bits::Int; check::Bool=true) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   if m == 0
      return true, par()
   end
   # ordering mask
   drmask = monomial_drmask(par, bits)
   # mask for checking for overflows in halves!
   mask1 = UInt(1) << (bits - 1)
   mask = UInt(0)
   for i = 1:div(sizeof(UInt)*8, bits)
      mask = (mask << bits) + mask1
   end
   # number of words in (possibly packed) exponent
   N = size(a.exps, 1)
   # Initialise heap
   H = Vector{heap_s}(undef, 0)
   I = Vector{heap_t}(undef, 0)
   viewc = 1
   Viewn = [1, 2]
   viewalloc = 2
   Exps = zeros(UInt, N, 2)
   # set up heap
   if m > 1
      vw = Viewn[viewc]
      viewc += 1
      monomial_set!(Exps, vw, a.exps, 2, N)
      push!(H, heap_s(vw, 1))
      push!(I, heap_t(0, 2, 0))
   end
   # number of result terms
   k = 1
   # alloc arrays for result coeffs/exps
   q_alloc = Int(floor(Base.sqrt(m)) + 1)
   Qc = Vector{T}(undef, q_alloc)
   Qe = zeros(UInt, N, q_alloc)
   # temporary for addmul
   c = R()
   # for accumulation of cross multiplications
   qc = R()
   # for multiplication by -1 in addmul
   m1 = -one(R)
   # Queue for processing next nodes into heap
   Q = zeros(Int, 0)
   reuse = zeros(Int, 0)
   # get leading coeff of sqrt
   d1 = monomial_halves!(Qe, 1, a.exps, 1, mask, N)
   d2 = check ? is_square(a.coeffs[1]) : true
   if check && !d1 || !d2
      return false, par()
   end
   Qc[1] = sqrt(a.coeffs[1]; check=check)
   mb = -2*Qc[1]
   # if exact sqrt is not checked, compute last exponent that needs dealing with
   if !check
      Fe = zeros(UInt, N, 1)
      monomial_halves!(Fe, 1, a.exps, m, mask, N)
      monomial_add!(Fe, 1, Fe, 1, Qe, 1, N)
   end
   # while the heap is not empty
   @inbounds while !isempty(H)
      # get next exponent from heap
      exp = H[1].exp
      # make space for additional result term
      k += 1
      if k > q_alloc
         q_alloc *= 2
         resize!(Qc, q_alloc)
         Qe = resize_exps!(Qe, q_alloc)
      end
      # check if next heap exponent is divisible by leading term
      d1 = monomial_divides!(Qe, k, Exps, exp, Qe, 1, mask, N)
      do_coeffs = check || d1
      # deal with each heap chain matching exp
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         # get first node from heap chain
         x = H[1]
         viewc -= 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if do_coeffs
            if v.i == 0 # term from original poly
               qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
            elseif v.i == v.j # term from cross multiplication
               qc = addmul_delayed_reduction!(qc, Qc[v.i], Qc[v.j], c)
            else
               c = mul_red!(c, Qc[v.i], Qc[v.j], false) # qc += 2*Q[i]*Q[j]
               qc = add!(qc, c)
               qc = add!(qc, c)
            end
         end
         # decide whether node needs processing or reusing
         if v.i != 0 || v.j < m
            push!(Q, x.n)
         else
            push!(reuse, x.n)
         end
         # deal with other nodes in current chain
         while (xn = v.next) != 0
            v = I[xn]
            if do_coeffs
               if v.i == 0 # term from original poly
                  qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
               elseif v.i == v.j # term from cross multiplication
                  qc = addmul_delayed_reduction!(qc, Qc[v.i], Qc[v.j], c)
               else
                  c = mul_red!(c, Qc[v.i], Qc[v.j], false) # qc += 2*Q[i]*Q[j]
                  qc = add!(qc, c)
                  qc = add!(qc, c)
               end
            end
            # decide whether node needs processing or reusing
            if v.i != 0 || v.j < m
               push!(Q, xn)
            else
               push!(reuse, xn)
            end
         end
      end
      # reduction was delayed, do it now
      if do_coeffs
         qc = reduce!(qc)
      end
      # put next items into heap by processing Q
      @inbounds while !isempty(Q)
         # get item from Q
         xn = pop!(Q)
         v = I[xn]
         if v.i == 0 # term from original poly
            # put next poly term in heap
            I[xn] = heap_t(0, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_set!(Exps, vw, a.exps, v.j + 1, N)
            if check || monomial_cmp(Exps, vw, Fe, 1, N, par, drmask) >= 0
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc += 1
               end
            end
         elseif v.j < v.i # term from cross mult
            # i, j -> i, j + 1 and put on heap
            I[xn] = heap_t(v.i, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, Qe, v.i, Qe, v.j + 1, N)
            if check || monomial_cmp(Exps, vw, Fe, 1, N, par, drmask) >= 0
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc += 1
               end
            end
         elseif v.j == k - 1 || v.j >= v.i # no new term to add
            push!(reuse, xn)
         end
      end
      # if terms from heap combine to zero, remove new result term
      if iszero(qc)
         k -= 1
      else
         # if not, check the accumulation is divisible by leading coeff
         if check
            d2, Qc[k] = divides(qc, mb)
         else
            d2, Qc[k] = true, divexact(qc, mb; check=check)
         end
         if check && !d1 || !d2 # if accumulation term is not divisible, return false
            return false, par()
         end
         viewalloc += 1
         push!(Viewn, viewalloc)
         Exps = resize_exps!(Exps, viewalloc)
         if !isempty(reuse) # if we have nodes in cache that we can reuse
            xn = pop!(reuse)
            I[xn] = heap_t(k, 2, 0) # put (k, 2) on heap
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, Qe, k, Qe, 2, N)
            if check || monomial_cmp(Exps, vw, Fe, 1, N, par, drmask) >= 0
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc += 1
               end
            end
         else # create new node
            push!(I, heap_t(k, 2, 0)) # put (k, 2) on heap
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, Qe, k, Qe, 2, N)
            if check || monomial_cmp(Exps, vw, Fe, 1, N, par, drmask) >= 0
               if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
                  viewc += 1
              end
            end
         end
      end
      qc = zero!(qc) # clear qc
   end
   resize!(Qc, k) # don't waste so much memory with result
   Qe = resize_exps!(Qe, k)
   return true, parent(a)(Qc, Qe) # return result
end

function sqrt_heap(a::MPoly{T}; check::Bool=true) where {T <: RingElement}
   if characteristic(base_ring(a)) == 2
      return sqrt_classical_char2(a; check=check)
   end
   v, d = max_fields(a)
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         break
      end
      max_e = 2^(exp_bits - 1)
   end
   word_bits = sizeof(Int)*8
   k = div(word_bits, exp_bits)
   N = parent(a).N
   if k != 1
      M = div(N + k - 1, k)
      e1 = zeros(UInt, M, length(a))
      pack_monomials(e1, a.exps, k, exp_bits, length(a))
      par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
      a1 = par(a.coeffs, e1)
      a1.length = a.length
      flag, q = sqrt_heap(a1, exp_bits; check=check)
      eq = zeros(UInt, N, length(q))
      unpack_monomials(eq, q.exps, k, exp_bits, length(q))
   else
      flag, q = sqrt_heap(a, exp_bits; check=check)
      eq = q.exps
   end
   return flag, parent(a)(q.coeffs, eq)
end

function Base.sqrt(a::MPoly{T}; check::Bool=true) where {T <: RingElement}
   flag, q = sqrt_heap(a; check=check)
   check && !flag && error("Not a square in square root")
   return q
end

function is_square(a::MPoly{T}) where {T <: RingElement}
   flag, q = sqrt_heap(a; check=true)
   return flag
end

function is_square_with_sqrt(a::MPoly{T}) where {T <: RingElement}
   return flag, q = sqrt_heap(a; check=true)
end

###############################################################################
#
#   Ad hoc arithmetic functions
#
###############################################################################

function *(a::MPoly, n::Union{Integer, Rational, AbstractFloat})
   N = size(a.exps, 1)
   r = zero(a)
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = a.coeffs[i]*n
      if !iszero(c)
         r.coeffs[j] = c
         monomial_set!(r.exps, j, a.exps, i, N)
         j += 1
      end
   end
   r.length = j - 1
   resize!(r.coeffs, r.length)
   return r
end

function *(a::MPoly{T}, n::T) where {T <: RingElem}
   N = size(a.exps, 1)
   r = zero(a)
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = a.coeffs[i]*n
      if !iszero(c)
         r.coeffs[j] = c
         monomial_set!(r.exps, j, a.exps, i, N)
         j += 1
      end
   end
   r.length = j - 1
   resize!(r.coeffs, r.length)
   return r
end

*(n::Union{Integer, Rational, AbstractFloat}, a::MPoly) = a*n

*(n::T, a::MPoly{T}) where {T <: RingElem} = a*n

function divexact(a::MPoly, n::Union{Integer, Rational, AbstractFloat}; check::Bool=true)
   N = size(a.exps, 1)
   r = zero(a)
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
     c = divexact(a.coeffs[i], n; check=check)
      if !iszero(c)
         r.coeffs[j] = c
         monomial_set!(r.exps, j, a.exps, i, N)
         j += 1
      end
   end
   r.length = j - 1
   resize!(r.coeffs, r.length)
   return r
end

function divexact(a::MPoly{T}, n::T; check::Bool=true) where {T <: RingElem}
   N = size(a.exps, 1)
   r = zero(a)
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = divexact(a.coeffs[i], n; check=check)
      if !iszero(c)
         r.coeffs[j] = c
         monomial_set!(r.exps, j, a.exps, i, N)
         j += 1
      end
   end
   r.length = j - 1
   resize!(r.coeffs, r.length)
   return r
end

###############################################################################
#
#   Comparison functions
#
###############################################################################

function ==(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   fl = check_parent(a, b, false)
   !fl && return false
   if a.length != b.length
      return false
   end
   N = size(a.exps, 1)
   for i = 1:a.length
      for j = 1:N
         if a.exps[j, i] != b.exps[j, i]
            return false
         end
      end
      if a.coeffs[i] != b.coeffs[i]
         return false
      end
   end
   return true
end

@doc raw"""
    isless(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}

Return `true` if the monomial $a$ is less than the monomial $b$ with respect
to the monomial ordering of the parent ring.
"""
function Base.isless(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   (!is_monomial(a) || !is_monomial(b)) && error("Not monomials in comparison")
   N = size(a.exps, 1)
   return monomial_isless(a.exps, 1, b.exps, 1, N, parent(a), UInt(0))
end

###############################################################################
#
#   Ad hoc comparison functions
#
###############################################################################

function ==(a::MPoly, n::Union{Integer, Rational, AbstractFloat})
   N = size(a.exps, 1)
   if n == 0
      return a.length == 0
   elseif a.length == 0
       return iszero(base_ring(a)(n))
   elseif a.length == 1
      return a.coeffs[1] == n && monomial_iszero(a.exps, 1, N)
   end
   return false
end

==(n::Union{Integer, Rational, AbstractFloat}, a::MPoly) = a == n

function ==(a::MPoly{T}, n::T) where {T <: RingElem}
   N = size(a.exps, 1)
   if n == 0
      return a.length == 0
   elseif a.length == 0
       return iszero(base_ring(a)(n))
   elseif a.length == 1
      return a.coeffs[1] == n && monomial_iszero(a.exps, 1, N)
   end
   return false
end

==(n::T, a::MPoly{T}) where {T <: RingElem} = a == n

###############################################################################
#
#   Powering
#
###############################################################################

function from_exp(R::Integers, A::Matrix{UInt}, j::Int, N::Int)
   z = R(reinterpret(Int, A[1, j]))
   for k = 2:N
      z <<= sizeof(Int)*8
      z += reinterpret(Int, A[k, j])
   end
   return z
end

function from_exp(R::Ring, A::Matrix{UInt}, j::Int, N::Int)
   z = R(reinterpret(Int, A[1, j]))
   for k = 2:N
      z *= 2^(sizeof(Int)*4)
      z *= 2^(sizeof(Int)*4)
      z += reinterpret(Int, A[k, j])
   end
   return z
end

# Implement fps algorithm from "Sparse polynomial powering with heaps" by
# Monagan and Pearce, except that we modify the algorithm to return terms
# in ascending order and we fix some issues in the original algorithm
# http://www.cecm.sfu.ca/CAG/papers/SparsePowering.pdf

function pow_fps(f::MPoly{T}, k::Int, bits::Int) where {T <: RingElement}
   par = parent(f)
   R = base_ring(par)
   m = length(f)
   N = parent(f).N
   drmask = monomial_drmask(par, bits)
   H = Vector{heap_s}(undef, 0) # heap
   I = Vector{heap_t}(undef, 0) # auxiliary data for heap nodes
   # set up output poly coeffs and exponents (corresponds to h in paper)
   r_alloc = k*(m - 1) + 1
   Rc = Vector{T}(undef, r_alloc)
   Re = zeros(UInt, N, r_alloc)
   rnext = 1
   # set up g coeffs and exponents (corresponds to g in paper)
   g_alloc = k*(m - 1) + 1
   gc = Vector{T}(undef, g_alloc)
   ge = zeros(UInt, N, g_alloc)
   gnext = 1
   # set up heap
   gc[1] = f.coeffs[1]^(k-1)
   monomial_mul!(ge, 1, f.exps, 1, k - 1, N)
   Rc[1] = f.coeffs[1]*gc[1]
   monomial_mul!(Re, 1, f.exps, 1, k, N)
   Exps = zeros(UInt, N, m + 1)
   Viewn = [i for i in 1:m + 1]
   viewc = m + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_add!(Exps, vw, f.exps, 2, ge, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, heap_t(2, 1, 0))
   Q = zeros(Int, 0) # corresponds to Q in paper
   topbit = -1 << (sizeof(Int)*8 - 1)
   mask = ~topbit
   largest = fill(topbit, m) # largest j s.t. (i, j) has been in heap
   largest[2] = 1
   # precompute some values
   fik = Vector{T}(undef, m)
   for i = 1:m
      fik[i] = from_exp(R, f.exps, i, N)*(k - 1)
   end
   kp1f1 = k*from_exp(R, f.exps, 1, N)
   gi = Vector{T}(undef, 1)
   gi[1] = -from_exp(R, ge, 1, N)
   final_exp = zeros(UInt, N, 1)
   exp_copy = zeros(UInt, N, 1)
   monomial_set!(final_exp, 1, f.exps, m, N)
   # temporary space
   t1 = R()
   C = R() # corresponds to C in paper
   SS = R() # corresponds to S in paper
   temp = R() # temporary space for addmul
   temp2 = R() # temporary space for add
   # begin algorithm
   @inbounds while !isempty(H)
      exp = H[1].exp
      monomial_set!(exp_copy, 1, Exps, exp, N)
      gnext += 1
      rnext += 1
      if gnext > g_alloc
         g_alloc *= 2
         resize!(gc, g_alloc)
         ge = resize_exps!(ge, g_alloc)
      end
      if rnext > r_alloc
         r_alloc *= 2
         resize!(Rc, r_alloc)
         Re = resize_exps!(Re, r_alloc)
      end
      first = true
      C = zero!(C)
      SS = zero!(SS)
      while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         largest[v.i] |= topbit
         t1 = mul!(t1, f.coeffs[v.i], gc[v.j])
         SS = add!(SS, t1)
         if !monomial_isless(Exps, exp, final_exp, 1, N, par, drmask)
            temp2 = add!(temp2, fik[v.i], gi[v.j])
            C = addmul_delayed_reduction!(C, temp2, t1, temp)
         end
         if first
            monomial_sub!(ge, gnext, Exps, exp, f.exps, 1, N)
            first = false
         end
         push!(Q, x.n)
         while (xn = v.next) != 0
            v = I[xn]
            largest[v.i] |= topbit
            t1 = mul!(t1, f.coeffs[v.i], gc[v.j])
            SS = add!(SS, t1)
            if !monomial_isless(Exps, exp, final_exp, 1, N, par, drmask)
               temp2 = add!(temp2, fik[v.i], gi[v.j])
               C = addmul_delayed_reduction!(C, temp2, t1, temp)
            end
            push!(Q, xn)
         end
      end
      C = reduce!(C)
      reuse = 0
      while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.i < m && largest[v.i + 1] == ((v.j - 1) | topbit)
            I[xn] = heap_t(v.i + 1, v.j, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, f.exps, v.i + 1, ge, v.j, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert v into heap
               viewc -= 1
            end
            largest[v.i + 1] = v.j
         else
            reuse = xn
         end
         if v.j < gnext - 1 && (largest[v.i] & mask) <  v.j + 1
            if reuse != 0
               I[reuse] = heap_t(v.i, v.j + 1, 0)
               vw = Viewn[viewc]
               monomial_add!(Exps, vw, f.exps, v.i, ge, v.j + 1, N)
               if heapinsert!(H, I, reuse, vw, Exps, N, par, drmask) # either chain or insert v into heap
                  viewc -= 1
               end
               reuse = 0
            else
               push!(I, heap_t(v.i, v.j + 1, 0))
               vw = Viewn[viewc]
               monomial_add!(Exps, vw, f.exps, v.i, ge, v.j + 1, N)
               if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
                  viewc -= 1
               end
            end
            largest[v.i] = v.j + 1
         end
      end
      if !iszero(C)
         temp = divexact(C, from_exp(R, exp_copy, 1, N) - kp1f1)
         SS = add!(SS, temp)
         gc[gnext] = divexact(temp, f.coeffs[1])
         push!(gi, -from_exp(R, ge, gnext, N))
         if (largest[2] & topbit) != 0
            push!(I, heap_t(2, gnext, 0))
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, f.exps, 2, ge, gnext, N)
            if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
               viewc -= 1
            end
            largest[2] = gnext
         end
      end
      if !iszero(SS)
         Rc[rnext] = SS
         monomial_add!(Re, rnext, ge, gnext, f.exps, 1, N)
         SS = R()
      else
         rnext -= 1
      end
      if iszero(C)
         gnext -= 1
      end
   end
   resize!(Rc, rnext)
   Re = resize_exps!(Re, rnext)
   return parent(f)(Rc, Re)
end

function pow_rmul(a::MPoly{T}, b::Int) where {T <: RingElement}
   b < 0 && throw(DomainError(b, "exponent must be >= 0"))
   if iszero(a)
      return zero(a)
   elseif b == 0
      return one(a)
   end
   z = deepcopy(a)
   for i = 2:b
      z = mul!(z, z, a)
   end
   return z
end

function ^(a::MPoly{T}, b::Int) where {T <: RingElement}
   b < 0 && throw(DomainError(b, "exponent must be >= 0"))
   # special case powers of x for constructing polynomials efficiently
   if iszero(a)
      if iszero(b)
         return one(a)
      else
         return zero(a)
      end
   elseif length(a) == 1
      c = coeff(a, 1)^b
      is_zero(c) && return zero(a)
      N = size(a.exps, 1)
      exps = zeros(UInt, N, 1)
      monomial_mul!(exps, 1, a.exps, 1, b, N)
      for i = 1:N
         if ndigits(a.exps[i, 1], base = 2) + ndigits(b, base = 2) >= sizeof(Int)*8
            error("Exponent overflow in powering")
         end
      end
      return parent(a)([c], exps)
   elseif b == 0
      return one(a)
   elseif b == 1
      return deepcopy(a)
   elseif b == 2
      return a*a
   elseif !is_exact_type(T) || !iszero(characteristic(base_ring(a)))
      # pow_fps requires char 0 or exact ring, so use pow_rmul if not or unsure
      return pow_rmul(a, b)
   else
      v, d = max_fields(a)
      d *= b
      if ndigits(d, base = 2) + ndigits(b, base = 2) >= sizeof(UInt)*8
         error("Exponent overflow in pow_fps")
      end
      exp_bits = 8
      max_e = 2^(exp_bits - 1)
      while d >= max_e
         exp_bits *= 2
         if exp_bits == sizeof(Int)*8
            break
         end
         max_e = 2^(exp_bits - 1)
      end
      word_bits = sizeof(Int)*8
      k = div(word_bits, exp_bits)
      N = parent(a).N
      if k != 1
         M = div(N + k - 1, k)
         e1 = zeros(UInt, M, length(a))
         pack_monomials(e1, a.exps, k, exp_bits, length(a))
         par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
         a1 = par(a.coeffs, e1)
         a1.length = a.length
         r1 = pow_fps(a1, b, exp_bits)
         er = zeros(UInt, N, length(r1))
         unpack_monomials(er, r1.exps, k, exp_bits, length(r1))
      else
         r1 = pow_fps(a, b, exp_bits)
         er = r1.exps
      end
      return parent(a)(r1.coeffs, er)
   end
end

###############################################################################
#
#   Inflation/deflation
#
###############################################################################

function deflate(f::MPoly{T}, shift::Vector{Int}, defl::Vector{Int}) where T <: RingElement
   N = nvars(parent(f))
   for i = 1:N
      if defl[i] == 0
         defl[i] = 1
      end
   end

   if parent(f).ord != :lex # sorting is required if ordering is not lex
      exps = collect(exponent_vectors(f))
      for i = 1:length(f)
         for j = 1:N
            exps[i][j] = div(exps[i][j] - shift[j], defl[j])
         end
      end
      coeffs = [coeff(f, i) for i in 1:length(f)]
      return parent(f)(coeffs, exps) # performs sorting
   else
      r = deepcopy(f)
      exps = r.exps
      for i = 1:length(r)
         for j = 1:N
            exps[N - j + 1, i] = div(exps[N - j + 1, i] - shift[j], defl[j])
         end
      end
      return r
   end
end

function inflate(f::MPoly{T}, shift::Vector{Int}, defl::Vector{Int}) where T <: RingElement
   N = nvars(parent(f))
   if parent(f).ord != :lex # sorting is required if ordering is not lex
      exps = collect(exponent_vectors(f))
      for i = 1:length(f)
         for j = 1:N
            exps[i][j] = exps[i][j]*defl[j] + shift[j]
         end
      end
      coeffs = [coeff(f, i) for i in 1:length(f)]
      return parent(f)(coeffs, exps)
   else
      r = deepcopy(f)
      exps = r.exps
      for i = 1:length(r)
         for j = 1:N
            exps[N - j + 1, i] = exps[N - j + 1, i]*defl[j] + shift[j]
         end
      end
      return r
   end
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divides_monagan_pearce(a::MPoly{T}, b::MPoly{T}, bits::Int) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   if m == 0
      return true, par()
   end
   if n == 0
      return false, par()
   end
   drmask = monomial_drmask(par, bits)
   mask1 = UInt(1) << (bits - 1)
   mask = UInt(0)
   for i = 1:div(sizeof(UInt)*8, bits)
      mask = (mask << bits) + mask1
   end
   N = parent(a).N
   H = Vector{heap_s}(undef, 0)
   I = Vector{heap_t}(undef, 0)
   Exps = zeros(UInt, N, n + 1)
   Viewn = [i for i in 1:n + 1]
   viewc = n + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_set!(Exps, vw, a.exps, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, heap_t(0, 1, 0))
   q_alloc = max(m - n, n)
   Qc = Vector{T}(undef, q_alloc)
   Qe = zeros(UInt, N, q_alloc)
   k = 0
   s = n
   c = R()
   qc = R()
   m1 = -one(R)
   mb = -b.coeffs[1]
   Q = zeros(Int, 0)
   reuse = zeros(Int, 0)
   @inbounds while !isempty(H)
      exp = H[1].exp
      k += 1
      if k > q_alloc
         q_alloc *= 2
         resize!(Qc, q_alloc)
         Qe = resize_exps!(Qe, q_alloc)
      end
      first = true
      d1 = false
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if first
            d1 = monomial_divides!(Qe, k, Exps, exp, b.exps, 1, mask, N)
            first = false
         end
         if v.i == 0
            qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
         else
            qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
         end
         if v.i != 0 || v.j < m
            push!(Q, x.n)
         else
            push!(reuse, x.n)
         end
         while (xn = v.next) != 0
            v = I[xn]
            if v.i == 0
               qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
            else
               qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
            end
            if v.i != 0 || v.j < m
               push!(Q, xn)
            else
               push!(reuse, xn)
            end
         end
      end
      qc = reduce!(qc)
      @inbounds while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.i == 0
            I[xn] = heap_t(0, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_set!(Exps, vw, a.exps, v.j + 1, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j < k - 1
            I[xn] = heap_t(v.i, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, b.exps, v.i, Qe, v.j + 1, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j == k - 1
            s += 1
            push!(reuse, xn)
         end
      end
      if qc == 0
         k -= 1
      else
         d2, Qc[k] = divides(qc, mb)
         if !d1 || !d2
             return false, par()
         end
         for i = 2:s
            if !isempty(reuse)
               xn = pop!(reuse)
               I[xn] = heap_t(i, k, 0)
               vw = Viewn[viewc]
               monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc -= 1
               end
            else
               push!(I, heap_t(i, k, 0))
               vw = Viewn[viewc]
               monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
               if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
                  viewc -= 1
               end
            end
         end
         s = 1
      end
      qc = zero!(qc)
   end
   resize!(Qc, k)
   Qe = resize_exps!(Qe, k)
   return true, parent(a)(Qc, Qe)
end

function divides(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   v1, d1 = max_fields(a)
   v2, d2 = max_fields(b)
   d = max(d1, d2)
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         break
      end
      max_e = 2^(exp_bits - 1)
   end
   word_bits = sizeof(Int)*8
   k = div(word_bits, exp_bits)
   N = parent(a).N
   if k != 1
      M = div(N + k - 1, k)
      e1 = zeros(UInt, M, length(a))
      e2 = zeros(UInt, M, length(b))
      pack_monomials(e1, a.exps, k, exp_bits, length(a))
      pack_monomials(e2, b.exps, k, exp_bits, length(b))
      par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
      a1 = par(a.coeffs, e1)
      b1 = par(b.coeffs, e2)
      a1.length = a.length
      b1.length = b.length
      flag, q = divides_monagan_pearce(a1, b1, exp_bits)
      eq = zeros(UInt, N, length(q))
      unpack_monomials(eq, q.exps, k, exp_bits, length(q))
   else
      flag, q = divides_monagan_pearce(a, b, exp_bits)
      eq = q.exps
   end
   return flag, parent(a)(q.coeffs, eq)
end

function divexact(a::MPoly{T}, b::MPoly{T}; check::Bool=true) where {T <: RingElement}
   d, q = divides(a, b)
   check && d == false && error("Not an exact division in divexact")
   return q
end

###############################################################################
#
#   Euclidean division
#
###############################################################################

function div_monagan_pearce(a::MPoly{T}, b::MPoly{T}, bits::Int) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   n == 0 && error("Division by zero in div_monagan_pearce")
   if m == 0
      return true, par()
   end
   flag = true
   drmask = monomial_drmask(par, bits)
   mask1 = UInt(1) << (bits - 1)
   mask = UInt(0)
   for i = 1:div(sizeof(UInt)*8, bits)
      mask = (mask << bits) + mask1
   end
   N = size(a.exps, 1)
   H = Vector{heap_s}(undef, 0)
   I = Vector{heap_t}(undef, 0)
   Exps = zeros(UInt, N, n + 1)
   Viewn = [i for i in 1:n + 1]
   viewc = n + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_set!(Exps, vw, a.exps, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, heap_t(0, 1, 0))
   q_alloc = max(m - n, n)
   Qc = Vector{T}(undef, q_alloc)
   Qe = zeros(UInt, N, q_alloc)
   k = 0
   s = n
   c = R()
   qc = R()
   m1 = -one(R)
   mb = -b.coeffs[1]
   Q = zeros(Int, 0)
   reuse = zeros(Int, 0)
   exp_copy = zeros(UInt, N, 1)
   temp = zeros(UInt, N, 1)
   temp2 = zeros(UInt, N, 1)
   texp = zeros(UInt, N, 1)
   monomial_set!(temp2, 1, b.exps, 1, N)
   while !isempty(H)
      exp = H[1].exp
      monomial_set!(exp_copy, 1, Exps, exp, N)
      if monomial_overflows(exp_copy, 1, mask, N)
         k = 0
         flag = false
         break
      end
      divides_exp = monomial_divides!(texp, 1, exp_copy, 1, temp2, 1, mask, N)
      k += 1
      if k > q_alloc
         q_alloc *= 2
         resize!(Qc, q_alloc)
         Qe = resize_exps!(Qe, q_alloc)
      end
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if divides_exp
            if v.i == 0
               qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
            else
               qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
            end
         end
         if v.i != 0 || v.j < m
            push!(Q, x.n)
         else
            push!(reuse, x.n)
         end
         while (xn = v.next) != 0
            v = I[xn]
            if divides_exp
               if v.i == 0
                  qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
               else
                  qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
               end
            end
            if v.i != 0 || v.j < m
               push!(Q, xn)
            else
               push!(reuse, xn)
            end
         end
      end
      qc = reduce!(qc)
      @inbounds while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.i == 0
            I[xn] = heap_t(0, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_set!(Exps, vw, a.exps, v.j + 1, N)
            if !monomial_isless(Exps, vw, temp2, 1, N, par, drmask)
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc -= 1
               end
            end
         elseif v.j < k - 1
            I[xn] = heap_t(v.i, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, b.exps, v.i, Qe, v.j + 1, N)
            if !monomial_isless(Exps, vw, temp2, 1, N, par, drmask)
               if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                  viewc -= 1
               end
            end
         elseif v.j == k - 1
            s += 1
            push!(reuse, xn)
         end
      end
      if qc == 0
         k -= 1
      else
         d1 = monomial_divides!(texp, 1, exp_copy, 1, temp2, 1, mask, N)
         if !d1
            k -= 1
         else
            tq, tr = divrem(qc, mb)
            if !iszero(tq)
               Qc[k] = tq
               monomial_set!(Qe, k, texp, 1, N)
               for i = 2:s
                  if !isempty(reuse)
                     xn = pop!(reuse)
                     I[xn] = heap_t(i, k, 0)
                     vw = Viewn[viewc]
                     monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
                     if !monomial_isless(Exps, vw, temp2, 1, N, par, drmask)
                        if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                           viewc -= 1
                        end
                     end
                  else
                     push!(I, heap_t(i, k, 0))
                     vw = Viewn[viewc]
                     monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
                     if !monomial_isless(Exps, vw, temp2, 1, N, par, drmask)
                        if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
                           viewc -= 1
                        end
                     end
                  end
               end
               s = 1
            else
               k -= 1
            end
         end
      end
      qc = zero!(qc)
   end
   resize!(Qc, k)
   Qe = resize_exps!(Qe, k)
   return flag, parent(a)(Qc, Qe)
end

function Base.div(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   v1, d1 = max_fields(a)
   v2, d2 = max_fields(b)
   d = max(d1, d2)
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         break
      end
      max_e = 2^(exp_bits - 1)
   end
   N = parent(a).N
   word_bits = sizeof(Int)*8
   q = zero(a)
   eq = zeros(UInt, N, 0)
   flag = false
   while flag == false
      k = div(word_bits, exp_bits)
      if k != 1
         M = div(N + k - 1, k)
         e1 = zeros(UInt, M, length(a))
         e2 = zeros(UInt, M, length(b))
         pack_monomials(e1, a.exps, k, exp_bits, length(a))
         pack_monomials(e2, b.exps, k, exp_bits, length(b))
         par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
         a1 = par(a.coeffs, e1)
         b1 = par(b.coeffs, e2)
         a1.length = a.length
         b1.length = b.length
         flag, q = div_monagan_pearce(a1, b1, exp_bits)
         if flag == false
            exp_bits *= 2
         else
            eq = zeros(UInt, N, length(q))
            unpack_monomials(eq, q.exps, k, exp_bits, length(q))
         end
      else
         flag, q = div_monagan_pearce(a, b, exp_bits)
         flag == false && error("Exponent overflow in div_monagan_pearce")
         eq = q.exps
      end
   end
   return parent(a)(q.coeffs, eq)
end

function divrem_monagan_pearce(a::MPoly{T}, b::MPoly{T}, bits::Int) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   n == 0 && error("Division by zero in divrem_monagan_pearce")
   if m == 0
      return true, par(), par()
   end
   flag = true
   drmask = monomial_drmask(par, bits)
   mask1 = UInt(1) << (bits - 1)
   mask = UInt(0)
   for i = 1:div(sizeof(UInt)*8, bits)
      mask = (mask << bits) + mask1
   end
   N = size(a.exps, 1)
   H = Vector{heap_s}(undef, 0)
   I = Vector{heap_t}(undef, 0)
   Exps = zeros(UInt, N, n + 1)
   Viewn = [i for i in 1:n + 1]
   viewc = n + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_set!(Exps, vw, a.exps, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, heap_t(0, 1, 0))
   q_alloc = max(m - n, n)
   r_alloc = n
   Qc = Vector{T}(undef, q_alloc)
   Qe = zeros(UInt, N, q_alloc)
   Rc = Vector{T}(undef, r_alloc)
   Re = zeros(UInt, N, r_alloc)
   k = 0
   l = 0
   s = n
   c = R()
   qc = R()
   m1 = -one(R)
   mb = -b.coeffs[1]
   Q = zeros(Int, 0)
   reuse = zeros(Int , 0)
   exp_copy = zeros(UInt, N, 1)
   temp = zeros(UInt, N, 1)
   temp2 = zeros(UInt, N, 1)
   texp = zeros(UInt, N, 1)
   monomial_set!(temp2, 1, b.exps, 1, N)
   while !isempty(H)
      exp = H[1].exp
      monomial_set!(exp_copy, 1, Exps, exp, N)
      if monomial_overflows(exp_copy, 1, mask, N)
         k = 0
         l = 0
         flag = false
         break
      end
      k += 1
      if k > q_alloc
         q_alloc *= 2
         resize!(Qc, q_alloc)
         Qe = resize_exps!(Qe, q_alloc)
      end
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if v.i == 0
            qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
         else
            qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
         end
         if v.i != 0 || v.j < m
            push!(Q, x.n)
         else
            push!(reuse, x.n)
         end
         while (xn = v.next) != 0
            v = I[xn]
            if v.i == 0
               qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
            else
               qc = addmul_delayed_reduction!(qc, b.coeffs[v.i], Qc[v.j], c)
            end
            if v.i != 0 || v.j < m
               push!(Q, xn)
            else
               push!(reuse, xn)
            end
         end
      end
      qc = reduce!(qc)
      @inbounds while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.i == 0
            I[xn] = heap_t(0, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_set!(Exps, vw, a.exps, v.j + 1, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j < k - 1
            I[xn] = heap_t(v.i, v.j + 1, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, b.exps, v.i, Qe, v.j + 1, N)
            if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j == k - 1
            s += 1
            push!(reuse, xn)
         end
      end
      if qc == 0
         k -= 1
      else
         d1 = monomial_divides!(texp, 1, exp_copy, 1, temp2, 1, mask, N)
         if !d1
            l += 1
            if l >= r_alloc
               r_alloc *= 2
               resize!(Rc, r_alloc)
               Re = resize_exps!(Re, r_alloc)
            end
            Rc[l] = -qc
            monomial_set!(Re, l, exp_copy, 1, N)
            k -= 1
         else
            tq, tr = divrem(qc, mb)
            if !iszero(tr)
               l += 1
               if l >= r_alloc
                  r_alloc *= 2
                  resize!(Rc, r_alloc)
                  Re = resize_exps!(Re, r_alloc)
               end
               Rc[l] = -tr
               monomial_set!(Re, l, exp_copy, 1, N)
            end
            if !iszero(tq)
               Qc[k] = tq
               monomial_set!(Qe, k, texp, 1, N)
               for i = 2:s
                  if !isempty(reuse)
                     xn = pop!(reuse)
                     I[xn] = heap_t(i, k, 0)
                     vw = Viewn[viewc]
                     monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
                     if heapinsert!(H, I, xn, vw, Exps, N, par, drmask) # either chain or insert into heap
                        viewc -= 1
                     end
                  else
                     push!(I, heap_t(i, k, 0))
                     vw = Viewn[viewc]
                     monomial_add!(Exps, vw, b.exps, i, Qe, k, N)
                     if heapinsert!(H, I, length(I), vw, Exps, N, par, drmask)
                        viewc -= 1
                     end
                  end
               end
               s = 1
            else
               k -= 1
            end
         end
      end
      qc = zero!(qc)
   end
   resize!(Qc, k)
   Qe = resize_exps!(Qe, k)
   resize!(Rc, l)
   Re = resize_exps!(Re, l)
   return flag, parent(a)(Qc, Qe), parent(a)(Rc, Re)
end

function Base.divrem(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   v1, d1 = max_fields(a)
   v2, d2 = max_fields(b)
   d = max(d1, d2)
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         break
      end
      max_e = 2^(exp_bits - 1)
   end
   N = parent(a).N
   word_bits = sizeof(Int)*8
   q = zero(a)
   r = zero(a)
   eq = zeros(UInt, N, 0)
   er = zeros(UInt, N, 0)
   flag = false
   while flag == false
      k = div(word_bits, exp_bits)
      if k != 1
         M = div(N + k - 1, k)
         e1 = zeros(UInt, M, length(a))
         e2 = zeros(UInt, M, length(b))
         pack_monomials(e1, a.exps, k, exp_bits, length(a))
         pack_monomials(e2, b.exps, k, exp_bits, length(b))
         par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
         a1 = par(a.coeffs, e1)
         b1 = par(b.coeffs, e2)
         a1.length = a.length
         b1.length = b.length
         flag, q, r = divrem_monagan_pearce(a1, b1, exp_bits)
         if flag == false
            exp_bits *= 2
         else
            eq = zeros(UInt, N, length(q))
            er = zeros(UInt, N, length(r))
            unpack_monomials(eq, q.exps, k, exp_bits, length(q))
            unpack_monomials(er, r.exps, k, exp_bits, length(r))
         end
      else
         flag, q, r = divrem_monagan_pearce(a, b, exp_bits)
         flag == false && error("Exponent overflow in divrem_monagan_pearce")
         eq = q.exps
         er = r.exps
      end
   end
   return parent(a)(q.coeffs, eq), parent(a)(r.coeffs, er)
end

function divrem_monagan_pearce(a::MPoly{T}, b::Vector{MPoly{T}}, bits::Int) where {T <: RingElement}
   par = parent(a)
   R = base_ring(par)
   len = length(b)
   m = length(a)
   n = [length(b[i]) for i in 1:len]
   for i = 1:len
      n[i] == 0 && error("Division by zero in divrem_monagan_pearce")
   end
   if m == 0
      return true, [par() for i in 1:len], par()
   end
   flag = true
   drmask = monomial_drmask(par, bits)
   mask1 = UInt(1) << (bits - 1)
   mask = UInt(0)
   for i = 1:div(sizeof(UInt)*8, bits)
      mask = (mask << bits) + mask1
   end
   N = size(a.exps, 1)
   H = Vector{heap_s}(undef, 0)
   I = Vector{nheap_t}(undef, 0)
   heapn = 0
   for i = 1:len
      heapn += n[i]
   end
   Exps = zeros(UInt, N, heapn + 1)
   Viewn = [i for i in 1:heapn + 1]
   viewc = heapn + 1
   # set up heap
   vw = Viewn[viewc]
   viewc -= 1
   monomial_set!(Exps, vw, a.exps, 1, N)
   push!(H, heap_s(vw, 1))
   push!(I, nheap_t(0, 1, 0, 0))
   q_alloc = [max(m - n[i], n[i]) for i in 1:len]
   r_alloc = n[1]
   Qc = [Vector{T}(undef, q_alloc[i]) for i in 1:len]
   Qe = [zeros(UInt, N, q_alloc[i]) for i in 1:len]
   Rc = Vector{T}(undef, r_alloc)
   Re = zeros(UInt, N, r_alloc)
   k = [0 for i in 1:len]
   l = 0
   s = [n[i] for i in 1:len]
   c = R()
   qc = R()
   m1 = -one(R)
   mb = [-b[i].coeffs[1] for i in 1:len]
   Q = zeros(Int, 0)
   reuse = zeros(Int, 0)
   exp_copy = zeros(UInt, N, 1)
   temp = zeros(UInt, N, 1)
   texp = zeros(UInt, N, 1)
   while !isempty(H)
      exp = H[1].exp
      monomial_set!(exp_copy, 1, Exps, exp, N)
      if monomial_overflows(exp_copy, 1, mask, N)
         for i = 1:len
            k[i] = 0
         end
         l = 0
         flag = false
         break
      end
      @inbounds while !isempty(H) && monomial_isequal(Exps, H[1].exp, exp, N)
         x = H[1]
         viewc += 1
         Viewn[viewc] = heappop!(H, Exps, N, par, drmask)
         v = I[x.n]
         if v.i == 0
            qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
         else
            qc = addmul_delayed_reduction!(qc, b[v.p].coeffs[v.i], Qc[v.p][v.j], c)
         end
         if v.i != 0 || v.j < m
            push!(Q, x.n)
         else
            push!(reuse, x.n)
         end
         while (xn = v.next) != 0
            v = I[xn]
            if v.i == 0
               qc = addmul_delayed_reduction!(qc, a.coeffs[v.j], m1, c)
            else
               qc = addmul_delayed_reduction!(qc, b[v.p].coeffs[v.i], Qc[v.p][v.j], c)
            end
            if v.i != 0 || v.j < m
               push!(Q, xn)
            else
               push!(reuse, xn)
            end
         end
      end
      qc = reduce!(qc)
      @inbounds while !isempty(Q)
         xn = pop!(Q)
         v = I[xn]
         if v.i == 0
            I[xn] = nheap_t(0, v.j + 1, 0, 0)
            vw = Viewn[viewc]
            monomial_set!(Exps, vw, a.exps, v.j + 1, N)
            if nheapinsert!(H, I, xn, vw, Exps, N, 0, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j < k[v.p]
            I[xn] = nheap_t(v.i, v.j + 1, v.p, 0)
            vw = Viewn[viewc]
            monomial_add!(Exps, vw, b[v.p].exps, v.i, Qe[v.p], v.j + 1, N)
            if nheapinsert!(H, I, xn, vw, Exps, N, v.p, par, drmask) # either chain or insert into heap
               viewc -= 1
            end
         elseif v.j == k[v.p]
            s[v.p] += 1
            push!(reuse, xn)
         end
      end
      if !iszero(qc)
         div_flag = false
         for w = 1:len
            d1 = monomial_divides!(texp, 1, exp_copy, 1, b[w].exps, 1, mask, N)
            if d1
               tq, qc = divrem(qc, mb[w])
               div_flag = qc == 0
               if !iszero(tq)
                  k[w] += 1
                  if k[w] > q_alloc[w]
                     q_alloc[w] *= 2
                     resize!(Qc[w], q_alloc[w])
                     Qe[w] = resize_exps!(Qe[w], q_alloc[w])
                  end
                  Qc[w][k[w]] = tq
                  monomial_set!(Qe[w], k[w], texp, 1, N)
                  for i = 2:s[w]
                     if !isempty(reuse)
                        xn = pop!(reuse)
                        I[xn] = nheap_t(i, k[w], w, 0)
                        vw = Viewn[viewc]
                        monomial_add!(Exps, vw, b[w].exps, i, Qe[w], k[w], N)
                        if nheapinsert!(H, I, xn, vw, Exps, N, w, par, drmask) # either chain or insert into heap
                           viewc -= 1
                        end
                     else
                        push!(I, nheap_t(i, k[w], w, 0))
                        vw = Viewn[viewc]
                        monomial_add!(Exps, vw, b[w].exps, i, Qe[w], k[w], N)
                        if nheapinsert!(H, I, length(I), vw, Exps, N, w, par, drmask)
                           viewc -= 1
                        end
                     end
                  end
                  s[w] = 1
               end
            end
         end
         if !div_flag
            l += 1
            if l >= r_alloc
               r_alloc *= 2
               resize!(Rc, r_alloc)
               Re = resize_exps!(Re, r_alloc)
            end
            Rc[l] = -qc
            monomial_set!(Re, l, exp_copy, 1, N)
         end
      end
      qc = zero!(qc)
   end
   for i = 1:len
      resize!(Qc[i], k[i])
      Qe[i] = resize_exps!(Qe[i], k[i])
   end
   resize!(Rc, l)
   Re = resize_exps!(Re, l)
   return flag, [parent(a)(Qc[i], Qe[i]) for i in 1:len], parent(a)(Rc, Re)
end

@doc raw"""
    divrem(a::MPoly{T}, b::Vector{MPoly{T}}) where {T <: RingElement}

Return a tuple `(q, r)` consisting of an array of polynomials `q`, one for
each polynomial in `b`, and a polynomial `r` such that `a = sum_i b[i]*q[i] + r`.
"""
function Base.divrem(a::MPoly{T}, b::Vector{MPoly{T}}) where {T <: RingElement}
   if isempty(b)
      return typeof(a)[], a
   end
   v1, d = max_fields(a)
   len = length(b)
   N = parent(a).N
   for i = 1:len
      v2, d2 = max_fields(b[i])
      for j = 1:N
         v1[j] = max(v1[j], v2[j])
      end
      d = max(d, d2)
   end
   exp_bits = 8
   max_e = 2^(exp_bits - 1)
   while d >= max_e
      exp_bits *= 2
      if exp_bits == sizeof(Int)*8
         break
      end
      max_e = 2^(exp_bits - 1)
   end
   word_bits = sizeof(Int)*8
   q = [zero(a) for i in 1:len]
   eq = [zeros(UInt, N, 0) for i in 1:len]
   r = zero(a)
   er = zeros(UInt, N, 0)
   flag = false
   while flag == false
      k = div(word_bits, exp_bits)
      if k != 1
         M = div(N + k - 1, k)
         e1 = zeros(UInt, M, length(a))
         e2 = [zeros(UInt, M, length(b[i])) for i in 1:len]
         pack_monomials(e1, a.exps, k, exp_bits, length(a))
         for i = 1:len
            pack_monomials(e2[i], b[i].exps, k, exp_bits, length(b[i]))
         end
         par = MPolyRing{T}(base_ring(a), parent(a).S, parent(a).ord, M, false)
         a1 = par(a.coeffs, e1)
         a1.length = a.length
         b1 = [par(b[i].coeffs, e2[i]) for i in 1:len]
         for i = 1:len
            b1[i].length = b[i].length
         end
         flag, q, r = divrem_monagan_pearce(a1, b1, exp_bits)
         if flag == false
            exp_bits *= 2
         else
            eq = [zeros(UInt, N, length(q[i])) for i in 1:len]
            for i = 1:len
               unpack_monomials(eq[i], q[i].exps, k, exp_bits, length(q[i]))
            end
            er = zeros(UInt, N, length(r))
            unpack_monomials(er, r.exps, k, exp_bits, length(r))
         end
      else
         flag, q, r = divrem_monagan_pearce(a, b, exp_bits)
         flag == false && error("Exponent overflow in divrem_monagan_pearce")
         eq = [q[i].exps for i in 1:len]
         er = r.exps
      end
   end
   return [parent(a)(q[i].coeffs, eq[i]) for i in 1:len], parent(a)(r.coeffs, er)
end

###############################################################################
#
#   Evaluation
#
###############################################################################

@doc raw"""
    evaluate(a::MPoly{T}, A::Vector{T}) where {T <: RingElement}

Evaluate the polynomial expression by substituting in the array of values for
each of the variables.
"""
function evaluate(a::MPoly{T}, A::Vector{T}) where T <: RingElement
   if iszero(a)
      return base_ring(a)()
   end
   N = size(a.exps, 1)
   ord = parent(a).ord
   if ord == :lex
      start_var = N
   else
      start_var = N - 1
   end
   R = SparsePolyRing{typeof(a)}(parent(a), :$, false)
   if ord == :degrevlex
      while a.length > 1 || (a.length == 1 && !monomial_iszero(a.exps, a.length, N))
         k = main_variable(a, start_var)
         p = main_variable_extract(R, a, k)
         a = evaluate(p, A[k])
      end
  else
      while a.length > 1 || (a.length == 1 && !monomial_iszero(a.exps, a.length, N))
         k = main_variable(a, start_var)
         p = main_variable_extract(R, a, k)
         a = evaluate(p, A[start_var - k + 1])
      end
   end
   if a.length == 0
      return base_ring(a)()
   else
      return a.coeffs[1]
   end
end

function (a::MPoly{T})() where T <: RingElement
   nvars(parent(a)) != 0 && error("Number of variables does not match number of values")
   return evaluate(a, T[])
end

function (a::MPoly{T})(vals::T...) where T <: RingElement
   length(vals) != nvars(parent(a)) && error("Number of variables does not match number of values")
   return evaluate(a, [vals...])
end

function (a::MPoly{T})(val::U, vals::U...) where {T <: RingElement, U <: Union{Integer, Rational, AbstractFloat}}
   length(vals) + 1 != nvars(parent(a)) && error("Number of variables does not match number of values")
   return evaluate(a, [val, vals...])
end

@doc raw"""
    (a::MPoly{T})(vals::Union{NCRingElem, RingElement}...) where T <: RingElement

Evaluate the polynomial at the supplied values, which may be any ring elements,
commutative or non-commutative. Evaluation always proceeds in the order of the
variables as supplied when creating the polynomial ring to which $a$ belongs.
The evaluation will succeed if a product of a coefficient of the polynomial by
all of the supplied values in order is defined. Note that this evaluation is
more general than those provided by the evaluate function. The values do not
need to be in the same ring, just in compatible rings.
"""
function (a::MPoly{T})(vals::Union{NCRingElem, RingElement}...) where T <: RingElement
   length(vals) != nvars(parent(a)) && error("Number of variables does not match number of values")
   R = base_ring(a)
   # The best we can do here is to cache previously used powers of the values
   # being substituted, as we cannot assume anything about the relative
   # performance of powering vs multiplication. The function should not try
   # to optimise computing new powers in any way.
   # Note that this function accepts values in a non-commutative ring, so operations
   # must be done in a certain order.
   powers = [Dict{Int, Any}() for i in 1:length(vals)]
   # First work out types of products
   r = R()
   for j = 1:length(vals)
      W = typeof(vals[j])
      if ((W <: Integer && W !== BigInt) ||
          (W <: Rational && W !== Rational{BigInt}))
         r = r*zero(W)
      else
         r = r*zero(parent(vals[j]))
      end
   end
   cvzip = zip(coefficients(a), exponent_vectors(a))
   for (c, v) in cvzip
      t = deepcopy(c)
      for j = 1:length(vals)
         exp = v[j]
         pe = get!(powers[j], exp) do
            return vals[j]^exp
         end
         t = mul!(t, pe)
      end
      r = add!(r, t)
   end
   return r
end

###############################################################################
#
#   GCD
#
###############################################################################

@doc raw"""
    gcd(a::MPoly{T}, a::MPoly{T}) where {T <: RingElement}

Return the greatest common divisor of a and b in parent(a).
"""
function gcd(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   check_parent(a, b)
   if iszero(a)
      if b.length == 0
         return deepcopy(a)
      end
      return divexact(b, canonical_unit(coeff(b, 1)))
   elseif length(b) == 0
      return divexact(a, canonical_unit(coeff(a, 1)))
   end
   if isone(a)
      return deepcopy(a)
   end
   if isone(b)
      return deepcopy(b)
   end
   # compute deflation and deflate
   shifta, defla = deflation(a)
   shiftb, deflb = deflation(b)
   shiftr = min.(shifta, shiftb)
   deflr = broadcast(gcd, defla, deflb)
   a = deflate(a, shifta, deflr)
   b = deflate(b, shiftb, deflr)
   # get degrees in each variable
   v1, d1 = max_fields(a)
   v2, d2 = max_fields(b)
   # check if both polys are constant
   if d1 == 0 && d2 == 0
      r = gcd(coeff(a, 1), coeff(b, 1))
      r = parent(a)(divexact(r, canonical_unit(r)))
      return inflate(r, shiftr, deflr)
   end
   ord = parent(a).ord
   N = parent(a).N
   if ord == :lex
      end_var = N
   else
      end_var = N - 1
   end
   # check for cases where degree is 0 in one of the variables for one poly
   for k = end_var:-1:1
      if v1[k] == 0 && v2[k] != 0
         p2 = main_variable_extract(b, k)
         r = gcd(a, content(p2))
         # perform inflation
         return inflate(r, shiftr, deflr)
      end
      if v2[k] == 0 && v1[k] != 0
         p1 = main_variable_extract(a, k)
         r = gcd(content(p1), b)
         # perform inflation
         return inflate(r, shiftr, deflr)
      end
   end
   # count number of terms in lead coefficient, for each variable
   lead1 = zeros(Int, N)
   lead2 = zeros(Int, N)
   for i = end_var:-1:1
      if v1[i] != 0
         for j = 1:length(a)
            if a.exps[i, j] == v1[i]
               lead1[i] += 1
            end
         end
      end
      if v2[i] != 0
         for j = 1:length(b)
            if b.exps[i, j] == v2[i]
               lead2[i] += 1
            end
         end
      end
   end
   # heuristic to decide optimal variable k to choose as main variable
   # it basically looks for low degree in the main variable, but
   # heavily weights monomial leading term
   k = 0
   m = Inf
   for i = end_var:-1:1
      if v1[i] != 0
         if v1[i] >= v2[i]
            c = max(Base.log(lead2[i])*v1[i]*v2[i], Base.log(2)*v2[i])
            if c < m
               m = c
               k = i
            end
         else
            c = max(Base.log(lead1[i])*v2[i]*v1[i], Base.log(2)*v1[i])
            if c < m
               m = c
               k = i
            end
         end
      end
   end
   # write polys in terms of main variable k, do gcd, then convert back,
   # then inflate
   p1 = main_variable_extract(a, k)
   p2 = main_variable_extract(b, k)
   g = gcd(p1, p2)
   r = main_variable_insert(g, k)
   r = divexact(r, canonical_unit(coeff(r, 1))) # normalise
   # perform inflation
   return inflate(r, shiftr, deflr)
end

@doc raw"""
    lcm(a::AbstractAlgebra.MPolyRingElem{T}, a::AbstractAlgebra.MPolyRingElem{T}) where {T <: RingElement}

Return the least common multiple of a and b in parent(a).
"""
function lcm(a::MPolyRingElem{T}, b::MPolyRingElem{T}) where {T <: RingElement}
   check_parent(a, b)
   g = gcd(a, b)
   iszero(g) && return g
   return a*divexact(b, g)
end

function term_gcd(a::MPoly{T}, b::MPoly{T}) where {T <: RingElement}
   if a.length < 1
      return b
   elseif b.length < 1
      return a
   end
   ord = parent(a).ord
   N = parent(a).N
   Ce = zeros(UInt, N, 1)
   Cc = Vector{T}(undef, 1)
   monomial_set!(Ce, 1, a.exps, 1, N)
   monomial_vecmin!(Ce, 1, b.exps, 1, N)
   if ord == :deglex || ord == :degrevlex
      sum = UInt(0)
      for j = 1:N - 1
         sum += Ce[j, 1]
      end
      Ce[N, 1] = sum
   end
   Cc[1] = gcd(a.coeffs[1], b.coeffs[1])
   return parent(a)(Cc, Ce)
end

function term_content(a::MPoly{T}) where {T <: RingElement}
   if a.length <= 1
      return a
   end
   ord = parent(a).ord
   N = parent(a).N
   Ce = zeros(UInt, N, 1)
   Cc = Vector{T}(undef, 1)
   monomial_set!(Ce, 1, a.exps, 1, N)
   for i = 2:a.length
      monomial_vecmin!(Ce, 1, a.exps, i, N)
      if ord == :deglex || ord == :degrevlex
         sum = UInt(0)
         for j = 1:N - 1
            sum += Ce[j, 1]
         end
         Ce[N, 1] = sum
      end
      if monomial_iszero(Ce, 1, N)
         break
      end
   end
   Cc[1] = base_ring(a)()
   for i = 1:a.length
      Cc[1] = gcd(Cc[1], a.coeffs[i])
   end
   return parent(a)(Cc, Ce)
end

###############################################################################
#
#   Conversions
#
###############################################################################

# These functions are internal and mainly used by the gcd code

# Determine the number of the first variable for which there is a nonzero exp
# we start at variable k0
function main_variable(a::MPoly{T}, k0::Int) where {T <: RingElement}
   N = parent(a).N
   for k = k0:-1:1
      for j = 1:a.length
         if a.exps[k, j] != 0
            return k
         end
      end
   end
   return 0
end

# Return an array of all the starting positions of terms in the main variable k
function main_variable_terms(a::MPoly{T}, k::Int) where {T <: RingElement}
   A = zeros(Int, 0)
   current_term = typemax(UInt)
   for i = 1:a.length
      if a.exps[k, i] != current_term
         push!(A, i)
         current_term = a.exps[k, i]
      end
   end
   return A
end

# Return the coefficient as a sparse distributed polynomial, of the term in variable
# k0 starting at position n
function main_variable_coefficient_lex(a::MPoly{T}, k0::Int, n::Int) where {T <: RingElement}
   exp = a.exps[k0, n]
   N = parent(a).N
   Ae = zeros(UInt, N, 0)
   a_alloc = 0
   Ac = Vector{T}(undef, 0)
   l = 0
   for i = n:a.length
      if a.exps[k0, i] != exp
         break
      end
      l += 1
      if l > a_alloc
         a_alloc = a_alloc*2 + 1
         Ae = resize_exps!(Ae, a_alloc)
      end
      for k = 1:N
         if k == k0
            Ae[k, l] = UInt(0)
         else
            Ae[k, l] = a.exps[k, i]
         end
      end
      push!(Ac, a.coeffs[i])
   end
   Ae = resize_exps!(Ae, l)
   return parent(a)(Ac, Ae)
end

function main_variable_coefficient(a::MPoly{T}, k::Int, n::Int, ::Val{:lex}) where {T <: RingElement}
   return main_variable_coefficient_lex(a, k, n)
end

# Return the coefficient as a sparse distributed polynomial, of the term in variable
# k0 starting at position n
function main_variable_coefficient_deglex(a::MPoly{T}, k0::Int, n::Int) where {T <: RingElement}
   exp = a.exps[k0, n]
   N = parent(a).N
   Ae = zeros(UInt, N, 0)
   a_alloc = 0
   Ac = Vector{T}(undef, 0)
   l = 0
   for i = n:a.length
      if a.exps[k0, i] != exp
         break
      end
      l += 1
      if l > a_alloc
         a_alloc = 2*a_alloc + 1
         Ae = resize_exps!(Ae, a_alloc)
      end
      for k = 1:N
         if k == N
            Ae[k, l] = a.exps[N, i] - a.exps[k0, i]
         elseif k == k0
            Ae[k, l] = UInt(0)
         else
            Ae[k, l] = a.exps[k, i]
         end
      end
      push!(Ac, a.coeffs[i])
   end
   Ae = resize_exps!(Ae, l)
   return parent(a)(Ac, Ae)
end

function main_variable_coefficient(a::MPoly{T}, k::Int, n::Int, ::Val{:deglex}) where {T <: RingElement}
   return main_variable_coefficient_deglex(a, k, n)
end

function main_variable_coefficient(a::MPoly{T}, k::Int, n::Int, ::Val{:degrevlex}) where {T <: RingElement}
   return main_variable_coefficient_deglex(a, k, n)
end

function main_variable_extract(a::MPoly{T}, k::Int) where {T <: RingElement}
   sym = parent(a).S[nvars(parent(a)) - k + 1]
   R = SparsePolyRing{MPoly{T}}(parent(a), sym, false)
   return main_variable_extract(R, a, k)
end

# Turn an MPoly into a SparsePoly in the main variable k
function main_variable_extract(R::SparsePolyRing, a::MPoly{T}, k::Int) where {T <: RingElement}
   V = [(a.exps[k, i], i) for i in 1:length(a)]
   sort!(V)
   N = size(a.exps, 1)
   Rc = [a.coeffs[V[i][2]] for i in 1:length(a)]
   Re = zeros(UInt, N, length(a))
   for i = 1:length(a)
      for j = 1:N
         Re[j, i] = a.exps[j, V[i][2]]
      end
   end
   a2 = parent(a)(Rc, Re)
   A = main_variable_terms(a2, k)
   Pe = zeros(UInt, length(A))
   Pc = Vector{MPoly{T}}(undef, length(A))
   ord = internal_ordering(parent(a))
   for i = 1:length(A)
      Pe[i] = a2.exps[k, A[i]]
      Pc[i] = main_variable_coefficient(a2, k, A[i], Val(ord))
   end
   return R(Pc, Pe)
end

function is_less_lex(a::Tuple, b::Tuple)
   N = length(a[1])
   for i = N:-1:1
      if a[1][i] < b[1][i]
         return true
      elseif a[1][i] > b[1][i]
         return false
      end
   end
   return false
end

# Convert a SparsePoly back into an MPoly in a main variable k
function main_variable_insert_lex(a::SparsePoly{MPoly{T}}, k::Int) where {T <: RingElement}
   N = base_ring(a).N
   V = [(ntuple(i -> i == k ? a.exps[r] : a.coeffs[r].exps[i, s], Val(N)), r, s) for
       r in 1:length(a) for s in 1:length(a.coeffs[r])]
   sort!(V, lt = is_less_lex)
   Rc = [a.coeffs[V[i][2]].coeffs[V[i][3]] for i in length(V):-1:1]
   Re = zeros(UInt, N, length(V))
   for i = 1:length(V)
      for j = 1:N
         Re[j, length(V) - i + 1] = V[i][1][j]
      end
   end
   return base_ring(a)(Rc, Re)
end

# Convert a SparsePoly back into an MPoly in a main variable k
function main_variable_insert_deglex(a::SparsePoly{MPoly{T}}, k::Int) where {T <: RingElement}
   N = base_ring(a).N
   V = [(ntuple(i -> i == N ? a.exps[r] + a.coeffs[r].exps[N, s] : (i == k ? a.exps[r] :
        a.coeffs[r].exps[i, s]), Val(N)), r, s) for r in 1:length(a) for s in 1:length(a.coeffs[r])]
   sort!(V, lt = is_less_lex)
   Rc = [a.coeffs[V[i][2]].coeffs[V[i][3]] for i in length(V):-1:1]
   Re = zeros(UInt, N, length(V))
   for i = 1:length(V)
      for j = 1:N
         Re[j, length(V) - i + 1] = V[i][1][j]
      end
   end
   return base_ring(a)(Rc, Re)
end

function is_less_degrevlex(a::Tuple, b::Tuple)
   N = length(a[1])
   if a[1][N] < b[1][N]
      return true
   elseif a[1][N] > b[1][N]
      return false
   end
   for i = N - 1:-1:1
      if a[1][i] > b[1][i]
         return true
      elseif a[1][i] < b[1][i]
         return false
      end
   end
   return false
end

# Convert a SparsePoly back into an MPoly in a main variable k
function main_variable_insert_degrevlex(a::SparsePoly{MPoly{T}}, k::Int) where {T <: RingElement}
   N = base_ring(a).N
   V = [(ntuple(i -> i == N ? a.exps[r] + a.coeffs[r].exps[N, s] : (i == k ? a.exps[r] :
        a.coeffs[r].exps[i, s]), Val(N)), r, s) for r in 1:length(a) for s in 1:length(a.coeffs[r])]
   sort!(V, lt = is_less_degrevlex)
   Rc = [a.coeffs[V[i][2]].coeffs[V[i][3]] for i in length(V):-1:1]
   Re = zeros(UInt, N, length(V))
   for i = 1:length(V)
      for j = 1:N
         Re[j, length(V) - i + 1] = V[i][1][j]
      end
   end
   return base_ring(a)(Rc, Re)
end

function main_variable_insert(a::SparsePoly{MPoly{T}}, k::Int) where {T <: RingElement}
   ord = base_ring(a).ord
   if ord == :lex
      return main_variable_insert_lex(a, k)
   elseif ord == :deglex
      return main_variable_insert_deglex(a, k)
   else
      return main_variable_insert_degrevlex(a, k)
   end
end

###############################################################################
#
#   Build context
#
###############################################################################

# We use Ring instead of MPolyRing to support other multivariate objects
# e.g. Series, non-commutative rings in Singular, etc.

@doc raw"""
    MPolyBuildCtx(R::MPolyRing)

Return a build context for creating polynomials in the given ring.
"""
function MPolyBuildCtx(R::AbstractAlgebra.NCRing)
   return MPolyBuildCtx(R, Nothing)
end

function show(io::IO, M::MPolyBuildCtx)
   print(io, "Builder for an element of ")
   print(terse(pretty(io)), Lowercase(), parent(M.poly))
end

@doc raw"""
    push_term!(M::MPolyBuildCtx, c::RingElem, v::Vector{Int})

Add the term with coefficient `c` and exponent vector `v` to the polynomial under
construction in the build context `M`.
"""
function push_term!(M::MPolyBuildCtx{T}, c::S, expv::Vector{Int}) where {T, S}
   if T <: AbstractAlgebra.MPolyRingElem && length(expv) != nvars(parent(M.poly))
      error("length of exponent vector should match the number of variables")
   end
   if iszero(c)
      return M
   end
   len = length(M.poly) + 1
   if T <: AbstractAlgebra.FreeAssociativeAlgebraElem
      set_exponent_word!(M.poly, len, expv)
   else
      set_exponent_vector!(M.poly, len, expv)
   end
   setcoeff!(M.poly, len, c)
   return M
end

@doc raw"""
    finish(M::MPolyBuildCtx)

Finish construction of the polynomial, sort the terms, remove duplicate and
zero terms and return the created polynomial.
"""
function finish(M::MPolyBuildCtx{T}) where T
   (res, M.poly) = (M.poly, zero(parent(M.poly)))
   return combine_like_terms!(sort_terms!(res))
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(a::MPoly{T}) where {T <: RingElement}
   a.length = 0
   return a
end

function one!(a::MPoly{T}) where {T <: RingElement}
   is_trivial(parent(a)) && return zero!(a)
   a.length = 1
   fit!(a, 1)
   a.coeffs[1] = one(base_ring(a))
   a.exps = zero(a.exps)
   return a
end

function neg!(a::MPoly{T}) where {T <: RingElement}
   for i in 1:length(a)
      a.coeffs[i] = neg!(a.coeffs[i])
   end
   return a
end

function neg!(z::MPoly{T}, a::MPoly{T}) where {T <: RingElement}
   if z === a
      return neg!(a)
   end
   z.length = length(a)
   fit!(z, length(a))
   for i in 1:length(a)
      if isassigned(z.coeffs, i)
         z.coeffs[i] = neg!(z.coeffs[i], a.coeffs[i])
      else
         z.coeffs[i] = -a.coeffs[i]
      end
   end
   z.exps[:,1:length(a)] .= a.exps[:,1:length(a)]
   return z
end

function add!(a::MPoly{T}, b::MPoly{T}, c::MPoly{T}) where {T <: RingElement}
   t = b + c
   a.coeffs = t.coeffs
   a.exps = t.exps
   a.length = t.length
   return a
end

function sub!(a::MPoly{T}, b::MPoly{T}, c::MPoly{T}) where {T <: RingElement}
   t = b - c
   a.coeffs = t.coeffs
   a.exps = t.exps
   a.length = t.length
   return a
end

function mul!(a::MPoly{T}, b::MPoly{T}, c::MPoly{T}) where {T <: RingElement}
   t = b*c
   a.coeffs = t.coeffs
   a.exps = t.exps
   a.length = t.length
   return a
end

function addmul!(a::MPoly{T}, b::MPoly{T}, c::MPoly{T}) where {T <: RingElement}
   t = b * c
   return add!(a, t)
end

function resize_exps!(a::Matrix{UInt}, n::Int)
   if n > size(a, 2)
      N = size(a, 1)
      A = reshape(a, size(a, 2)*N)
      new_size = max(n, 2*size(a, 2))
      resize!(A, new_size*N)
      return reshape(A, N, new_size)
   end
   return a
end

function fit!(a::MPoly{T}, n::Int) where {T <: RingElement}
   if length(a.coeffs) < n
      resize!(a.coeffs, n)
      a.exps = resize_exps!(a.exps, n)
   end
   return nothing
end

@doc raw"""
    setcoeff!(a::MPoly{T}, i::Int, c::T) where T <: RingElement

Set the coefficient of the i-th term of the polynomial to $c$.
"""
setcoeff!(a::MPoly{<: RingElement}, i::Int, c::RingElement)

for T in [RingElem, Integer, Rational, AbstractFloat]
  @eval begin
    function setcoeff!(a::MPoly{S}, i::Int, c::S) where {S <: $T}
       fit!(a, i)
       a.coeffs[i] = c
       if i > length(a)
          a.length = i
       end
       return a
    end
  end
end

@doc raw"""
    setcoeff!(a::MPoly{T}, i::Int, c::U) where {T <: RingElement, U <: Integer}

Set the coefficient of the i-th term of the polynomial to the integer $c$.
"""
function setcoeff!(a::MPoly{T}, i::Int, c::U) where {T <: RingElement, U <: Integer}
    return setcoeff!(a, i, base_ring(a)(c))
end

@doc raw"""
    combine_like_terms!(a::MPoly{T}) where T <: RingElement

Remove zero terms and combine adjacent terms if they have the same
exponent vector. The modified polynomial is returned.
"""
function combine_like_terms!(a::MPoly{T}) where T <: RingElement
   A = a.exps
   N = size(A, 1)
   i = 1
   j = 0
   while i <= length(a)
      c = a.coeffs[i]
      while i < length(a) && iszero(c)
         i += 1
         c = a.coeffs[i]
      end
      k = i
      i += 1
      while i <= length(a) && monomial_isequal(A, k, i, N)
         c += a.coeffs[i]
         i += 1
      end
      if !iszero(c)
         j += 1
         a.coeffs[j] = c
         monomial_set!(A, j, A, k, N)
      end
   end
   a.length = j
   return a
end

###############################################################################
#
#   Promotion rules
#
###############################################################################

promote_rule(::Type{MPoly{T}}, ::Type{MPoly{T}}) where T <: RingElement = MPoly{T}

function promote_rule(::Type{MPoly{T}}, ::Type{U}) where {T <: RingElement, U <: RingElement}
   promote_rule(T, U) == T ? MPoly{T} : Union{}
end

#function promote_rule(::Type{T}, ::Type{MPoly{T}}) where {T <: RingElement}
#   return MPoly{T}
#end

###############################################################################
#
#   Parent object call overload
#
###############################################################################

function (a::MPolyRing{T})(b::RingElement) where {T <: RingElement}
   return a(base_ring(a)(b))
end

@doc raw"""
    (a::MPolyRing{T})() where {T <: RingElement}

Construct the zero polynomial in the given polynomial ring.
"""
function (a::MPolyRing{T})() where {T <: RingElement}
   z = MPoly{T}(a)
   return z
end

@doc raw"""
    (a::MPolyRing{T})(b::Union{Integer, Rational, AbstractFloat}) where {T <: RingElement}

Construct the constant polynomial `b` in the given polynomial ring.
"""
function (a::MPolyRing{T})(b::Union{Integer, Rational, AbstractFloat}) where {T <: RingElement}
   z = MPoly{T}(a, base_ring(a)(b))
   return z
end

function (a::MPolyRing{T})(b::T) where {T <: Union{Integer, Rational, AbstractFloat}}
   z = MPoly{T}(a, b)
   return z
end

@doc raw"""
    (a::MPolyRing{T})(b::T) where {T <: RingElement}

Construct the constant polynomial `b` in the given polynomial ring.
"""
function (a::MPolyRing{T})(b::T) where {T <: RingElement}
   parent(b) != base_ring(a) && error("Unable to coerce to polynomial")
   z = MPoly{T}(a, b)
   return z
end

function (a::MPolyRing{T})(b::MPoly{T}) where {T <: RingElement}
   parent(b) != a && error("Unable to coerce polynomial")
   return b
end

function (a::MPolyRing{T})(b::Vector{T}, m::Matrix{UInt}) where {T <: RingElement}
   if length(b) > 0 && isassigned(b, 1)
      parent(b[1]) != base_ring(a) && error("Unable to coerce to polynomial")
   end
   z = MPoly{T}(a, b, m)
   return z
end

# This is the main user interface for efficiently creating a polynomial. It accepts
# an array of coefficients and an array of exponent vectors. Sorting, coalescing of
# like terms and removal of zero terms is performed.
function (a::MPolyRing{T})(b::Vector{T}, m::Vector{Vector{Int}}) where {T <: RingElement}
   if length(b) > 0 && isassigned(b, 1)
       parent(b[1]) != base_ring(a) && error("Unable to coerce to polynomial")
   end

   for i in 1:length(m)
      length(m[i]) != nvars(a) && error("Exponent vector $i has length $(length(m[i])) (expected $(nvars(a)))")
   end

   N = a.N
   ord = internal_ordering(a)
   Pe = Matrix{UInt}(undef, N, length(m))

   if ord == :lex
      for i = 1:length(m)
         for j = 1:N
            Pe[j, i] = UInt(m[i][N - j + 1])
         end
      end
   elseif ord == :deglex
      for i = 1:length(m)
         for j = 1:N - 1
            Pe[j, i] = UInt(m[i][N - j])
         end
         Pe[N, i] = UInt(sum(m[i]))
      end
   else # degrevlex
      for i = 1:length(m)
         for j = 1:N - 1
            Pe[j, i] = UInt(m[i][j])
         end
         Pe[N, i] = UInt(sum(m[i]))
      end
   end

   z = MPoly{T}(a, b, Pe)
   z = sort_terms!(z)
   z = combine_like_terms!(z)
   return z
end
