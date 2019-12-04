using Gumbo, AbstractTrees

function extract_subnets_from_ipinfo(as_number::AbstractString)
    html_path = download_to_cache("$(as_number).html", "https://ipinfo.io/$(as_number)")
    html = parsehtml(String(read(html_path)))
    
    # Find all links that point to /$(as_number)/<ip address>
    subnets = IPSubnet[]
    as_number_len = length(as_number)
    for elem in PostOrderDFS(html.root)
        # First, find <a> tags
        if isa(elem, HTMLElement) && tag(elem) == :a && haskey(elem.attributes, "href")
            href = elem.attributes["href"]
            if length(href) > as_number_len + 1 && href[2:as_number_len+1] == as_number
                subnet_str = href[as_number_len+3:end]
                push!(subnets, IPSubnet(subnet_str))
            end
        end
    end
    return subnets
end