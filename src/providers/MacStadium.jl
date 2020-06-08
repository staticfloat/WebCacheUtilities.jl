module MacStadium
import ..IPSubnet, ..extract_subnets_from_ipinfo

prefixes() = vcat(
    extract_subnets_from_ipinfo("AS395336"),
    extract_subnets_from_ipinfo("AS54112"),
    extract_subnets_from_ipinfo("AS397114"),
)

end # module MacStadium