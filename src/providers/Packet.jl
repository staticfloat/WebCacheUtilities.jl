module Packet
import ..IPSubnet, ..extract_subnets_from_ipinfo

prefixes() = extract_subnets_from_ipinfo("AS54825")

end # module Packet