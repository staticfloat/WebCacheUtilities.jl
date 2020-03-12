using CSV, DataFrames

export parse_csv_source_ips, parse_csv_payload_sizes, parse_csv_http_uri, parse_csv_http_method, parse_csv_http_response_code,
       attribute_data_to_providers, find_provider

function checkprop(df, name)
    if !hasproperty(df, name)
        error("Unable to find the `$(name)` column, make sure you exported it from graylog!")
    end
end

# Generate String -> DataFrame converters
for f in (:parse_csv_source_iups, :parse_csv_payload_sizes, :parse_csv_http_uri, :parse_csv_http_method, :parse_csv_http_response_code)
    @eval $(f)(path::AbstractString) = $(f)(CSV.read(path))
end

function parse_csv_source_ips(csv_data::DataFrame)
    checkprop(csv_data, :http_src)

    # Grab all the `http_src` fields, parse them out into IPAddr's and return them
    return parse.(IPAddr, csv_data[:, :http_src])
end

function parse_csv_payload_sizes(csv_data::DataFrame)
    checkprop(csv_data, :http_payload_size)

    parse_payload(x::Missing) = 0
    parse_payload(x::Integer) = Int64(x)
    return parse_payload.(csv_data[:, :http_payload_size])
end

function parse_csv_http_uri(csv_data::DataFrame)
    checkprop(csv_data, :http_uri)
    
    return csv_data[:, :http_uri]
end

function parse_csv_http_response_code(csv_data::DataFrame)
    checkprop(csv_data, :http_response_code)
    
    return csv_data[:, :http_response_code]
end

function parse_csv_http_method(csv_data::DataFrame)
    checkprop(csv_data, :http_method)

    return csv_data[:, :http_method]
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

function attribute_data_to_providers(ip_traffic::Dict, pxs::Dict{String,Vector{<:IPSubnet}})
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