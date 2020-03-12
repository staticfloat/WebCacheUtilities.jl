push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))
using WebCacheUtilities, Sockets, Dates, CSV, DataFrames, Printf
using Plots, Measures, StatsPlots

function distill_dataset(criteria::Function, num_months = 18, stop_month = DateTime(year(now()), month(now()), 1))
    dataset = DataFrame()
    for month_idx in 0:(num_months - 1)
        to = stop_month - Month(month_idx)
        from = to - Month(1)
        @info("Processing $(month(from))/$(year(from))")
        csv_path = download_graylog_csv((from, to))
        dataset = [dataset; filter(criteria, CSV.read(csv_path))]
    end

    return dataset
end

# Load CI prefixes
ci_pxs = ci_prefixes_by_provider()

# Load cloud proivder prefixes
pxs = prefixes_by_provider()

# First, distill dataset down for non-cloud downloads.  We test against our list of IP addresses.
noncloud_dataset = distill_dataset() do row
    # Throw out anything that doesn't have the keys we need:
    if row[:http_response_code] === missing ||
       row[:http_method] === missing ||
       row[:http_uri] === missing ||
       row[:http_src] === missing
        return false
    end

    # Next, check that it was HTTP 200 OK, was a GET to something in `/bin`
    # and it wasn't one of the CI IPs we have collected in a list of prefixes
    # or one of the cloud provider IPs.
    return row[:http_response_code] == 200 &&
           row[:http_method] == "GET" &&
           startswith(row[:http_uri], "/bin") &&
           find_provider(ci_pxs, parse.(IPAddr, row[:http_src])) == "<unknown>" &&
           find_provider(pxs, parse.(IPAddr, row[:http_src])) == "<unknown>"
end

# Also create one where we've filtered out only transmissions >= 50 MB in size
noncloud_overhalf_dataset = filter(noncloud_dataset) do row
    if row[:http_payload_size] === missing
        return false
    end

    return row[:http_payload_size] >= 50*1024*1024
end

# Also get another one for only cloud IPs
cloud_dataset = distill_dataset() do row
    # Throw out anything that doesn't have the keys we need:
    if row[:http_response_code] === missing ||
       row[:http_method] === missing ||
       row[:http_uri] === missing ||
       row[:http_src] === missing
        return false
    end

    ip = parse.(IPAddr, row[:http_src])

    # Make sure that the GET and "/bin" stuff from above is preserved:
    return row[:http_method] == "GET" &&
           startswith(row[:http_uri], "/bin") &&
           # We can have a 302 OR a 200 at this point though (In November of 2019 we
           # started redirecting cloud providers with 302's)
           (row[:http_response_code] == 302 || row[:http_response_code] == 200) &&
           find_provider(ci_pxs, ip) == "<unknown>" &&
           # Only keep IPs that match our known cloud providers (but not Azure)
           find_provider(pxs, ip) != "<unknown>" &&
           !startswith(find_provider(pxs, ip), "Azure")
end

# Useful keyfuncs
byday(t) = DateTime(year(t), month(t), day(t))
bymonth(t) = DateTime(year(t), month(t))
byyear(t) = DateTime(year(t))
function reduce_by_time(extractor::Function, dataset,
                        # By default, bin by year/month
                        key_func::Function,
                        # By default, pass in an empty dict
                        initializer = () -> Dict())
    stats = Dict()
    for idx in 1:size(dataset, 1)
        # Gotta chop off the ".000Z" at the end, unfortunately
        key = key_func(DateTime(dataset[idx, :timestamp][1:end-5]))

        if !(key in keys(stats))
            stats[key] = initializer()
        end

        extractor(dataset[idx, :], stats[key])
    end
    return stats
end

function hits_by_time(dataset, key_func)
    return reduce_by_time(dataset, key_func, () -> Dict(:hits => 0)) do row, data
        data[:hits] += 1
    end
end

cloud_hits_by_day = hits_by_time(cloud_dataset, byday)
noncloud_hits_by_day = hits_by_time(noncloud_dataset, byday)
noncloud_overhalf_hits_by_day = hits_by_time(noncloud_overhalf_dataset, byday)

cloud_hits_by_month = hits_by_time(cloud_dataset, bymonth)
noncloud_hits_by_month = hits_by_time(noncloud_dataset, bymonth)
noncloud_overhalf_hits_by_month = hits_by_time(noncloud_overhalf_dataset, bymonth)

# Plot 'em!
months = sort(collect(keys(cloud_hits_by_month)))
days = sort(collect(keys(cloud_hits_by_day)))

begin
    println("Initiated downloads per month:")
    for m in months
        println(@sprintf(
            "  %02d/%04d: %d (cloud) %d (noncloud) %d (noncloud >50MB)",
            month(m),
            year(m),
            cloud_hits_by_month[m][:hits],
            noncloud_hits_by_month[m][:hits],
            noncloud_overhalf_hits_by_month[m][:hits],
        ))
    end
    println()
end

begin
    # grouped bar with month-specificity
    groupedbar(
        1:length(months),
        hcat(
            collect(cloud_hits_by_month[m][:hits]/daysinmonth(m) for m in months),
            collect(noncloud_hits_by_month[m][:hits]/daysinmonth(m) for m in months),
            collect(noncloud_overhalf_hits_by_month[m][:hits]/daysinmonth(m) for m in months),
        ),
        bar_position=:stack,
        bar_width=0.7,
        label=["Cloud hits" "Non-cloud hits" "Non-cloud >50MB"],
        ylabel="Hits/day",
        xticks=(1:length(months), ["$(monthname(m)) $(year(m))" for m in months]),
        xrotation=30,
        bottom_margin=11mm,
        left_margin=16mm,
    )
end

begin
    plot(
        days,
        hcat(
            collect(cloud_hits_by_day[d][:hits] for d in days),
            collect(noncloud_hits_by_day[d][:hits] for d in days),
            collect(noncloud_overhalf_hits_by_day[d][:hits] for d in days),
        ),
        label=["Cloud hits" "Non-cloud hits" "Non-cloud >50MB"],
        legend=:topleft,
        ylabel="Hits by day",
        xrotation=30,
        bottom_margin=11mm,
        left_margin=16mm,
    )
end


function unique_ips_by_time(dataset, key_func)
    return reduce_by_time(dataset, key_func, () -> Set{IPAddr}()) do row, data
        push!(data, parse.(IPAddr, row[:http_src]))
    end
end

cloud_unique_ips_by_day = unique_ips_by_time(cloud_dataset, byday)
noncloud_unique_ips_by_day = unique_ips_by_time(noncloud_dataset, byday)

cloud_unique_ips_by_month = unique_ips_by_time(cloud_dataset, bymonth)
noncloud_unique_ips_by_month = unique_ips_by_time(noncloud_dataset, bymonth)

cloud_unique_ips_by_year = unique_ips_by_time(cloud_dataset, byyear)
noncloud_unique_ips_by_year = unique_ips_by_time(noncloud_dataset, byyear)

begin
    println("Unique IPs per year:")
    for y in [DateTime(2019), DateTime(2020)]
        println("  $(year(y)): $(length(cloud_unique_ips_by_year[y])) (cloud), $(length(noncloud_unique_ips_by_year[y])) (noncloud)")
    end
    println()

    println("Unique IPs per month:")
    for m in months
        println(@sprintf("  %02d/%04d: %d (cloud) %d (noncloud)",
            month(m),
            year(m),
            length(cloud_unique_ips_by_month[m]),
            length(noncloud_unique_ips_by_month[m]),
        ))
    end
    println()
end

begin
    # grouped bar with month-specificity
    groupedbar(
        1:length(months),
        hcat(
            collect(length(cloud_unique_ips_by_month[m]) for m in months),
            collect(length(noncloud_unique_ips_by_month[m]) for m in months),
        ),
        bar_position=:stack,
        bar_width=0.7,
        label=["Cloud unique IPs" "Non-cloud unique IPs"],
        legend=:bottomright,
        ylabel="Unique IPs",
        xticks=(1:length(months), ["$(monthname(m)) $(year(m))" for m in months]),
        xrotation=30,
        bottom_margin=11mm,
        left_margin=16mm,
    )
end

begin
    Plots.plot(
        days,
        hcat(
            collect(length(cloud_unique_ips_by_day[d]) for d in days),
            collect(length(noncloud_unique_ips_by_day[d]) for d in days),
        ),
        label=["Cloud" "Non-cloud"],
        ylabel="Unique IPs",
        legend=:topleft,
        xrotation=30,
        bottom_margin=10mm,
        left_margin=14mm,
    )
end


# Get download split by major version and OS
begin
    combined_dataset = vcat(cloud_dataset, noncloud_dataset)

    oses = ["linux", "mac", "winnt", "freebsd"]
    versions = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5"]
    split_by_version = reduce_by_time(combined_dataset, bymonth, () -> Dict(k => 0 for k in versions)) do row, data
        m = match(r"\/(\d\.\d)\/julia", row[:http_uri])
        if m !== nothing && m.captures[1] in keys(data)
            data[m.captures[1]] += 1
        end
    end
    split_by_os = reduce_by_time(combined_dataset, bymonth, () -> Dict(k => 0 for k in oses)) do row, data
        m = match(r"bin\/([^/]+)\/", row[:http_uri])
        if m !== nothing && m.captures[1] in keys(data)
            data[m.captures[1]] += 1
        end
    end
end

begin
    groupedbar(
        1:length(months),
        hcat((collect(split_by_version[m][v] for m in months) for v in reverse(versions))...),
        label=hcat(collect("Julia v$(v)" for v in reverse(versions))...),
        ylabel="Hits by version",
        bar_position=:stack,
        legend=:bottomleft,
        xticks=(1:length(months), ["$(monthname(m)) $(year(m))" for m in months]),
        xrotation=30,
        bottom_margin=11mm,
        left_margin=14mm,
    )
end