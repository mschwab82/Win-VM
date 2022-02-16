# Networkconfiguration

$ConfigAdapterName = Get-NetAdapter | where MacAddress -eq "00-15-5D-01-10-6D"

Rename-NetAdapter -Name $ConfigAdapterName.name -NewName "Primary Adapter"
Set-NetIPInterface -InterfaceIndex $ConfigAdapterName.ifIndex -Dhcp Disabled

New-NetIPAddress -InterfaceIndex $ConfigAdapterName.ifIndex -IPAddress 192.168.10.15 -DefaultGateway 192.168.10.1 -PrefixLength 24
Set-DNSClientServerAddress -InterfaceIndex $ConfigAdapterName.ifIndex -ServerAddresses ("192.168.10.11","192.168.10.10")
Set-DnsClientGlobalSetting -SuffixSearchList @("schwab.local")
