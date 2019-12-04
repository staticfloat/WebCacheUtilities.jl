push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using Plots, Dates, WebCacheUtilities

# Grab the last 48 hours of graylog data (caching it for up to an hour)
graylog_csv = download_graylog_csv(time_period=Hour(8))

# Extract IPs and count up the amount of traffic per IP
@info("Parsing CSV...")
ip_traffic = parse_csv_traffic_per_ip(graylog_csv)

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
