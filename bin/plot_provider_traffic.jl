push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using Plots, Dates, WebCacheUtilities, CSV

# Grab the last 48 hours of graylog data (caching it for up to an hour)
graylog_csv = download_graylog_csv(time_period=Hour(48))

# Extract IPs and count up the amount of traffic per IP
@info("Parsing CSV...")
csv_data = CSV.read(graylog_csv)
ips = parse_csv_source_ips(csv_data)
payloads = parse_csv_payload_sizes(csv_data)

# Uniquify them, turn into a dictionary, sum them up by ip
ip_traffic = Dict(ip => 0 for ip in ips)
for idx in 1:length(payloads)
    ip_traffic[ips[idx]] += payloads[idx]
end

# Next, attribute those to providers, where we can
@info("Collating by provider...")
pxs = prefixes_by_provider()
provider_traffic = attribute_traffic_to_providers(ip_traffic, pxs)

sorted_provider_pairs = sort(collect(provider_traffic), by = pair -> last(pair), rev=true)
sorted_provider_names, sorted_provider_values = zip(sorted_provider_pairs...)

@info("Plotting...")
p = Plots.bar(
    collect(sorted_provider_names),
    collect(sorted_provider_values)./(1024^4),
    ylabel="Traffic (TB)",
    xrotation=30,
)
display(p)
