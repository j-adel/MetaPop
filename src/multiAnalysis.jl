@enum Param begin
    βParam
    μParam
    λParam
end

struct SArray
    params::Array{Param, 1}
    size::Array{Int, 1}
    ranges::Array{Tuple{Float64, Float64}, 1}
end

function multiScenario(S, param_names, param_ranges)
    nPts = length(param_ranges[1])
    dims = length(param_names)
    Ss = Array{Scenario, dims}(undef, (nPts for _ in 1:dims)...)
    
    indices = [1 for _ in 1:dims]
    while true
        epi = deepcopy(S.epi)
        strat = deepcopy(S.strat)
        
        for (k, param_name) in enumerate(param_names)
            if param_name == :βParam
                epi.β = param_ranges[k][indices[k]]
            elseif param_name == :μParam
                epi.μ = param_ranges[k][indices[k]]
            elseif param_name == :λParam
                strat.λ = param_ranges[k][indices[k]]
            end
        end
        
        new_S = deepcopy(S)
        new_S.epi = epi
        new_S.strat = strat
        
        Ss[indices...] = new_S
        
        for k in 1:dims
            indices[k] += 1
            if indices[k] <= nPts
                break
            elseif k == dims
                return Ss
            else
                indices[k] = 1
            end
        end
    end
end

function multiScenario_μβ(S)
    nPtsX=nPtsY=5
    βs=range(0.2,1,nPtsX)
    μs=range(0.01,0.1,nPtsY)
    Ss=Array{Scenario,2}(undef,nPtsX,nPtsY)
    for i in 1:nPtsX
        for j in 1:nPtsY
            epi=deepcopy(S.epi)
            epi.μ=μs[i]
            epi.β=βs[j]
            Ss[i,j]=deepcopy(S)
            Ss[i,j].epi=epi
        end
    end
    return Ss
end

function multiScenario_λ(S)
    nPtsX=9
    λs= 10 .^(range(0,(nPtsX-1)*2,nPtsX))
    Ss=Array{Scenario,1}(undef,nPtsX)
    for i in 1:nPtsX
        strat=deepcopy(S.strat)
        strat.λ=λs[i]
        Ss[i]=deepcopy(S)
        Ss[i].strat=strat
    end
    return Ss
end

function multiScenario_1D(S)
    nPtsX=20
    Ss=Array{Scenario,1}(undef,nPtsX)
    for i in 1:nPtsX
        Ss[i]=deepcopy(S)
    end
    return Ss
end


function multiScenario_strategies(S)
    Ss=Array{Scenario,1}(undef,5)
    for i in 1:nPtsX
        Ss[i]=deepcopy(S)
    end
    Ss[1].strat = Strat(λ = 0, mobBias = 0.0,strategy = GlobalDiffRestriction)
    Ss[2].strat = Strat(λ = 1e7, mobBias = 0.0,strategy = GlobalDiffRestriction)
    Ss[3].strat = Strat(λ = 1e7, mobBias = 0.0,strategy = UniformPropRestriction)
    Ss[4].strat = Strat(λ = 1e7, mobBias = 0.0,strategy = IndivPropRestriction)
    Ss[5].strat = Strat(λ = 1e-1, mobBias = 0.0,strategy = IndivLogRestriction)
    return Ss
end

