module WebCacheUtilities
using JSON, HTTP, Sockets

export prefixes_by_provider

include("file_cache.jl")
include("IPSubnet.jl")
include("ipinfo.jl")
include("providers/GCE.jl")
include("providers/AWS.jl")
include("providers/Azure.jl")
include("providers/Packet.jl")
include("providers/MacStadium.jl")
include("providers/LiquidWeb.jl")
include("CSVAnalysis.jl")
include("graylog.jl")
include("Fastly.jl")

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

end # module
