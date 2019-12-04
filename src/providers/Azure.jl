module Azure
using HTTP, JSON
import ..IPSubnet, ..download_to_cache

prefixes_by_region = Dict{String,Vector{IPSubnet}}()
function get_prefixes_by_region()
    global prefixes_by_region
    if isempty(prefixes_by_region)
        json_file = download_to_cache(
            "azure_ip_ranges.json",
            "https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20191202.json"
        )
        
        regions = JSON.parsefile(json_file)["values"]
        for r in regions
            # We only care about the `AzureCloud.<name>` values
            if !startswith(r["name"], "AzureCloud.")
                continue
            end
            region = r["name"][12:end]
            prefixes_by_region[region] = IPSubnet.(r["properties"]["addressPrefixes"])
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

end # module Azure