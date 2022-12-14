"""
This function calculates the errors on positional data and returns the mean error value.

# Arguments 
- `trainData::ComplicatedType`: The global train data.
- `params::PredictionParameters`: The parameters to use when calculating the error.
- `checkLoops::Bool`: Check if an unrealistic amount of loops were estimated with given parameters. 
# Returns 
- `Float64`: The error arising from the train data with given parameters. 
"""
function calculateError(trainData::Vector{Tuple{Int64, typeof(StructArray(PositionalData[])), Union{Nothing, Matrix{Float32}}}}, params::PredictionParameters, checkLoops::Bool)
    X = Vector{typeof(StructArray(PositionalState[]))}(undef, 0)

    for d ∈ trainData
        x = predictFromRecordedData(d[2], params)
        push!(X, x)

        # Check number of loops exceeds tolerable orientation change
        if checkLoops
            tolerableOrientationChange = d[1] * 2*π + π
            if abs(x.Ψ[1] - x.Ψ[end]) > tolerableOrientationChange 
                return Inf64
            end
        end
    end

    
    accumulatedError = 0.0
    for i ∈ 1:length(X)
        # if no real position is provided compare start and end point 
        if isnothing(trainData[i][3])
            accumulatedError += norm(X[i][1].position - X[i][end].position)
        else
            # Compare with real position
            @warn "Comparing with real position is WIP"
        end
    end

    return accumulatedError / length(X)
end

"""
This function calculates the errors on positional data and returns for each data point the corresponding error value.

# Arguments 
- `trainData::ComplicatedType`: The global train data.
- `params::PredictionParameters`: The parameters to use when calculating the error.
# Returns 
- `Vector{Float32}`: The positional errors arising from the train data with given parameters. 
- `Vector{Float32}`: The orientational errors arising from the train data with given parameters.
"""
function calculateError(trainData::Vector{Tuple{Int64, typeof(StructArray(PositionalData[])), Union{Nothing, Matrix{Float32}}}}, params::PredictionParameters)
    X = Vector{typeof(StructArray(PositionalState[]))}(undef, 0)

    for d ∈ trainData
        x = predictFromRecordedData(d[2], params)
        push!(X, x)

        # Check number of loops exceeds tolerable orientation change
        tolerableOrientationChange = d[1] * 2*π + π
        if abs(x.Ψ[1] - x.Ψ[end]) > tolerableOrientationChange 
            return Inf64
        end
    end

    
    errors = Vector{Float32}(undef, 0)
    orientationErrors = Vector{Float32}(undef, 0)
    for i ∈ 1:length(X)
        # calculate positional error
        push!(errors, norm(X[i][1].position - X[i][end].position)),
        # calculate orientational error
        push!(orientationErrors, norm([X[i][1].Ψ, X[i][1].θ, X[i][1].ϕ] - [X[i][end].Ψ - (i == 1 ? π/2 : 0), X[i][end].θ, X[i][end].ϕ]))
    end    
    

    return errors, orientationErrors
end

"""
This function alters a given parameter set.
    
# Argument 
- `params::PredictionParameters`: The parameters to alter. 
# Returns 
- `Vector{PredictionParameters}`: A vector of parameters changed in every possible way from given parameters.
"""
function getNewParams(params::PredictionParameters)
    possibleParams = Vector{PredictionParameters}(undef, 0)

    params.exponentCC += 0.1
    push!(possibleParams, PredictionParameters(params))
    params.exponentCC -= 0.2
    if params.exponentCC >= 0.0 push!(possibleParams, PredictionParameters(params)) end
    params.exponentCC += 0.1

    params.speedExponentCC += 0.1
    push!(possibleParams, PredictionParameters(params))
    params.speedExponentCC -= 0.2
    if params.speedExponentCC >= 0.0 push!(possibleParams, PredictionParameters(params)) end
    params.speedExponentCC += 0.1

    params.odoGyroFactor += 0.1
    if params.odoGyroFactor <= 1.0 push!(possibleParams, PredictionParameters(params)) end
    params.odoGyroFactor -= 0.2
    if params.odoGyroFactor >= (params.ΨₒmagInfluence ? 0.01 : 0.0) push!(possibleParams, PredictionParameters(params)) end
    params.odoGyroFactor += 0.1

    params.odoMagFactor += 0.1
    if params.odoMagFactor <= 1.0 push!(possibleParams, PredictionParameters(params)) end
    params.odoMagFactor -= 0.2
    if params.odoMagFactor >= 0.0 push!(possibleParams, PredictionParameters(params)) end
    params.odoMagFactor += 0.1

    params.odoSteerFactor += 0.1
    if params.odoSteerFactor <= 1.0 push!(possibleParams, PredictionParameters(params)) end
    params.odoSteerFactor -= 0.2
    if params.odoSteerFactor >= 0.0 push!(possibleParams, PredictionParameters(params)) end
    params.odoSteerFactor += 0.1

    params.steerAngleFactor += 0.02
    if params.steerAngleFactor <= 10.0 push!(possibleParams, PredictionParameters(params)) end
    params.steerAngleFactor -= 0.04
    if params.steerAngleFactor >= 0.0 push!(possibleParams, PredictionParameters(params)) end
    params.steerAngleFactor += 0.02

    params.σ_forSpeedKernel += 0.1
    push!(possibleParams, PredictionParameters(params))
    params.σ_forSpeedKernel -= 0.2
    if params.σ_forSpeedKernel >= 0.015 push!(possibleParams, PredictionParameters(params)) end
    params.σ_forSpeedKernel += 0.1

    params.speedUseSinCC = !params.speedUseSinCC
    push!(possibleParams, PredictionParameters(params))
    params.speedUseSinCC = !params.speedUseSinCC

    params.useSinCC = !params.useSinCC
    push!(possibleParams, PredictionParameters(params))
    params.useSinCC = !params.useSinCC

    params.kalmanFilterCamera = !params.kalmanFilterCamera
    push!(possibleParams, PredictionParameters(params))
    params.kalmanFilterCamera = !params.kalmanFilterCamera  
    
    params.kalmanFilterGyro = !params.kalmanFilterGyro
    push!(possibleParams, PredictionParameters(params))
    params.kalmanFilterGyro = !params.kalmanFilterGyro  

    params.ΨₒmagInfluence = !params.ΨₒmagInfluence
    push!(possibleParams, PredictionParameters(params))
    params.ΨₒmagInfluence = !params.ΨₒmagInfluence

    params.UKF = !params.UKF
    push!(possibleParams, PredictionParameters(params))
    params.UKF = !params.UKF

    if params.kalmanFilterCamera         
        params.processNoiseC += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.processNoiseC -= 0.2
        if params.processNoiseC >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.processNoiseC += 0.1

        params.measurementNoiseC += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.measurementNoiseC -= 0.2
        if params.measurementNoiseC >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.measurementNoiseC += 0.1
    end

    if params.kalmanFilterGyro        
        params.processNoiseG += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.processNoiseG -= 0.2
        if params.processNoiseG >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.processNoiseG += 0.1

        params.measurementNoiseG += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.measurementNoiseG -= 0.2
        if params.measurementNoiseG >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.measurementNoiseG += 0.1
    end

    if params.UKF
        params.processNoiseS += 0.1
        if params.processNoiseS <= 1.0 push!(possibleParams, PredictionParameters(params)) end
        params.processNoiseS -= 0.2
        if params.processNoiseS >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.processNoiseS += 0.1

        params.measurementNoiseS += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.measurementNoiseS -= 0.2
        if params.measurementNoiseS >= 0.01 push!(possibleParams, PredictionParameters(params)) end
        params.measurementNoiseS += 0.1

        params.κ += 0.1
        push!(possibleParams, PredictionParameters(params))
        params.κ -= 0.2
        if params.κ >= 0.0 push!(possibleParams, PredictionParameters(params)) end
        params.κ += 0.1

        params.α += 0.001
        push!(possibleParams, PredictionParameters(params))
        params.α -= 0.002
        if params.α >= 0.00001 push!(possibleParams, PredictionParameters(params)) end
        params.α += 0.001
    end

    return possibleParams
end