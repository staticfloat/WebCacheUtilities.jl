using WebCacheUtilities
using Sockets

@testset "IPSubnet" begin
    subnet = IPSubnet("1.1.1.1", 31)
    @test subnet.address == ip"1.1.1.0"
    @test subnet.mask == 31

    @test ip"1.1.1.1" in subnet"1.1.1.1/8"
    @test ip"10.128.5.7" in subnet"10.128.5.7/32"
    @test ip"10.128.5.7" in subnet"10.128.5.7/31"
    @test ip"10.128.5.7" in subnet"10.128.5.7/4"
    @test ip"10.128.5.1" in subnet"10.128.5.0/31"
    @test !(ip"10.128.5.1" in subnet"10.128.5.0/32")
end