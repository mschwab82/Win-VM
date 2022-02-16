# Networkconfiguration

$ConfigAdapterName = Get-NetAdapter | where MacAddress -eq "1MACAddress"

Rename-NetAdapter -Name $ConfigAdapterName.name -NewName "1NetworkAdapterName"
Set-NetIPInterface -InterfaceIndex $ConfigAdapterName.ifIndex -Dhcp Disabled

New-NetIPAddress -InterfaceIndex $ConfigAdapterName.ifIndex -IPAddress 1IPDomain -DefaultGateway 1DefaultGW -PrefixLength 24
Set-DNSClientServerAddress -InterfaceIndex $ConfigAdapterName.ifIndex -ServerAddresses ("1DNSServer1","1DNSServer2")
Set-DnsClientGlobalSetting -SuffixSearchList @("1DNSDomain")