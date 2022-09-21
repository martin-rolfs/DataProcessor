module DataProcessor

using StructArrays
using LinearAlgebra
using ProgressMeter
using Random

include("Structs.jl")

export loadDataToStack
"""
Loads a new JSOn File in RAM as Struct Array from PositionalData.

# Arguments
- `path::String`: The path to the .json file where the data is stored. 
- `numberOfLoops::Int`: The number of loops the robot made in this data set. 

# Optional Arguments
- `rotateCameraCoords::Bool`: Rotate the camera position so it fits onto prediction.
- `pathPosTracking::String`: The path to the .json file containing the correct positional information for the data.
"""
function loadDataToStack(path::String, numberOfLoops::Int; rotateCameraCoords::Bool=true, pathPosTracking::String="")
    posData = loadFromJSon(rotateCameraCoords, path);
    if length(posData) == 0
        @warn "No data was added to the stack."
        return
    end

    push!(trainData, (numberOfLoops, posData, cmp(pathPosTracking, String("")) == 0 ? nothing : loadFromJSon(pathPosTracking)));
end

export getLength
getLength() = @info "Length of stack: " * string(length(trainData))

export addInitialParameter
"""
This method adds Parameters to a list used for random restart. If no argument is given the parameters will be randomly generated.

# Optional Argument
- `param::Union{String, PredictionParameters}`: The Parameters can be directly provided or the path to the JSON file containing the information.
"""
function addInitialParameter(;param::Union{String, PredictionParameters}=".")
    if param isa String
        if param != "."
            push!(initialParameters, loadParamsFromJSon(param))
            return
        end
    else
        push!(initialParameters, param)
        return
    end

    # Add random parameter
    push!(initialParameters, PredictionParameters(bitrand(1)[1], 
                                                  bitrand(1)[1], 
                                                  rand(Float32, 1)[1]*10, 
                                                  bitrand(1)[1], 
                                                  rand(Float32, 1)[1]*10, 
                                                  bitrand(1)[1], 
                                                  rand(Float32, 1)[1]*0.3, 
                                                  rand(Float32, 1)[1], 
                                                  rand(Float32, 1)[1]+0.01, 
                                                  rand(Float32, 1)[1], 
                                                  rand(Float32, 1)[1]*0.3+0.1, 
                                                  rand(Float32, 1)[1]*100, 
                                                  rand(Float32, 1)[1]*0.3+0.1, 
                                                  rand(Float32, 1)[1]*100, 
                                                  rand(Float32, 1)[1], 
                                                  bitrand(1)[1]))
end


export train
"""
This function executes the hillclimbing itself. The data to train with should be given in `trainData`. 

# Optional Arguments
- `maxIterations::Integer`: The maximum iterations after which the algorithm terminates.
- `minError::Float64`: The minimum error to achieve if the maximum iterations were not exceded.
- `maxIterChangeParams`: How many iterations should be looked for better parameters. If greater, greater deviation in parameters from initial parameter possible. 
- `saveAsFile::Bool`: If resulting parameters should be saved as a JSON file.
- `randomRestart::Bool`: Restart algorithm with initial parameters provided in `initialParameters`.
"""
function train(;maxIterations::Integer=1000, minError::Float64=1.0, maxIterChangeParams=100, saveAsFile::Bool=false, randomRestart::Bool=false, rri::Integer=1)
    len = length(trainData)
    len == 0 && throw(ArgumentError("No data was added to the stack! Cannot train."))
    (randomRestart && length(initialParameters) == 0) && throw(ArgumentError("For random restart to work, initial parameters must be provided using `addInitialParameter`."))

    # Starting Parameters
    params = randomRestart ? initialParameters[rri] : PredictionParameters()
    @info "Training with $(len) data points..."
    @info "Start parameter: $(params)"
    
    # Error with starting parameters
    meanError = calculateError(trainData, params)
    @info "Error of starting params: $(meanError)"

    i = 0
    prog = Progress(maxIterations, 1, "Training...", 50)

    while meanError > minError && i < maxIterations
        inner_i = 0
        while true 
            P = getNewParams(params)
            newMeanError = Inf64

            for p ∈ P
                #@info "Current Params: $(p)."
                e = calculateError(trainData, p)

                # if new error is smaller take parameter
                if e < newMeanError
                    newMeanError = e
                    params = p
                end
            end
            inner_i += 1

            # Break out of loop
            if newMeanError < meanError || inner_i == maxIterChangeParams 
                meanError = newMeanError 
                break 
            end
        end

        if inner_i == maxIterChangeParams
            println()
            @info "No better Value was found -> local minima with Parameters: $(params) with error: $(meanError)"

            if saveAsFile saveParamsJSon(params, fileName=randomRestart ? "pred_params$(rri)" : nothing) end

            return (randomRestart && length(initialParameters) > rri) ? train(maxIterations=maxIterations, minError=minError, maxIterChangeParams=maxIterChangeParams, saveAsFile=saveAsFile, randomRestart=true, rri=rri+1) : params
        end

        i += 1
        next!(prog)
    end

    println()
    @info "Training finished with mean error: $(meanError) and Parameters: $(params)"

    if saveAsFile saveParamsJSon(params, fileName=randomRestart ? "pred_params$(rri)" : nothing) end    

    return (randomRestart && length(initialParameters) > rri) ? train(maxIterations=maxIterations, minError=minError, maxIterChangeParams=maxIterChangeParams, saveAsFile=saveAsFile, randomRestart=true, rri=rri+1) : params
end


#helper function
function transformVecToString(v::Vector{T}) where T <: Number
    s = String("")
    for n ∈ v s = s*string(n)*" " end
    return s
end
export saveDataToFile
function saveDataToFile(data::Union{StructArray, Matrix}, filename::String)
    if data isa Matrix
        @info "Save positional [x, y, z] data in file."

        open(filename*".data", "w") do io 
            println(size(data)[2])
            for i ∈ 1:size(data)[2]
                write(io, string(data[1, i])*" "*string(data[2, i])*" "*string(data[3, i])*"\n");
            end
        end;
    elseif data isa StructArray
        @info "Save sensor data from struct in file."

        open(filename*".data", "w") do io             
            for i ∈ 1:length(data)
                s = String("")

                newData = data[i]

                s = s*string(newData.steerAngle)*" "
                s = s*string(newData.sensorAngle)*" "
                s = s*string(newData.maxSpeed)*" "
                s = s*string(newData.sensorSpeed)*" "
                s = s*transformVecToString(newData.cameraPos)
                s = s*transformVecToString(newData.cameraOri)
                s = s*transformVecToString(newData.imuGyro)
                s = s*transformVecToString(newData.imuAcc)
                s = s*transformVecToString(newData.imuMag)
                s = s*string(newData.deltaTime)*" "
                s = s*string(newData.cameraConfidence)

                write(io, s*"\n");
            end
        end;
    else
        @warn "Data given is not supported!"
        return
    end    
end

include("Sensorfusion.jl")
include("HillClimbing.jl")
include("DataExtractor.jl")
trainData = Vector{Tuple{Int64, typeof(StructArray(PositionalData[])), Union{Nothing, Matrix{Float32}}}}(undef, 0);
initialParameters = Vector{PredictionParameters}(undef, 0);

end # module
