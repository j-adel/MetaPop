function combinePlots(plots)
    gr()
    # Calculate the total height
    height = sum(p[2] for p in plots)
    
    # Extract the heights for the layout
    layout_heights = [p[2] for p in plots]./height
    layout_heights[end]=1-sum(layout_heights[1:end-1])
    
    l = Plots.grid(length(plots), 1, heights=layout_heights)
    combined_plot = plot([p[1] for p in plots]..., layout=l, size=(1000, height))
    return combined_plot
end

function plotCase(data,S;img_filename)
    plots = []
    push!(plots, plotInfEvolution(data))
    push!(plots, plotInfEvolution(data,log_scale=true))
    push!(plots, plotRestrictions(data))
    push!(plots, plotInfectedFlow(data))
    # push!(plots, plotAvgRestrictions(data["ρsAvgHistory"]))    
    push!(plots, plotInfectionDays(data,S.epi))
    push!(plots, plotSpreadRates(data))
    # push!(plots, plot_cumulative_flow(data))
    # push!(plots, plot_consecutive_infected(data["infectedHistory"],log_scale=false))
    push!(plots, plot_infect_ρ(data["infectedHistory"],data["ρsHistory"]))
    push!(plots, plot_infect_flow(data["infectedHistory"],data["downstream_flows"]))
    # push!(plots, plotRestrictionsGrid(data["ρsHistory"]))

    # Load the image and add it to the plots
    if img_filename != ""
        img = load(img_filename)
        img_plot = plot(img, seriestype=:image)
        push!(plots, (img_plot,800))
    end
    return combinePlots(plots)
end

function plotEnsemble(datas,Ss)
    plots = []
    push!(plots, plot_lambda_spread_rate(datas,Ss))
    push!(plots, plot_lambda_spread_rates(datas,Ss))
    

    return combinePlots(plots)
end

# TODO create a function that unifies the functionality of all these functions
function plotInfEvolution(data; log_scale::Bool=false)
    xAxis = data["days"]
    timeseries,avg_infected_percent = data["infectedHistory"],data["infectedAvgHistory"]
    nTimeSteps, nPopulations = size(timeseries)

    infected_percent = timeseries 
    colors = palette(:jet, nPopulations)
    startInd = log_scale ? 2 : 1
    color_index = 1
    p = plot()
    for i in 1:nPopulations
        plot!(p,xAxis[startInd:nTimeSteps], infected_percent[startInd:end, i], label="Pop. $i", color=colors[color_index])
        color_index += 1
    end
    !log_scale && plot!(p, xAxis[startInd:nTimeSteps], avg_infected_percent[startInd:end], label="Average",
     linestyle=:dash, linewidth=2, legendfontsize=6, legend=false)
    log_scale && plot!(p, yscale=:log10)
    xlabel!(p,"Time (days)")
    ylabel!(p,"Infected Population Fraction")
    title!(p, "Prevalence of Infected" * (log_scale ? " (Log Scale)" : ""))
    return p, 400
end


function plotRestrictions(data)
    xAxis = data["days"]
    nTimeSteps, nρs= size(data["downstream_ρs"])
    p = plot(legend=false)
    
    colors = palette(:jet, nρs)
    
    color_index = 1
    for i in 1:nρs
            plot!(p, xAxis, data["downstream_ρs"][:,i] , label="P($i,$(i+1))", color=colors[color_index], ylim=(0,1))
            color_index += 1
    end
    
    xlabel!(p, "Time (days)")
    ylabel!(p, "Mobility Restrictions")
    title!(p, "Evolution of Path Mobility Restrictions")
    return p, 400
end

function plotInfectedFlow(data)
    xAxis = data["days"]
    downstream_flows = data["downstream_flows"]
    nTimeSteps, nFlows = size(downstream_flows)
    p = plot(legend=false)
    
    colors = palette(:jet, nFlows)
    cleanDownstreamFlows = replace(x -> x <= 0 ? NaN : x, downstream_flows)

    color_index = 1
    for i in 1:nFlows
        plot!(p, xAxis, cleanDownstreamFlows[:,i], label="Flow($i,$(i+1))", color=colors[color_index],yscale=:log10)
        color_index += 1
    end
    
    xlabel!(p, "Time (days)")
    ylabel!(p, "Infected Flow")
    title!(p, "Evolution of Infected Flow")
    return p, 400
end


function plotAvgRestrictions(ρsAvgHistory)
    
    nTimeSteps, nPopulations = size(ρsAvgHistory)
    p = plot(1:nTimeSteps, zeros(nTimeSteps), label="P1", legend=false)
    
    colors = palette(:jet, nPopulations)
    
    color_index = 1
    for i in 1:nPopulations
        plot!(p, 1:nTimeSteps, ρsAvgHistory[:, i], label="P($i)", color=colors[color_index], ylim=(0,1))
        color_index += 1
    end
    
    xlabel!(p, "Time (days)")
    ylabel!(p, "Mobility Restrictions")
    title!(p, "Evolution of Mobility Restrictions")
    return p, 600
end

function plotRestrictionsGrid(ρsHistory)
    
    nTimeSteps, nPopulations, _ = size(ρsHistory)
    layout = @layout [Plots.grid(nPopulations, nPopulations)]
    p = plot(layout=layout, size=(800, 800), framestyle=:none, ticks=nothing,legend=false)
    
    for i in 1:nPopulations
        for j in 1:nPopulations
            plot!(p, 1:nTimeSteps, ρsHistory[:, i, j], label="", subplot=(i-1)*nPopulations + j,ylim=(0,1))
        end
    end
    
    return p, 800
end

function plotInfectionDays(data,epi)
    pathLengths = data["pathLengths"]
    spreadInfInd = data["spreadInfInd"]

    # Create a scatter plot
    p = scatter(pathLengths, spreadInfInd, label="Spread Infection Day",
                xlabel="Path Length", ylabel="Indices", size=(1000,800),
                legendfontsize=15, tickfontsize=15, guidefontsize=15, left_margin=10Plots.mm,
                mc=:blue)
    
    epi.γ>0 && scatter!(p, pathLengths, data["peakInfInd"], label="Peak Infection Day", mc=:red)
    scatter!(p, pathLengths, data["firstOrderSol"], label="First Order Sol.", mc=:yellow)
    plot!(p, pathLengths, data["firstOrderApprox"], label="First Order Approx.", mc=:white)
    
    return p, 800
end

function plotSpreadRates(data)
    pathLengths = data["pathLengths"]
    spreadInfInd = data["spreadInfInd"]

    # Calculate the inverse of the difference of the number of days between consecutive nodes
    inv_diff_days = 1.0 ./ (spreadInfInd[2:end] .- spreadInfInd[1:end-1])
    inv_diff_firstOrderSol = 1.0 ./ (data["firstOrderSol"][2:end] .- data["firstOrderSol"][1:end-1])
    inv_diff_firstOrderApprox = 1.0 ./ (data["firstOrderApprox"][2:end] .- data["firstOrderApprox"][1:end-1])
    
    # Create a scatter plot
    p = scatter(pathLengths, data["1/Δt"], label="1/Δt",
                xlabel="Path Length", ylabel="Inverse Δt", size=(1000,800),
                legendfontsize=15, tickfontsize=15, guidefontsize=15, left_margin=10Plots.mm,
                mc=:blue)
    scatter!(p, pathLengths[2:end], inv_diff_firstOrderSol, label="First Order Sol.", mc=:yellow)
    plot!(p, pathLengths[2:end], inv_diff_firstOrderApprox, label="First Order Approx.")
    # make y-axis start from 0
    plot!(p, ylims=(0, maximum(inv_diff_days)*1.1))
    
    return p, 800
end


function plot_cumulative_flow(data::Dict)
    cumuInfMob =[data["cumuInfMob"][i, i+1] for i in 1:size(data["cumuInfMob"], 1)-1]
    nPopulations = length(cumuInfMob)
    p = scatter(1:nPopulations-1, cumuInfMob, legend=false, yscale=:log10)
    plot!(p, xlims=(0, nPopulations))
    xlabel!(p, "Path length")
    ylabel!(p, "Cumulative Infected Flow")
    title!(p, "Cumulative Infected Flow")
    return p, 800
end


function plot_multi_spread_rates(datas::Array{Dict, 2},Ss)
    nRows, nCols = size(datas)
    
    # Initialize arrays to store the values
    referenceSpreadRates = [[] for _ in 1:nCols]
    firstOrderSolSpreadRates = [[] for _ in 1:nCols]
    firstOrderApproxSpreadRates = [[] for _ in 1:nCols]
    spreadRates = [[] for _ in 1:nCols]
    βs=[]
    μs=[]
    
    # Extract values from each dictionary in the 2D array
    for i in 1:nRows
        for j in 1:nCols
            push!(referenceSpreadRates[j], datas[i, j]["referenceSpreadRate"])
            push!(firstOrderSolSpreadRates[j], datas[i, j]["firstOrderSolSpreadRate"])
            push!(firstOrderApproxSpreadRates[j], 1 ./firstOrderApprox(Ss[i,j].epi))
            push!(spreadRates[j], datas[i, j]["avgSpreadRate"])
            i==1 && push!(βs,Ss[1,j].epi.β)
        end
        push!(μs,Ss[i,1].epi.μ) 
    end
    @show βs μs
    # Create the plot
    p = plot(xlabel="μ", ylabel="Rate (nodes/day)", title="Spread Rates")
    
    for j in 1:nCols
        plot!(p, μs, spreadRates[j], label="Actual Rate (β= $(βs[j]))", lw=2, lc=:green, legendfontsize=6)
        # scatter!(p, μs, referenceSpreadRates[j], label="Ref Rate (β= $(βs[j]))", lw=2, mc=:black)
        plot!(p, μs, firstOrderSolSpreadRates[j], label="My Rate (β= $(βs[j]))", lw=2, lc=:red)
        # scatter!(p, μs, firstOrderSolSpreadRates[j], label="My Rate (β= $(βs[j]))", lw=2, mc=:red)
        # plot!(p, μs, firstOrderApproxSpreadRates[j], label="Approx Rate (β= $(βs[j]))", lw=2, lc=:blue)
        scatter!(p, μs, firstOrderApproxSpreadRates[j], label="Approx Rate (β= $(βs[j]))", lw=2, mc=:blue)
    end
    
    return p, 800
end

function plot_lambda_spread_rate(datas::Array{Dict, 1}, Ss)
    n = length(datas)
    
    # Initialize arrays to store the values
    firstOrderSolSpreadRates = []
    firstOrderApproxSpreadRates = []
    asympSpreadRates = []
    initSpreadRates = []
    avgSpreadRates = []
    λs = []
    
    # Extract values from each dictionary in the array
    for i in 1:n
        # push!(firstOrderSolSpreadRates, datas[i]["firstOrderSolSpreadRate"])
        # push!(firstOrderApproxSpreadRates, 1 ./ firstOrderApprox(Ss[i].epi))
        push!(asympSpreadRates, datas[i]["asympSpreadRate"])
        push!(initSpreadRates, datas[i]["initSpreadRate"])
        push!(avgSpreadRates, datas[i]["avgSpreadRate"])

        push!(λs, Ss[i].strat.λ)
    end
    
    @show λs 
    # Create the plot
    p = plot(xlabel="λ", ylabel="Rate (nodes/day)", title="Spread Rates", ylims=(0,.2), xscale=:log10)
    plot!(p, λs, asympSpreadRates, label="Asymptotic Spread Rate", lw=2, lc=:green, legendfontsize=6)
    plot!(p, λs, initSpreadRates, label="Initial Spread Rate", lw=2, lc=:blue, legendfontsize=6)
    plot!(p, λs, avgSpreadRates, label="Average Spread Rate", lw=2, lc=:red, legendfontsize=6)

    # plot!(p, λs, firstOrderSolSpreadRates, label="My Rate", lw=2, lc=:red)
    # scatter!(p, λs, firstOrderApproxSpreadRates, label="Approx Rate", lw=2, mc=:blue)

    
    
    return p, 800
end

function plot_lambda_spread_rates(datas::Array{Dict, 1}, Ss)
    n = length(datas)
    
    λs = []
    spreadRates = []
    
    # Extract values from each dictionary in the array
    for i in 1:n
        push!(spreadRates,datas[i]["1/Δt"])
        push!(λs, Ss[i].strat.λ)
    end

    
    pathLengths = datas[1]["pathLengths"]

    p=plot(xlabel="Path Length", ylabel="Inverse Δt", size=(1000,800),
    legendfontsize=15, tickfontsize=15, guidefontsize=15)
    for i in 1:n
        plot!(p, pathLengths[2:end], spreadRates[i][2:end], label="λ=$(λs[i])", mc=:yellow)
    end
    plot!(p, ylims=(0, .2))

    return p, 800
end


function plot_consecutive_infected(infectedHistory::Array{Float64,2}; log_scale::Bool=false)
    
    nTimeSteps, nPopulations = size(infectedHistory)
    p = plot()
    colors = palette(:jet, nPopulations)
    color_index = 1
    for i in 1:nPopulations-1
        phase_shift = (i - 1)/nPopulations  # Adjust phase shift as needed
        plot!(p, infectedHistory[2:end,i], infectedHistory[2:end,i+1], label = "($i,$(i+1))", color = colors[color_index], linestyle=:dash, phase=phase_shift)
        color_index += 1
    end
    xlabel!(p, "Population i infected prevalence")
    ylabel!(p, "Population i+1 infected prevalence")
    title!(p, "Consecutive Infecteds prevalence" * (log_scale ? " (Log Scale)" : ""))
    
    if log_scale
        plot!(p,xscale=:ln,yscale=:ln)
    end
    
    return p, 800
end

function plot_infect_ρ(infectedHistory::Array{Float64,2}, ρsHistory::Array{Float64,3})
    
    nTimeSteps, nPopulations = size(infectedHistory)
    p = plot()
    colors = palette(:jet, nPopulations)
    color_index = 1
    cleanInfectedHistory = replace(x -> x <= 0 ? NaN : x,infectedHistory)
    cleanρsHistory = replace(x -> x <= 0 ? NaN : x, ρsHistory)
    for i in 1:nPopulations-1
        plot!(p, cleanInfectedHistory[2:end,i], cleanρsHistory[2:end,i+1,i], label = "($i,$(i+1))", color=colors[color_index], xscale=:log10)
        color_index += 1
    end
    plot!(p,legend=false)
    xlabel!(p, "Population i infected prevalence")
    ylabel!(p, "Population i+1 infected prevalence")
    title!(p, "Evolution of infected flow and ρ")
    return p, 800
end

function plot_infect_flow(infectedHistory, downstream_flows)
    nTimeSteps, nPopulations = size(infectedHistory)
    p = plot()
    colors = palette(:jet, nPopulations)
    cleanInfectedHistory = replace(x -> x <= 0 ? NaN : x, infectedHistory)
    cleanDownstreamFlows = replace(x -> x <= 0 ? NaN : x, downstream_flows)
    color_index = 1
    for i in 1:nPopulations-1
        plot!(p,  cleanDownstreamFlows[2:end, i],infectedHistory[2:end, i+1], label = "($i,$(i+1))", color=colors[color_index], xscale=:log10,yscale=:log10)
        color_index += 1
    end
    
    plot!(p, legend=false)
    ylabel!(p, "Population i infected prevalence")
    xlabel!(p, "Population i+1 infected flow rate")
    title!(p, "Evolution of infected flow rate")
    return p, 800
end