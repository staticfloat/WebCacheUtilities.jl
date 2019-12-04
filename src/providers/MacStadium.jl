module MacStadium
import ..IPSubnet, ..extract_subnets_from_ipinfo

prefixes() = extract_subnets_from_ipinfo("AS395336")

end # module MacStadium