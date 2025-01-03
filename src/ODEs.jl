# using DifferentialEquations
using Plots

function f(du, u, p, t)
    μ = 0.02
    β = 0.25
    λ = 1e10

    # Initialize du to match the structure of u
    du .= 0.0

    du[1] = β * u[1] * (1 - u[1]) + 2μ * u[10] * (u[2] - u[1])
    for i in 2:4
        du[i] = β * u[i] * (1 - u[i]) + μ * u[4 + i] * (u[i-1] - u[i]) + μ * u[9 + i] * (u[i+1] - u[i])
    end
    du[5] = β * u[5] * (1 - u[5]) + μ * u[9] * (u[4] - u[5])

    for i in 1:4
        du[5 + i] = -λ * μ * u[5 + i] * u[i]
    end

    for i in 1:4
        du[9 + i] = -λ * μ * u[9 + i] * u[i + 1]
    end
end

function integrate_f()
    # Initial condition as a one-dimensional array
    u0 = [1e-5, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]

    # Time span
    tspan = (0.0, 135.0)

    # Define the ODE problem
    prob = ODEProblem(f, u0, tspan)

    # Solve the ODE problem
    sol = solve(prob, Rosenbrock23(), reltol = 1e-8, abstol = 1e-8)

    # Plot the solution
    p=plot(size=(1000,450))
    for i in 1:5
        plot!(p,sol.t,[x[i] for x in sol.u[:]], linewidth =2, title = "Solution to the ODE with one-dimensional array",
            xaxis = "Time (t)", yaxis = "u(t)", label = "Solution")
    end
    plot(p)
end

# Define the SIR model differential equations
function sir_euler(S, I, R, β, γ, dt)
    dS = -β * S * I
    dI = β * S * I - γ * I
    dR = γ * I
    S_new = S + dS * dt
    I_new = I + dI * dt
    R_new = R + dR * dt
    return S_new, I_new, R_new
end

# Function to solve the SIR model using Euler integration
function solve_sir_euler(β, γ, S0, I0, R0, tspan, dt)
    t = tspan[1]:dt:tspan[2]
    S, I, R = [S0], [I0], [R0]
    for _ in t[2:end]
        S_new, I_new, R_new = sir_euler(S[end], I[end], R[end], β, γ, dt)
        push!(S, S_new)
        push!(I, I_new)
        push!(R, R_new)
    end
    return t, S, I, R
end

# Generate the phase space plot
function plot_phase_space(β, γ, tspan, S_range, I_range, dt)
    # Create a grid for the quiver plot
    S_vals = range(S_range[1], S_range[2], length=20)
    I_vals = range(I_range[1], I_range[2], length=20)
    S_grid, I_grid = [S for S in S_vals, I in I_vals], [I for S in S_vals, I in I_vals]
    dS = -β .* S_grid .* I_grid
    dI = β .* S_grid .* I_grid .- γ .* I_grid

    # Plot the quiver plot
    # quiver(S_vals, I_vals, quiver=(dS, dI), xlabel="S", ylabel="I", title="Phase Space of SIR Model")

    # Plot solutions for different initial conditions
    p=plot(xlabel="Susceptible",ylabel="Infected")
    colors = [:red, :blue, :green, :orange, :purple]
    for (idx, S0) in enumerate(0.15:0.2:0.95)
        t, S, I, R = solve_sir_euler(β, γ, S0, 1-S0, 0.0, tspan, dt)
        l=length(S)
        plot!(p, S, I, label="S₀=$(S0)", color=colors[idx])
        arrow0!(p,S[l÷8],I[l÷8],S[l÷8]-S[l÷8-1],I[l÷8]-I[l÷8-1]; as=10, la=1, lc=colors[idx])
    end
    plot!([0, 1], [1, 0], linestyle=:dash, color=:red, label="R=0",size=(500,500))

    # S0=0.95
    # t, S, I, R = solve_sir_euler(β, γ, S0, 1-S0, 0.0, tspan, dt)
    # plot(t,[S I R],label=["Susceptible" "Infected" "Recovered"],xlabel="time", ylabel="Compratment Fraction",
    #  size=(500,500),lw=3,legend=:right,ylims=(0,1))
    # # Draw the diagonal line R = 0 

end



function arrow0!(p,x, y, u, v; as=0.07, lc=:black, la=1)
    nuv = sqrt(u^2 + v^2)
    v1 = [u;v] ./ nuv  
    v2 = [-v;u] ./ nuv
    v4 = (3*v1 + v2)/3.1623  # sqrt(10) to get unit vector
    v5 = v4 - 2*(v4'*v2)*v2
    v4, v5 = as*nuv*v4, as*nuv*v5
    plot!(p,[x,x+u], [y,y+v], lc=lc,la=la,label="")
    plot!(p,[x+u,x+u-v5[1]], [y+v,y+v-v5[2]], lc=lc, la=la,label="")
    plot!(p,[x+u,x+u-v4[1]], [y+v,y+v-v4[2]], lc=lc, la=la,label="")
end


function stratQuiver(b)
    function d_rho_dt(M_I,ρ,b)
        λ = 1 
        return λ * M_I - λ*b*ρ^2
        
        # return λ * M_I  - λ * M_I* ρ - λ*b*ρ

        # return λ * (M_I  - ( M_I + b)* ρ)
    end
    function d_M_dt(ρ, d_rho_dt, Id_j)
        return -2 * (1 - ρ) * d_rho_dt * Id_j
    end
    
    # Create grid matrices for M and ρ
    M_grid = repeat(range(0, 1, length=10)', 10, 1)
    ρ_grid = repeat(range(0, 1, length=10), 1, 10)

    # Initialize arrays to store the rate of change
    d_rho = zeros(size(ρ_grid))
    d_M = zeros(size(M_grid))

    # Compute the rate of change for each pair of ρ and M
    p = plot(label="", ylabel="M", xlabel="ρ", xlims=(0, 1), ylims=(0, 1),size=(600,400))

    for i in 1:size(ρ_grid, 1)
        for j in 1:size(ρ_grid, 2)
            ρ = ρ_grid[i, j]
            M = M_grid[i, j]
            d_rho[i, j] = d_rho_dt(M,ρ,b)
            d_M[i, j] = d_M_dt(ρ, d_rho[i, j], 1)
            arrow0!(p,ρ_grid[i, j], M_grid[i, j], .13d_rho[i, j], .13d_M[i, j]; as=0.1, lc=:blue, la=1)
        end
    end
    t0 = 0.0
    t_end = 100.0
    dt = 0.1
    t_span = t0:dt:t_end

    # Compute trajectories starting from ρ=0 and M in range(0,1,10)
    
    for D in range(0, 1, length=10)
        ρ = 0.0
        M = D
        ρ_values = Float64[]
        M_values = Float64[]
        for t in t_span
            push!(ρ_values, ρ)
            push!(M_values, M)
            dρ = d_rho_dt(M, ρ,b)
            ρ += dρ * dt
            M =(1-ρ)^2*D
        end
        # push!(ss_values,b*ρ/(1-ρ))

        # plot!(ρ_values,M_values, lw=1, label="", c=:red)
        # plot!(t_span,ρ_values, c=:red, label="")
        # plot!(t_span,M_values, c=:blue, label="")
        
    end
    ss_values = [b*ρ^2 for ρ in range(0,1,100)]
    plot!(range(0,1,100),ss_values,style=:dash,c=:red,label="")
    # plot!(t_span,ρ_values, c=:red, label="ρ")
    # plot!(t_span,M_values, c=:blue, label="M")


    display(p)
    # quiver(M_grid, ρ_grid, quiver=(d_M, d_rho), xlabel="M", ylabel="ρ", title="Quiver Plot of ρ and M")
end
println("Hello!")
# stratQuiver(1)
plot_phase_space(0.25, 0.07, (0.0, 100.0), (0.0, 1.0), (0.0, 1.0), 0.1)

