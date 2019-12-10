module GCE
import ..IPSubnet, ..hit_file_cache, ..dig_cache

function prefixes()
    domains_to_process = ["_cloud-netblocks.googleusercontent.com"]
    ranges = IPSubnet[]
    while !isempty(domains_to_process)
        # First, hit the next domain to process
        next_domain = pop!(domains_to_process)
        txt_records = dig_cache(next_domain, "TXT")

        for txt_rec in txt_records
            # Extract any `include:` statements within the TXT records
            for m in eachmatch(r"include:([^ ]+)", txt_rec)
                push!(domains_to_process, m.captures[1])
            end

            for m in eachmatch(r"ip4:([^ ]+)", txt_rec)
                push!(ranges, IPSubnet(m.captures[1]))
            end

            for m in eachmatch(r"ip6:([^ ]+)", txt_rec)
                push!(ranges, IPSubnet(m.captures[1]))
            end
        end
    end
    return unique(ranges)
end

end # module GCE