module Azure
using HTTP, JSON, Gumbo, AbstractTrees
import ..IPSubnet, ..download_to_cache, ..for_each_href

prefixes_by_region = Dict{String,Vector{IPSubnet}}()
function get_prefixes_by_region()
    global prefixes_by_region
    if isempty(prefixes_by_region)
        html_path = download_to_cache(
            "azure_html_bounce.html",
            "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519",
        )
        
        json_url = nothing
        for_each_href(html_path) do href
            if match(r"ServiceTags_Public_\d+\.json$", href) !== nothing
                json_url = href
            end
        end

        if json_url === nothing
            error("Unable to auto-detect Azure IP ranges JSON location.  PHOOEY.")
        end
        json_file = download_to_cache("azure_ip_ranges.json", json_url)
        regions = JSON.parsefile(json_file)["values"]
        for r in regions
            # We only care about the `AzureCloud.<name>` values
            if !startswith(r["name"], "AzureCloud.")
                continue
            end
            region = r["name"][12:end]
            prefixes_by_region[region] = unique(IPSubnet.(r["properties"]["addressPrefixes"]))
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