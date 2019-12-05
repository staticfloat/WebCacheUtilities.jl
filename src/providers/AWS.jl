module AWS
using HTTP, JSON
import ..IPSubnet, ..download_to_cache

prefixes_by_region = Dict{String,Vector{IPSubnet}}()
function get_prefixes_by_region()
    global prefixes_by_region
    if isempty(prefixes_by_region)
        json_file = download_to_cache("aws_ip_ranges.json", "https://ip-ranges.amazonaws.com/ip-ranges.json")
        prefixes = JSON.parsefile(json_file)["prefixes"]
        for p in prefixes
            if !haskey(prefixes_by_region, p["region"])
                prefixes_by_region[p["region"]] = IPSubnet[]
            end
            push!(prefixes_by_region[p["region"]], IPSubnet(p["ip_prefix"]))
        end

        for region in keys(prefixes_by_region)
            prefixes_by_region[region] = unique(prefixes_by_region[region])
        end
    end
    return prefixes_by_region
end

function prefixes_for_region(region_name)
    prefixes_by_region = get_prefixes_by_region()
    if !haskey(prefixes_by_region, region_name)
        error("Invalid region name $(region_name); valid choices: $(join(keys(prefixes_by_region), ", "))")
    end
    return prefixes_by_region[region_name]
end

function prefix_regions()
    prefixes_by_region = get_prefixes_by_region()
    return collect(keys(prefixes_by_region))
end

end # AWS