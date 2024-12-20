
W = 400; H= 400;

function drawArc2PntAngle(p1::Point, p2::Point, angle::Float64)
    midpoint = 0.5 * (p1 + p2)

    dist = mag(p2 - p1)

    radius = dist / (2 * sin(angle / 2))

    dist_to_center = sqrt(radius^2 - (dist / 2)^2)

    direction = (p2 - p1) / dist
    direction = Point(-direction.y, direction.x)

    center = midpoint + dist_to_center * direction

    angle1 = mod(atan(p1.y - center.y, p1.x - center.x),2π)
    # angle2 = atan(p2.y - center.y, p2.x - center.x)

    return center, radius, angle1
end

function drawPopulation(pop::Population,position;radiusScale = 15)
    maxRadius = sqrt(pop.size)*radiusScale

    Luxor.translate(position)
    Luxor.rotate(-π/2)
    sAngle = pop.S * 2 * π #cw
    iAngle = pop.I * 2 * π
    
    setcolor("black")
    pop.index==1 && circle(O,maxRadius*1.35, :fill)
    setcolor("blue")
    sector(O, 0, maxRadius, 0, sAngle, :fill)
    setcolor("red")
    sector(O, 0, maxRadius, sAngle, sAngle + iAngle, :fill)
    setcolor("green")
    (sAngle + iAngle < 2π) && sector(O, 0, maxRadius, sAngle + iAngle, 2 * π, :fill)
        
    # function drawDisk(radius, color)
    #     setcolor(color)
    #     frac_radius = maxRadius * sqrt(radius)
    #     circle(O, frac_radius, :fill)
    # end
    
    # fractions = [(s_fraction, "green"), (i_fraction, "red"), (r_fraction, "blue")]
    # cumuFrac = 1
    # for (fraction, color) in fractions
    #     drawDisk(cumuFrac, color)
    #     cumuFrac -= fraction
    # end

    origin()
end

function drawConnection(i,j,populations; PNG = false)
    if (j>i)
        startInd, endInd = (j,i)
    else
        startInd, endInd = (i,j)
    end
    nPopulations = length(populations)
    r = W/2 - 30
    theta_i = 2*π/nPopulations * (i-1)
    theta_j = 2*π/nPopulations * (j-1)
    position_i = Point(r*cos(theta_i), r*sin(theta_i))
    position_j = Point(r*cos(theta_j), r*sin(theta_j))
   

    angle = 2*π/nPopulations
    if (angle>π)
        # angle = 2π-angle
        # print(angle)
        startInd, endInd = (endInd,startInd)
    end
    infFrac1 = populations[startInd].I
    infFrac2 = populations[endInd].I  
    mobRestriction1 = populations[startInd].ρs[endInd]
    mobRestriction2 = populations[endInd].ρs[startInd]
    nSegs = 20
    flip = xor(i>j,mod(i-j,nPopulations)>nPopulations/2)
    (position_1,position_2) = flip ? (position_i,position_j) : (position_j,position_i)
    center, radius, angle1 = drawArc2PntAngle(position_1,position_2, angle)

    
    # lineStep = (populations[j].position-populations[i].position)/nSegs
    angleStep = angle/nSegs
    for k in 1:nSegs
        x = (k-1)/nSegs
        redness = infFrac1*(1-x) + infFrac2*x
        # transparency = max(mobRate1*(1-x)^2, mobRate2*(x)^2) * abs(nSegs*.5-k)/nSegs*4
        transparency::Float64 = parabolaS0(x,1-mobRestriction1,1-mobRestriction2)
        if (PNG)
            setcolor(0,0,0)
        else
            setcolor(1-(1-redness)^1.1,0,0,transparency)
        end
        # @show angle1+angleStep*k angle1
        # if mod(angle1+angleStep*k,2π)>angle1
            arc(center,radius,angle1+angleStep*(k-1),angle1+angleStep*k,:stroke)
        # end
        # arc(center,radius,angle1+angleStep*(k-1),angle1+angleStep*k,:stroke)
        # line(populations[i].position+lineStep*(k-1), populations[i].position+lineStep*k,:stroke)
    end
end

function drawConnections(populations,connections;PNG = false)
    setline(2) # Set line width
    sethue("black") # Set line color
    nPopulations = length(populations)
    for i in 1:nPopulations
        for j in 1:i
            if connections[i,j] == 1
                drawConnection(i,j,populations; PNG = PNG)
            end
        end
    end
end

function drawNetwork(populations,connections)
    background("white")
    origin()
    drawConnections(populations,connections)
    nPopulations = length(populations)
    r = W/2 - 30
    for pop in populations
        theta = 2*π/nPopulations * (pop.index-1)
        position = Point(r*cos(theta), r*sin(theta))
        drawPopulation(pop,position)
    end
    finish()
end

function frame(scene::Scene, framenumber::Int, populations,infectedHistory, susceptibleHistory, recoveredHistory, ρsHistory,connections)
    # locally available variables: populations,connections,infectedHistory, ρsHistory
    # create `populationsSnapshot` based on framenumber
    populationsSnapshot = deepcopy(populations)
    for population in populationsSnapshot
        population.I = infectedHistory[framenumber, population.index]
        population.S = susceptibleHistory[framenumber, population.index]
        population.R = recoveredHistory[framenumber, population.index]
        population.ρs = ρsHistory[framenumber, population.index, :]
    end

    drawNetwork(populationsSnapshot,connections)
end


# function drawNetworkPNG(populations,connections,infectedHistory, susceptibleHistory,ρsHistory;filename = "MetaPopNet.png")
#     @png begin
#         background("white")
#         origin()
#         drawConnections(populations,connections;PNG = true)
#         for pop in populations
#             drawPopulationHistory(pop, susceptibleHistory[:,pop.index], infectedHistory[:,pop.index])
#         end
#         finish()
#     end 400 400 filename
#     return filename
# end

function drawNetworkKarnak(meta, data; filename = "Network.png")
    spreadTimes = data["spreadInfInd"].-1 # if time=-1 means not found
    peakTimes = data["peakInfInd"].-data["peakInfInd"][1]
    g = meta.S.net.graph
    @png begin
        background("white")
        sethue("black")

        drawgraph(g, layout=spring,
            vertexshapesizes = 20,
            margin=40,
            vertexlabels = (vtx) -> string(Int(round(peakTimes[vtx]))),
            vertexlabelfontsizes = 20,
            vertexstrokecolors = (vtx) -> vtx==1 ? colorant"red" : colorant"black", 
            vertexstrokeweights = (vtx) -> vtx==1 ? 5 : 1  
        )
    end 1000 1000 filename
    return filename
end
function animate_network(populations,connections,infectedHistory, susceptibleHistory, recoveredHistory, ρsHistory;filename = "preview.gif")
    nFrames = size(infectedHistory,1)
    mymovie=Movie(W,H,"test",1:nFrames)
    Luxor.animate(mymovie,[Scene(mymovie,(s, f) -> frame(s, f, populations,infectedHistory, susceptibleHistory, recoveredHistory, ρsHistory,connections),1:nFrames)],creategif=true, framerate=2,pathname=filename)
end