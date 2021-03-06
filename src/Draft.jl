########## Collection of obseleted codes ##########

# function rolling_estim(func::Function, X::AbstractMatrix{T}, widx::AbstractArray{Int}, p::Int) where {T<:Real}
#     # wsize = w[end]-w[1]+1
#     # @assert wsize <= size(X,2)
#     return [func(X[:,n+widx]) for n=1:p:size(X,2) if n+widx[end]<size(X,2)]
#     # res = []
#     # for n=1:p:size(X,2)
#     #     idx = n+w
#     #     idx = idx[idx.<=size(X,2)]
#     #     push!(res, func(view(X, :,n+w)))
#     # end
# end


# function rolling_estim(fun::Function, X::AbstractVector{T}, wsize::Int, p::Int=1) where T
#     offset = wsize-1
#     res = [fun(view(X, (n*p):(n*p+wsize-1))) for n=1:p:N]
#     end

#     # y = fun(view(X, idx:idx+offset))  # test return type of fun
#     res = Vector{typeof(y)}(undef, div(length(data)-offset, p))
#     @inbounds for n=1:p:N
#         push!(res, fun(view(X, (idx*p):(idx*p+offset))))
#         end
#     @inbounds for n in eachindex(res)
#         res[n] = fun(hcat(X[idx*p:idx*p+offset]...))
#     end

#     return res
# end


# function scalogram_estim(Cxx::Matrix{Float64}, sclrng::AbstractArray{Int}, ρmax::Int=1)
#     nr, nc = size(Cxx)
#     @assert nr == nc == length(sclrng)
#     @assert ρmax >= 1
#     xvar = Float64[]
#     yvar = Float64[]
#     for ρ=1:ρmax
#         toto = [Cxx[j, ρ*j] for j in 1:nr if ρ*j<=nr]
#         xvar = vcat(xvar, sclrng[1:length(toto)])
#         yvar = vcat(yvar, abs.(toto))
#     end
#     df = DataFrames.DataFrame(
#         xvar=log2.(xvar),
#         yvar=log2.(yvar)
#     )
#     ols_hurst = GLM.lm(@GLM.formula(yvar~xvar), df)
#     hurst_estim = (GLM.coef(ols_hurst)[2]-1)/2
#     return hurst_estim, ols_hurst
# end

function powlaw_estim(X::Vector{Float64}, lags::AbstractArray{Int}, pows::AbstractArray{T}) where {T<:Real}
    @assert length(lags) > 1 && all(lags .> 1)

    # Define the function for computing the p-th moment of the increment
    moment_incr(X,d,p) = mean((abs.(X[d+1:end] - X[1:end-d])).^p)

    # Estimation of Hurst exponent and β
    H = zeros(Float64, length(pows))
    β = zeros(Float64, length(pows))
    C = zeros(Float64, length(pows))

    for (n,p) in enumerate(pows)
        powlaw_estim()
        C[n] = 2^(p/2) * gamma((p+1)/2)/sqrt(pi)

        yp = map(d -> log(moment_incr(X, d, p)), lags)
        xp = p * log.(lags)
        Ap = hcat(xp, ones(length(xp)))  # design matrix
        H[n], β[n] = Ap \ yp  # estimation of H and β

        # dg = DataFrames.DataFrame(xvar=Ap, yvar=yp)
        # ols = GLM.lm(@GLM.formula(yvar ~ xvar), dg)
        # β[n], H[n] = GLM.coef(ols)
    end

    Σ = exp.((β-log.(C))./pows)

    hurst = sum(H) / length(H)
    σ = sum(Σ) / length(Σ)

    return hurst, σ
end


function powlaw_estim_old(X::Vector{Float64}, lags::AbstractArray{Int}, pows::AbstractArray{T}) where {T<:Real}
    # Define the function for computing the p-th moment of the increment
    moment_incr(X,d,p) = mean((abs.(X[d+1:end] - X[1:end-d])).^p)

    # Estimation of Hurst exponent
    Y = zeros(Float64, (length(lags), length(pows)))
    for (n,p) in enumerate(pows)
        Y[:,n] = map(d -> log(moment_incr(X, d, p)), lags)
    end
    dY = diff(Y, 1)
    df = DataFrames.DataFrame(xvar=(diff(log.(lags)) * pows')[:],
                              yvar=dY[:])
    ols_hurst = GLM.lm(@GLM.formula(yvar ~ xvar), df)
    Hurst = GLM.coef(ols_hurst)[2]  # estimation of hurst exponent

    # Estimation of volatility
    # Constant in the p-th moment of normal distribution, see
    # https://en.wikipedia.org/wiki/Normal_distribution#Moments
    cps = [2^(p/2) * gamma((p+1)/2)/sqrt(pi) for p in pows]
    Z = Y -  Hurst * (log.(lags) * pows') - ones(lags) * log.(cps)'
    dg = DataFrames.DataFrame(xvar=(ones(lags) * pows')[:],
                              yvar=Z[:])
    ols_sigma = GLM.lm(@GLM.formula(yvar ~ xvar), dg)

    return Y, Dict('H'=>ols_hurst, 'σ'=>ols_sigma)
end

"""
Extract the estimates of Hurst and voaltility from the result of `powlaw_estim`.
"""
function powlaw_coeff(ols::Dict, h::Float64)
    H = GLM.coef(ols['H'])[2]
    σ = exp(GLM.coef(ols['σ'])[2] - H * log(h))

    return H, σ
end


##### Special functions #####

"""
Compute the continued fraction involved in the upper incomplete gamma function using the modified Lentz's method.
"""
function _uigamma_cf(s::Complex, z::Complex; N=100, epsilon=1e-20)
#     a::Complex = 0
#     b::Complex = 0
#     d::Complex = 0
    u::Complex = s
    v::Complex = 0
    p::Complex = 0

    for n=1:N
#         a, b = (n%2==1) ? ((-div(n-1,2)-s)*z, s+n) : (div(n,2)*z, s+n)
        a, b = (n%2==1) ? ((-div(n-1,2)-s), (s+n)/z) : (div(n,2), (s+n)/z)
        u = b + a / u
        v = 1/(b + a * v)
        d = log(u * v)
        (abs(d) < epsilon) ? break : (p += d)
#         println("$(a), $(b), $(u), $(v), $(d), $(p), $(exp(p))")
    end
    return s * exp(p)
end

doc"""
    uigamma0(z::Complex; N=100, epsilon=1e-20)

Upper incomplete gamma function with vanishing first argument:
$$ \Gamma(0,z) = \lim_{a\rightarrow 0} \Gamma(a,z) $$

Computed using the series expansion of the [exponential integral](https://en.wikipedia.org/wiki/Exponential_integral) $E_1(z)$.
"""
function uigamma0(z::Number; N=100, epsilon=1e-20)
    #     A::Vector{Complex} = [(-z)^k / k / exp(lgamma(k+1)) for k=1:N]
    #     s = sum(A[abs.(A)<epsilon])
    s::Complex = 0
    for k=1:N
        d = (-z)^k / k / exp(lgamma(k+1))
        (abs(d) < epsilon) ? break : (s += d)
    end
    r = -(eulergamma + log(z) + s)
    return (typeof(z) <: Real ? real(r) : r)
end

# """
# Upper incomplete gamma function.
# """
# function uigamma(a::Real, z::T; N=100, epsilon=1e-8) where {T<:Number}
#     z == 0 && return gamma(a)
#     u::T = z
#     v::T = 0
#     f::T = z
# #     f::Complex = log(z)
#     for n=1:N
#         an, bn = (n%2==1) ? (div(n+1,2)-a, z) : (div(n,2), 1)
#         u = bn + an / u
#         v = bn + an * v
#         f *= (u/v)
# #         f += (log(α) - log(β))
#         println("$(an), $(bn), $(u), $(v), $(f)")
#         if abs(u/v-1) < epsilon
#             break
#         end
#     end
#     return z^a * exp(-z) / f
# #     return z^a * exp(-z-f)
# end


doc"""
    uigamma(s::Complex, z::Complex; N=100, epsilon=1e-20)

Upper incomplete gamma function $\Gamma(s,z)$ with complex arguments.

Computed using the [continued fraction representation](http://functions.wolfram.com/06.06.10.0005.01).
The special case $\Gamma(0,z)$ is computed via the series expansion of the exponential integral $E_1(z)$.

# Reference
- [Upper incomplete gamma function](https://en.wikipedia.org/wiki/Incomplete_gamma_function)
- [Continued fraction representation](http://functions.wolfram.com/06.06.10.0005.01)
- [Exponential integral](https://en.wikipedia.org/wiki/Exponential_integral)
"""

function uigamma(s::Number, z::Number; N=100, epsilon=1e-20)
    if abs(s) == 0
        return uigamma0(z; N=N, epsilon=epsilon)
    end

    r = gamma(s) - z^s * exp(-z) / _uigamma_cf(Complex(s), Complex(z); N=N, epsilon=epsilon)
    return (typeof(s)<:Real && typeof(z)<:Real) ? real(r) : r
end

doc"""
    ligamma(s::Complex, z::Complex; N=100, epsilon=1e-20)

Lower incomplete gamma function $\gamma(s,z)$ with complex arguments.
"""
function ligamma(s::Number, z::Number; N=100, epsilon=1e-20)
    return gamma(s) - uigamma(s, z; N=N, epsilon=epsilon)
end



function wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractArray{Int}, v::Int, H::Real, σ::Real; mode::Symbol=:center)
    N, d = size(X)  # length and dim of X
    A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
    C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

    Σ = σ^2 * C1 .* A
    # Σ += Matrix(1.0I, size(Σ)) * max(1e-8, mean(abs.(Σ))*1e-5)
    # println("H=$H, σ=$σ, det(Σ)=$(det(Σ))")

    # method 1:
    # iX = Σ \ X'  # <- unstable!

    # method 2:
    # iΣ = pinv(Σ)  # regularization by pseudo-inverse
    # iX = iΣ * X'

    # method 3:
    iX = lsqr(Σ, X')

    return -1/2 * (tr(X*iX) + N*logdet(Σ) + N*d*log(2π))
end


function grad_wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractArray{Int}, v::Int, H::Real, σ::Real; mode::Symbol=:center)
    N, d = size(X)  # length and dim of X
    A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
    C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]
    dAda = [log(i*j) for i in sclrng, j in sclrng] .* A
    dC1da = [diff_C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

    Σ = σ^2 * C1 .* A
    # Σ += Matrix(1.0I, size(Σ)) * max(1e-8, mean(abs.(Σ))*1e-5)

    dΣda = σ^2 * (dC1da .* A + C1 .* dAda)
    dΣdb = 2σ * C1 .* A

    # method 1:
    # iX = Σ \ X'
    # da = N * tr(Σ \ dΣda) - tr(iX' * dΣda * iX)
    # db = N * tr(Σ \ dΣdb) - tr(iX' * dΣdb * iX)

    # method 2:
    # iΣ = pinv(Σ)  # regularization by pseudo-inverse
    # iX = iΣ * X'
    # da = N * tr(iΣ * dΣda) - tr(iX' * dΣda * iX)
    # db = N * tr(iΣ * dΣdb) - tr(iX' * dΣdb * iX)

    # method 3:
    iX = lsqr(Σ, X')
    da = N * tr(lsqr(Σ, dΣda)) - tr(iX' * dΣda * iX)
    db = N * tr(lsqr(Σ, dΣdb)) - tr(iX' * dΣdb * iX)

    return  -1/2 * [da, db]
end




function wavelet_MLE_estim(X::Matrix{Float64}, sclrng::AbstractArray{Int}, v::Int, d::Int=1, vars::Symbol=:all, init::Vector{Float64}=[0.5,1.]; cflag::Bool=false, dflag::Bool=false, mode::Symbol=:center)
    @assert size(X,2) == length(sclrng)
    @assert length(init) == 2
    @assert d >= 1

    func = x -> ()
    grad = x -> ()
    hurst_estim, σ_estim = init

    if vars == :all
        func = x -> -wavelet_MLE_obj(X[1:d:end, :], sclrng, v, x[1], x[2]; cflag=cflag, mode=mode)
        grad = x -> -grad_wavelet_MLE_obj(X[1:d:end,:], sclrng, v, x[1], x[2]; cflag=cflag, mode=mode)
    elseif vars == :hurst
        func = x -> -wavelet_MLE_obj(X[1:d:end, :], sclrng, v, x[1], σ_estim; cflag=cflag, mode=mode)
        grad = x -> -grad_wavelet_MLE_obj(X[1:d:end,:], sclrng, v, x[1], σ_estim; cflag=cflag, mode=mode)
    else
        func = x -> -wavelet_MLE_obj(X[1:d:end, :], sclrng, v, hurst_estim, x[2]; cflag=cflag, mode=mode)
        grad = x -> -grad_wavelet_MLE_obj(X[1:d:end,:], sclrng, v, hurst_estim, x[2]; cflag=cflag, mode=mode)
    end

    ε = 1e-10
    # opm = Optim.optimize(func, [ε, ε], [1-ε, 1/ε], init, Optim.Fminbox(Optim.GradientDescent()))
    opm = dflag ? Optim.optimize(func, grad, [ε, ε], [1-ε, 1/ε], init, Optim.Fminbox(Optim.GradientDescent()); inplace=false) : Optim.optimize(func, [ε, ε], [1-ε, 1/ε], init, Optim.Fminbox(Optim.GradientDescent()))
    # Optim.BFGS() or Optim.GradientDescent()
    res = Optim.minimizer(opm)

    if vars == :all
        hurst_estim = cflag ? sigmoid(res[1]) : res[1]
        σ_estim = cflag ? exp(res[2]) : res[2]
    elseif vars == :hurst
        hurst_estim = cflag ? sigmoid(res[1]) : res[1]
    else
        σ_estim = cflag ? exp(res[2]) : res[2]
    end

    return (hurst_estim, σ_estim), opm
end




# function partial_bspline_covmat(sclrng::AbstractVector{Int}, v::Int, H::Real, mode::Symbol)
#     return full_bspline_covmat(0, sclrng, v, H, mode)
# end


# function partial_bspline_log_likelihood_H(X::AbstractVecOrMat{T}, sclrng::AbstractVector{Int}, v::Int, H::Real; mode::Symbol=:center) where {T<:Real}
#     # @assert size(X,1) == length(sclrng)
#     Σ = partial_bspline_covmat(sclrng, v, H, mode)
#     # println(size(Σ))
#     # println(size(X))

#     return log_likelihood_H(Σ, X)
# end


# """
# B-Spline wavelet-MLE estimator with partial covariance matrix.
# """
# function partial_bspline_MLE_estim(X::AbstractVecOrMat{T}, sclrng::AbstractVector{Int}, v::Int; init::Real=0.5, mode::Symbol=:center) where {T<:Real}
#     @assert size(X,1) == length(sclrng)

#     func = h -> -partial_bspline_log_likelihood_H(X, sclrng, v, h; mode=mode)

#     ε = 1e-5
#     # optimizer = Optim.GradientDescent()  # e.g. Optim.BFGS(), Optim.GradientDescent()
#     # optimizer = Optim.BFGS()
#     # opm = Optim.optimize(func, ε, 1-ε, [0.5], Optim.Fminbox(optimizer))
#     opm = Optim.optimize(func, ε, 1-ε, Optim.Brent())

#     hurst = Optim.minimizer(opm)[1]

#     Σ = partial_bspline_covmat(sclrng, v, hurst, mode)
#     σ = sqrt(xiAx(Σ, X) / length(X))

#     return (hurst, σ), opm
# end






function partial_wavelet_log_likelihood_H(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int, H::Real; mode::Symbol=:center)
    N, J = size(X)  # length and dim of X

    A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
    Σ = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng] .* A

    iΣ = pinv(Σ)  # regularization by pseudo-inverse

    return -1/2 * (J*N*log(sum(X' .* (iΣ * X'))) + N*logdet(Σ))
end


function partial_wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int, H::Real, σ::Real; mode::Symbol=:center)
    N, d = size(X)  # length and dim of X

    A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
    C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

    Σ = σ^2 * C1 .* A
    # Σ += Matrix(1.0I, size(Σ)) * max(1e-10, mean(abs.(Σ))*1e-5)

    # println("H=$(H), σ=$(σ), mean(Σ)=$(mean(abs.(Σ)))")
    # println("logdet(Σ)=$(logdet(Σ))")

    # method 1:
    # iX = Σ \ X'

    # method 2:
    iΣ = pinv(Σ)  # regularization by pseudo-inverse
    iX = iΣ * X'  # regularization by pseudo-inverse

    # # method 3:
    # iX = lsqr(Σ, X')

    return -1/2 * (tr(X*iX) + N*logdet(Σ) + N*d*log(2π))
end


# function wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int, H::Real, σ::Real; mode::Symbol=:center)
#     N, d = size(X)  # length and dim of X

#     A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
#     C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

#     Σ = σ^2 * C1 .* A
#     # Σ += Matrix(1.0I, size(Σ)) * max(1e-10, mean(abs.(Σ))*1e-5)

#     # println("H=$(H), σ=$(σ), mean(Σ)=$(mean(abs.(Σ)))")
#     # println("logdet(Σ)=$(logdet(Σ))")

#     # method 1:
#     # iX = Σ \ X'

#     # method 2:
#     iΣ = pinv(Σ)  # regularization by pseudo-inverse
#     iX = iΣ * X'  # regularization by pseudo-inverse

#     # # method 3:
#     # iX = lsqr(Σ, X')

#     return -1/2 * (tr(X*iX) + N*logdet(Σ) + N*d*log(2π))
# end


# older version:
# function wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int, α::Real, β::Real; cflag::Bool=false, mode::Symbol=:center)
#     N, d = size(X)  # length and dim of X

#     H = cflag ? sigmoid(α) : α
#     σ = cflag ? exp(β) : β

#     A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
#     C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

#     Σ = σ^2 * C1 .* A
#     # Σ += Matrix(1.0I, size(Σ)) * max(1e-8, mean(abs.(Σ))*1e-5)

#     # println("H=$(H), σ=$(σ), α=$(α), β=$(β), mean(Σ)=$(mean(abs.(Σ)))")
#     # println("logdet(Σ)=$(logdet(Σ))")

#     # method 1:
#     # iX = Σ \ X'

#     # # method 2:
#     # iΣ = pinv(Σ)  # regularization by pseudo-inverse
#     # iX = iΣ * X'  # regularization by pseudo-inverse

#     # method 3:
#     iX = lsqr(Σ, X')

#     return -1/2 * (tr(X*iX) + N*log(abs(det(Σ))) + N*d*log(2π))
# end


# function grad_wavelet_MLE_obj(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int, α::Real, β::Real; cflag::Bool=false, mode::Symbol=:center)
#     N, d = size(X)  # length and dim of X

#     H = cflag ? sigmoid(α) : α
#     σ = cflag ? exp(β) : β

#     A = [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
#     C1 = [C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]
#     dAda = [log(i*j) for i in sclrng, j in sclrng] .* A
#     dC1da = [diff_C1rho(0, j/i, H, v, mode) for i in sclrng, j in sclrng]

#     if cflag
#         dAda *= diff_sigmoid(α)
#         dC1da *= diff_sigmoid(α)
#     end

#     Σ = σ^2 * C1 .* A
#     # Σ += Matrix(1.0I, size(Σ)) * max(1e-8, mean(abs.(Σ))*1e-5)
#     dΣda = σ^2 * (dC1da .* A + C1 .* dAda)
#     dΣdb = cflag ? 2*Σ : 2σ * C1 .* A

#     # method 1:
#     # iX = Σ \ X'
#     # da = N * tr(Σ \ dΣda) - tr(iX' * dΣda * iX)
#     # db = N * tr(Σ \ dΣdb) - tr(iX' * dΣdb * iX)

#     # method 2:
#     iΣ = pinv(Σ)  # regularization by pseudo-inverse
#     iX = iΣ * X'
#     da = N * tr(iΣ * dΣda) - tr(iX' * dΣda * iX)
#     db = N * tr(iΣ * dΣdb) - tr(iX' * dΣdb * iX)

#     # method 3:
#     # iX = lsqr(Σ, X')
#     # da = N * tr(lsqr(Σ, dΣda)) - tr(iX' * dΣda * iX)
#     # db = N * tr(lsqr(Σ, dΣdb)) - tr(iX' * dΣdb * iX)

#     return  -1/2 * [da, db]
# end


function wavelet_MLE_estim(X::Matrix{Float64}, sclrng::AbstractVector{Int}, v::Int; vars::Symbol=:all, init::Vector{Float64}=[0.5,1.], mode::Symbol=:center)
    @assert size(X,2) == length(sclrng)
    @assert length(init) == 2

    func = x -> ()
    hurst, σ = init
    # println(init)

    if vars == :all
        func = x -> -wavelet_MLE_obj(X, sclrng, v, x[1], x[2]; mode=mode)
    elseif vars == :hurst
        func = x -> -wavelet_MLE_obj(X, sclrng, v, x[1], σ; mode=mode)
    else
        func = x -> -wavelet_MLE_obj(X, sclrng, v, hurst, x[2]; mode=mode)
    end

    ε = 1e-8
    # optimizer = Optim.GradientDescent()  # e.g. Optim.BFGS(), Optim.GradientDescent()
    optimizer = Optim.BFGS()
    opm = Optim.optimize(func, [ε, ε], [1-ε, 1/ε], init, Optim.Fminbox(optimizer))
    # opm = Optim.optimize(func, [ε, ε], [1-ε, 1/ε], init, Optim.Fminbox(optimizer); autodiff=:forward)
    res = Optim.minimizer(opm)

    if vars == :all
        hurst, σ = res[1], res[2]
    elseif vars == :hurst
        hurst = res[1]
    else
        σ = res[2]
    end

    return (hurst, σ), opm
end





function split_by_day(data::TimeArray)
    res = []
    d0, d1 = Dates.Date(TimeSeries.timestamp(data[1])[1]), Dates.Date(TimeSeries.timestamp(data[end])[1])

    for d in d0:Dates.Day(1):d1
        m0 = Dates.DateTime(d)
        m1 = Dates.DateTime(d + Dates.Hour(23) + Dates.Minute(59))
        mtsp = m0:Dates.Minute(1):m1  # full timestamp
        stsp = intersect(mtsp, TimeSeries.timestamp(data))  # valid timestamp
        if length(stsp) > 0
            push!(res, data[mtsp])
        end
    end

    return res
end




function rolling_regress_predict(regressor::Function, predictor::Function, X0::AbstractVecOrMat{T}, Y0::AbstractVecOrMat{T}, λ::Int, (w,s,d)::Tuple{Int,Int,Int}, p::Int, trans::Function=(x->vec(x)); mode::Symbol=:causal) where {T<:Number}
    X = ndims(X0)>1 ? X0 : reshape(X0, 1, :)  # vec to matrix, create a reference not a copy
    Y = ndims(Y0)>1 ? Y0 : reshape(Y0, 1, :)
    @assert size(X,2) == size(Y,2)

    (any(isnan.(X)) || any(isnan.(Y))) && throw(ValueError("Inputs cannot contain nan values!"))
    L = size(X,2)  # total time
    @assert L >= w >= s

    res_time, res_reg, res_prd = [], [], []  # temporary lists

    if mode == :causal  # causal
        xf, yf = [], []  # future data (due to reversal of time) used for prediction

        for t = L:-p:w
            printfmtln("Processing time {}...\r", t)

            # xv = rolling_apply_hard(trans, view(X, :, max(1, t-w+1):t), s, d; mode=:causal)
            # yv0 = view(Y, :, max(1, t-w+1):t)[:, end:-d:1]  # time-reversed
            # yv = yv0[:,1:size(xv,2)][:,end:-1:1]  # reverse back
            xv = rolling_apply_hard(trans, view(X, :, t-w+1:t), s, d; mode=:causal)
            yv0 = view(Y, :, t-w+1:t)[:, end:-d:1]  # time-reversed
            yv = yv0[:,1:size(xv,2)][:,end:-1:1]  # reverse back

            (xs, ys) = if nan == :ignore
                # ignore columns containing nan values
                idx = findall(.!vec(any(isnan.(vcat(xv, yv)), dims=1)))  # without vec findall will return `CartesianIndex`
                if length(idx) > 0
                    (view(xv,:,idx), view(yv,:,idx))
                else
                    ([], [])
                end
            elseif nan == :zero
                # set all nan to zero
                xv[findall(isnan.(xv))] = 0
                yv[findall(isnan.(yv))] = 0
                (xv, yv)
            else
                (xv, yv)
            end

            if length(xs) > 0 && length(ys) > 0
                reg = regressor(ys, xs)  # regression
                prd = isempty(xf) ? [] : predictor(reg, xf, yf)  # prediction using future data
                pushfirst!(res_time, t)
                pushfirst!(res_reg, reg)
                pushfirst!(res_prd, prd)
            end
            (xf, yf) = if L-t < λ
                ([], [])
            else
                (xv[:,end], yv[:,end])  # yv[:,end]==Y[:,t] is the future truth
            end
        end
        # readjust the prediction
        n = sum([isempty(prd) for prd in res_prd])
        res_prd = circshift(res_prd, n)
    else  # anticausal: TODO
        for t = 1:p:L
            xv = rolling_apply_hard(trans, view(X, :, t:min(L, t+w-1)), s, d; mode=:anticausal)
            yv = rolling_apply_hard(trans, view(Y, :, t:min(L, t+w-1)), 1, d; mode=:anticausal)

            (xs, ys) = if nan == :ignore
                # ignore columns containing nan values
                idx = findall(.!vec(any(isnan.(xv), dims=1) + any(isnan.(yv), dims=1)))  # without vec findall return `CartesianIndex`

                if length(idx) > 0
                    (view(xv,:,idx), view(yv,:,idx))
                else
                    ([], [])
                end
            elseif nan == :zero
                # set all nan to zero
                xv[findall(isnan.(xv))] = 0
                yv[findall(isnan.(yv))] = 0
                (xv, yv)
            else
                (xv, yv)
            end

            if length(xs) > 0 && length(ys) > 0
                # push!(res, (t,regressor(ys, xs)))
                reg = regressor(ys', xs')
                prd = isempty(res_reg) ? [] : predictor(res_reg[end], xv, yv[:,end])
                pushfirst!(res_time, t)
                pushfirst!(res_reg, reg)
                pushfirst!(res_prd, prd)
            end
        end
    end
    res = [(time=t, regression=reg, prediction=prd) for (t, reg, prd) in zip(res_time, res_reg, res_prd)]  # final result is a named tuple
    return res
end




# function moment_incr(X::AbstractVector{T}, d::Integer, p::Real, w::StatsBase.AbstractWeights)
#     mean((abs.(X[d+1:end] - X[1:end-d])).^p, w)
# end

# moment_incr(X, d, p) = moment_incr(X, d, p, StatsBase.weights(ones(length(X)-d)))

"""
Compute the p-th moment of the increment of time-lag `d` of a 1d array.
"""
function moment_incr(X::AbstractVecOrMat{<:Real}, d::Integer, p::Real, k::Int=0)
    dX = X[d+1:end] - X[1:end-d]
    return if k==0  # q is the order of polynomial weight
        mean((abs.(dX)).^p)
    else
        w = StatsBase.weights(causal_weight(length(dX), k))
        mean((abs.(dX)).^p, w)
    end
    # median((abs.(dX)).^p)
end


function moment(X::AbstractVecOrMat{<:Real}, d::Integer, p::Real, k::Int=0)
    w = StatsBase.weights(causal_weight(length(dX), k))
    μX = mean(X, w, dims=1)
    return mean((abs.(X.-μX)).^p, w)
    # return median((abs.(X.-μX)).^p, w)
end


function powlaw_estim(X::AbstractVector{<:Real}, lags::AbstractVector{<:Integer}, p::Real=2.; kt::Integer=1, ks::Integer=0, q::Real=2., ε::Real=1e-2)
    @assert length(lags) > 1 && all(lags .>= 1)
    @assert p > 0.

    cp = 2^(p/2) * gamma((p+1)/2)/sqrt(pi)  # constant depending on p

    # observation and explanatory vectors
    yp = map(d -> log(moment_incr(X, d, p, kt)), lags)
    xp = p * log.(lags)

    # weight for scales
    # wj = length(wj) < length(yp) ? StatsBase.weights(ones(length(yp))/length(yp)) : StatsBase.weights(wj/sum(wj))
    # # @assert all(wj .>= 0)
    w = StatsBase.weights(poly_weight(length(yp), ks))

    yc = yp .- mean(yp, w)
    xc = xp .- mean(xp, w)
    # func = h -> 1/2 * sum(w .* (yc - h*xc).^2)
    func = h -> 1/2 * mean((yc - h*xc).^2, w)
    # func = h -> 1/2 * mean(abs.(yc - h*xc).^q, W)

    # estimation of H and η
    # Gradient-free constrained optimization
    opm = Optim.optimize(func, ε, 1-ε, Optim.Brent())
    # # Gradient-based optimization
    # optimizer = Optim.GradientDescent()  # e.g. Optim.BFGS(), Optim.GradientDescent()
    # opm = Optim.optimize(func, ε, 1-ε, [0.5], Optim.Fminbox(optimizer))
    hurst = Optim.minimizer(opm)[1]
    η = mean(yp - hurst*xp, w)

    # # by manual inversion
    # Ap = hcat(xp, ones(length(xp))) # design matrix
    # hurst, β = Ap \ yp
    # # or by GLM
    # dg = DataFrames.DataFrame(xvar=xp, yvar=yp)
    # opm = GLM.lm(@GLM.formula(yvar~xvar), dg)
    # η, hurst = GLM.coef(opm)

    σ = exp((η-log(cp))/p)

    return (hurst, σ), opm
end
const fBm_powlaw_estim = powlaw_estim


"""
"""
function powlaw_estim_predict(X::AbstractVector{<:Real}, dlag::Integer, Δ::Integer, p::Real, plen::Integer, plag::Integer; kwargs...)
    (H, σ), opm = FracFin.powlaw_estim(X, dlag-Δ:dlag+Δ, p; kwargs...)
    dX0 = X[dlag+1:end] - X[1:end-dlag]
    # dX = view(dX0, length(dX0)-plen+1:length(dX0))
    pidx = reverse(length(dX0):-dlag:1)[end-plen+1:end]
    dX = dX0[pidx]
    # println(length(dX)+dlag)
    # println(length(X))
    μc, Σc = cond_mean_cov(FractionalGaussianNoise(H, dlag), length(dX)+1:length(dX)+plag, pidx, dX)
    return H, σ, μc, σ^2 * Σc
end



"""TODO
Multiscale fGn-MLE
"""
function ms_fGn_MLE_estim(X::AbstractVector{T}, lags::AbstractVector{Int}, w::Int) where {T<:Real}
    Hs = zeros(length(lags))
    Σs = zeros(length(lags))

    for (n,lag) in enumerate(lags)  # time lag for finite difference
        # vectorization with window size w
        dXo = rolling_vectorize(X[lag+1:end]-X[1:end-lag], w, 1, 1)
        # rolling mean with window size 2lag, then down-sample at step lag
        dX = rolling_mean(dXo, 2lag, lag; boundary=:hard)

        (hurst_estim, σ_estim), obj = fGn_MLE_estim(squeezedims(dX), lag)

        Hs[n] = hurst_estim
        Σs[n] = σ_estim
    end

    return Hs, Σs
end



##### B-Spline DCWT MLE (Not maintained) #####
# Implementation based on DCWT formulation, not working well in practice.

function fBm_bspline_covmat_lag(H::Real, v::Int, l::Int, sclrng::AbstractVector{Int}, mode::Symbol)
    return Amat_bspline(H, v, l, sclrng) .* [sqrt(i*j) for i in sclrng, j in sclrng].^(2H+1)
end


"""
Compute the covariance matrix of B-Spline DCWT coefficients of a pure fBm.

The full covariance matrix of `J`-scale transform and of time-lag `N` is a N*J-by-N*J symmetric matrix.

# Args
- l: maximum time-lag
- sclrng: scale range
- v: vanishing moments of B-Spline wavelet
- H: Hurst exponent
- mode: mode of convolution
"""
function fBm_bspline_covmat(l::Int, sclrng::AbstractVector{Int}, v::Int, H::Real, mode::Symbol)
    J = length(sclrng)
    Σ = zeros(((l+1)*J, (l+1)*J))
    Σs = [fBm_bspline_covmat_lag(H, v, d, sclrng, mode) for d = 0:l]

    for r = 0:l
        for c = 0:l
            Σ[(r*J+1):(r*J+J), (c*J+1):(c*J+J)] = (c>=r) ? Σs[c-r+1] : transpose(Σs[r-c+1])
        end
    end

    return Matrix(Symmetric(Σ))  #  forcing symmetry
    # return [(c>=r) ? Σs[c-r+1] : Σs[r-c+1]' for r=0:N-1, c=0:N-1]
end


"""
Evaluate the log-likelihood of B-Spline DCWT coefficients.
"""
function fBm_bspline_log_likelihood_H(X::AbstractVecOrMat{T}, sclrng::AbstractVector{Int}, v::Int, H::Real, mode::Symbol) where {T<:Real}
    @assert 0 < H < 1
    @assert size(X,1) % length(sclrng) == 0

    L = size(X,1) ÷ length(sclrng)  # integer division: \div
    # N = ndims(X)>1 ? size(X,2) : 1

    Σ = fBm_bspline_covmat(L-1, sclrng, v, H, mode)  # full covariance matrix

    # # strangely, the following does not work (logarithm of a negative value)
    # iΣ = pinv(Σ)  # regularization by pseudo-inverse
    # return -1/2 * (J*N*log(trace(X'*iΣ*X)) + logdet(Σ))

    return log_likelihood_H(Σ, X)
end


"""
B-Spline wavelet-MLE estimator.
"""
function fBm_bspline_DCWT_MLE_estim(X::AbstractVecOrMat{T}, sclrng::AbstractVector{Int}, v::Int, mode::Symbol; method::Symbol=:optim, ε::Real=1e-2) where {T<:Real}
    @assert size(X,1) % length(sclrng) == 0
    # number of wavelet coefficient vectors concatenated into one column of X
    L = size(X,1) ÷ length(sclrng)  # integer division: \div
    # N = ndims(X)>1 ? size(X,2) : 1

    func = x -> -fBm_bspline_log_likelihood_H(X, sclrng, v, x, mode)

    opm = nothing
    hurst = nothing

    if method == :optim
        # Gradient-free constrained optimization
        opm = Optim.optimize(func, ε, 1-ε, Optim.Brent())
        # # Gradient-based optimization
        # optimizer = Optim.GradientDescent()  # e.g. Optim.BFGS(), Optim.GradientDescent()
        # opm = Optim.optimize(func, ε, 1-ε, [0.5], Optim.Fminbox(optimizer))
        hurst = Optim.minimizer(opm)[1]
    elseif method == :table
        Hs = collect(ε:ε:1-ε)
        hurst = Hs[argmin([func(h) for h in Hs])]
    else
        throw("Unknown method: ", method)
    end

    Σ = fBm_bspline_covmat(L-1, sclrng, v, hurst, mode)
    σ = sqrt(xiAx(Σ, X) / length(X))

    return (hurst, σ), opm
end
