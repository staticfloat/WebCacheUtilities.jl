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
    return unique(subnets)
end


function dig(addr, record_type="A")
    # Until we have a builtin resolver in Julia, we'll shell out to `dig`:
    raw = chomp(String(read(`dig +noall +answer $addr $record_type`)))

    # Parse out the 5th column stuff
    result = String[]
    for line in split(raw, "\n")
        line = split(line)
        if length(line) < 5
            continue
        end
        push!(result, join(line[5:end], " "))
    end
    return result
end

function dig_cache(domain, record_type="A")
    record_file = hit_file_cache("$(domain)_$(record_type).txt") do record_file
        # Write the DNS queries out to a .txt file, one line per record
        open(record_file, "w") do io
            records = dig(domain, record_type)
            for record in records
                println(io, record)
            end
        end
    end
    return readlines(record_file)
end