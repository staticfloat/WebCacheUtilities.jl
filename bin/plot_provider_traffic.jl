push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using Plots, Dates, WebCacheUtilities, CSV, Measures, DataFrames, Sockets

# Grab the last month of graylog data (caching it for up to an hour)
graylog_csv = download_graylog_csv(Hour(31*24))
ci_pxs = ci_prefixes_by_provider()

# Extract IPs and count up the amount of traffic per IP
@info("Parsing CSV...")
csv_data = CSV.read(graylog_csv)
csv_data = dropmissing(csv_data, [:http_response_code, :http_method, :http_uri, :http_src])
csv_data = filter(row -> row[:http_response_code] == 302 &&
                         row[:http_method] == "GET" &&
                         startswith(row[:http_uri], "/bin") &&
                         find_provider(ci_pxs, parse.(IPAddr, row[:http_src])) == "<unknown>",
                  csv_data)

ips = parse_csv_source_ips(csv_data)
payloads = parse_csv_payload_sizes(csv_data)

# Uniquify them, turn into a dictionary, sum them up by ip
ip_traffic = Dict(ip => 0 for ip in ips)
ip_hits = Dict(ip => 0 for ip in ips)
for idx in 1:length(ips)
    ip_traffic[ips[idx]] += payloads[idx]
    ip_hits[ips[idx]] += 1
end

# Next, attribute those to providers, where we can
@info("Collating by provider...")
pxs = prefixes_by_provider()
provider_traffic = attribute_data_to_providers(ip_traffic, pxs)

sorted_provider_pairs = sort(collect(provider_traffic), by = pair -> last(pair), rev=true)
sorted_provider_names, sorted_provider_values = zip(sorted_provider_pairs...)

@info("Plotting...")
p = Plots.bar(
    collect(sorted_provider_names),
    collect(sorted_provider_values)./(1024^4),
    ylabel="Traffic (TB)",
    xrotation=30,
    bottom_margin=11mm,
    left_margin=7mm,
)
display(p)

provider_hits = attribute_data_to_providers(ip_hits, pxs)
delete!(provider_hits, "<unknown>")
sorted_provider_pairs = sort(collect(provider_hits), by = pair -> last(pair), rev=true)
sorted_provider_names, sorted_provider_values = zip(sorted_provider_pairs...)

@info("Plotting...")
p = Plots.bar(
    collect(sorted_provider_names),
    collect(sorted_provider_values),
    ylabel="Downloads (per month)",
    legend=nothing,
    xrotation=30,
    bottom_margin=14mm,
    left_margin=16mm,
)
display(p)

for k in collect(keys(provider_hits))
    if startswith(k, "Azure")
        delete!(provider_hits, k)
    end
end

sorted_provider_pairs = sort(collect(provider_hits), by = pair -> last(pair), rev=true)
sorted_provider_names, sorted_provider_values = zip(sorted_provider_pairs...)

@info("Plotting...")
p = Plots.bar(
    collect(sorted_provider_names),
    collect(sorted_provider_values),
    ylabel="Downloads (per month)",
    legend=nothing,
    xrotation=30,
    bottom_margin=14mm,
    left_margin=16mm,
)
display(p)
