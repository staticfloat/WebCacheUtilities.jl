module WebCacheUtilities
using JSON, HTTP, Sockets

include("file_cache.jl")
include("IPSubnet.jl")
include("ipinfo.jl")

# Cloud providers
include("providers/GCE.jl")
include("providers/AWS.jl")
include("providers/Azure.jl")
include("providers/Packet.jl")
include("providers/MacStadium.jl")
include("providers/LiquidWeb.jl")

# CI providers
include("providers/Travis.jl")
include("providers/Appveyor.jl")
include("providers/Cirrus.jl")
include("providers/Drone.jl")
include("providers/GitHubActions.jl")

include("CSVAnalysis.jl")
include("graylog.jl")
include("Fastly.jl")

export prefixes_by_provider, ci_prefixes_by_provider

function prefixes_by_provider(;aws_regions=["us-east-1", "us-east-2", "us-west-1", "us-west-2"],
                               azure_regions=["westus", "westus2", "eastus", "eastus2", "centralus", "northcentralus", "southcentralus"])
    prefixes = Dict{String,Vector{<:IPSubnet}}(
        "MacStadium" => MacStadium.prefixes(),
        "Packet" => Packet.prefixes(),
        "GCE" => GCE.prefixes(),
        "LiquidWeb" => LiquidWeb.prefixes(),
    )

    for region in aws_regions
        prefixes["AWS-$(region)"] = AWS.prefixes_for_region(region)
    end
    for region in azure_regions
        prefixes["Azure-$(region)"] = Azure.prefixes_for_region(region)
    end

    return prefixes
end

function ci_prefixes_by_provider()
    ci_prefixes = Dict{String,Vector{<:IPSubnet}}(
        "Travis" => Travis.prefixes(),
        "Cirrus" => Cirrus.prefixes(),
        "Appveyor" => Appveyor.prefixes(),
        "GitHubActions" => GitHubActions.prefixes(),
        # Eventually
        #"Drone" => Drone.prefixes(),
    )
    return ci_prefixes
end


function __init__()
    # Set up HTTP to use a default user-agent
    HTTP.setuseragent!("WebCacheUtilities.jl")
end

end # module
