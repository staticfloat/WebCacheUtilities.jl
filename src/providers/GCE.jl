module GCE
import ..IPSubnet, ..hit_file_cache

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

function prefixes()
    domains_to_process = ["_cloud-netblocks.googleusercontent.com"]
    ranges = IPSubnet[]
    while !isempty(domains_to_process)
        # First, hit the next domain to process
        next_domain = pop!(domains_to_process)
        txt_record_file = hit_file_cache("$(next_domain).txt") do txt_record_file
            # Write the DNS queries out to a .txt file, one line per record
            open(txt_record_file, "w") do io
                txt_records = dig(next_domain, "TXT")
                for record in txt_records
                    println(io, record)
                end
            end
        end

        # Read the lines back in from our cache
        txt_records = readlines(txt_record_file)

        for txt_rec in txt_records
            # Extract any `include:` statements within the TXT records
            for m in eachmatch(r"include:([^ ]+)", txt_rec)
                push!(domains_to_process, m.captures[1])
            end

            for m in eachmatch(r"ip4:([^ ]+)", txt_rec)
                push!(ranges, IPSubnet(m.captures[1]))
            end
        end
    end
    return ranges
end

end # module GCE