import DelimitedFiles

export parse_csv_source_ips, parse_csv_traffic_per_ip, attribute_ips_to_providers, attribute_traffic_to_providers

function parse_csv_source_ips(path::AbstractString)
    csv_data = DelimitedFiles.readdlm(path, ',')

    http_srcs_idx = findfirst(csv_data[1, :] .== "http_src")
    if http_srcs_idx === nothing
        error("Unable to find the `http_srcs` column, make sure you exported it!")
    end

    # Grab all the `http_src` fields, parse them out into IPAddr's and return them
    return parse.(IPAddr, csv_data[2:end, http_srcs_idx])
end

function parse_csv_traffic_per_ip(path::AbstractString)
    csv_data = DelimitedFiles.readdlm(path, ',')

    http_srcs_idx = findfirst(csv_data[1, :] .== "http_src")
    if http_srcs_idx === nothing
        error("Unable to find the `http_srcs` column, make sure you exported it!")
    end
    http_payload_size_idx = findfirst(csv_data[1, :] .== "http_payload_size")
    if http_payload_size_idx === nothing
        error("Unable to find the `http_payload_size` column, make sure you exported it!")
    end

    # Grab IPs and payload sizes
    ips = parse.(IPAddr, csv_data[2:end, http_srcs_idx])
    parse_payload(x::AbstractString) = 0
    parse_payload(x::Integer) = Int64(x)
    payloads = parse_payload.(csv_data[2:end, http_payload_size_idx])
    
    # Uniquify them, turn into a dictionary
    ip_traffic = Dict(ip => 0 for ip in ips)

    # Start summing it up!
    for idx in 1:length(payloads)
        ip_traffic[ips[idx]] += payloads[idx]
    end
    
    return ip_traffic
end

firstbyte(x::UInt32)  = UInt8(x >> 24)
firstbyte(x::UInt128) = UInt8(x >> 120)

function prebin_pxs(pxs)
    # Bin first byte of each prefix to speed lookups, then build reverse-subnet 
    prefix_dict = Dict(UInt8(idx) => Vector{Tuple{IPSubnet, String}}() for idx in 0:255)
    for provider in keys(pxs)
        for prefix in pxs[provider]
            byte_list = prefix_dict[firstbyte(prefix.address.host)]
            push!(byte_list, (prefix, provider))
        end
    end
    # The last thing in every byte list is the "unknown" provider
    for idx in 0:255
        push!(prefix_dict[idx], (subnet"0.0.0.0/0", "<unknown>"))
    end
    return prefix_dict
end

# Simple find_provider
function find_provider(pxs::Dict{String,Vector{<:IPSubnet}}, ip)
    for provider in keys(pxs)
        for prefix in pxs[provider]
            if ip in prefix
                return provider
            end
        end
    end
    return "<unknown>"    
end

# Binned find_provider
function find_provider(prefix_dict::Dict{UInt8,Vector{Tuple{IPSubnet,String}}}, ip)
    byte_list = prefix_dict[firstbyte(ip.host)]
    for (prefix, provider) in byte_list
        if ip in prefix
            return provider
        end
    end
    return "<unknown>"
end

function attribute_ips_to_providers(ips::Vector{<:IPAddr}, pxs::Dict{String,Vector{<:IPSubnet}})
    # Prebin our prefixes for fast lookups
    prefix_dict = prebin_pxs(pxs)

    provider_ips = Dict(provider => Vector{IPAddr}() for provider in keys(pxs))
    provider_ips["<unknown>"] = Vector{IPAddr}()

    # Next, loop through the (uniquified) ips, attributing each one to a provider.
    for ip in unique(ips)
        provider = find_provider(prefix_dict, ip)
        push!(provider_ips[provider], ip)
    end

    return provider_ips
end

function attribute_traffic_to_providers(ip_traffic::Dict, pxs::Dict{String,Vector{<:IPSubnet}})
    # Prebin our prefixes for fast lookups
    prefix_dict = prebin_pxs(pxs)

    # Initialize dictionary to hold 
    provider_traffic = Dict(provider => 0 for provider in keys(pxs))
    provider_traffic["<unknown>"] = 0

    # Next, loop through our IP -> traffic amount mapping, attributing each one to a provider.
    for (ip, traffic) in ip_traffic
        provider_traffic[find_provider(prefix_dict, ip)] += traffic
    end
    return provider_traffic
end