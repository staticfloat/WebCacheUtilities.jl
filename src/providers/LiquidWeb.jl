module LiquidWeb
import ..IPSubnet, ..extract_subnets_from_ipinfo

prefixes() = extract_subnets_from_ipinfo("AS32244")

end # module LiquidWeb