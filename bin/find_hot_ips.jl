push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))
using WebCacheUtilities, Dates, CSV

# Parameters
num_top = 50
exclude_known_ci_ips = true

# Load in our prefix mappings
pxs = prefixes_by_provider()
ci_pxs = ci_prefixes_by_provider()

# We're going to try and find "hot" IPs by downloading the last two months of requests,
# then showing the top IPs that did a lot of GET requests to things in `/bin`:
graylog_csv = download_graylog_csv(time_period=Hour(2*31*24))
csv_data = CSV.read(graylog_csv)

# Drop anything that wasn't a `GET` or doesn't have an http_uri that starts with `/bin`:
csv_data = filter(row -> row[:http_method] == "GET" && startswith(row[:http_uri], "/bin"), csv_data)

# Next, bin requests by IP, then sort IPs by number of requests:
row_ips = parse_csv_source_ips(csv_data)

# Filter out known CI ips if we've been asked to
ips = unique(row_ips)
if exclude_known_ci_ips
    filter!(ip -> find_provider(ci_pxs, ip) == "<unknown>", ips)
end
ip_requests = Dict(ip => 0 for ip in ips)

for row_idx in 1:length(row_ips)
    if haskey(ip_requests, row_ips[row_idx])
        ip_requests[row_ips[row_idx]] += 1
    end
end


top_ips = sort(collect(keys(ip_requests)), by=ip->ip_requests[ip], rev=true)[1:num_top]

# Print out the top offenders
for ip in top_ips
    hosting_provider = find_provider(pxs, ip)
    hosting_provider_str = hosting_provider != "<unknown>" ? " ($(hosting_provider))" : ""

    ci_provider = find_provider(ci_pxs, ip)
    ci_provider_str = ci_provider != "<unknown>" ? " ($(ci_provider))" : ""
    println("$ip: $(ip_requests[ip])$(hosting_provider_str)$(ci_provider_str)")
end