push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))
using WebCacheUtilities, Sockets

ci_pxs = ci_prefixes_by_provider()

# Use `find_hot_ips` to find more of these.
manually_determined_ci_subnets = IPSubnet[
    # macOS Github Actions maybe?
    subnet"199.7.166.17/32",
]

# Get _all_ known CI IPs in a single 
all_prefixes = vcat(values(ci_pxs)..., manually_determined_ci_subnets...)
match_str = join(["cidr_match(\"$(string(subnet))\", to_ip(\$message.http_src))" for subnet in all_prefixes], " || ")

println("""
rule "is_ci_ip"
when
    has_field("http_src") && ($(match_str))
then
    set_field("is_ci_ip", true);
end
""")