# -------------------------------------- Part 1 Start -------------------------------------- #

    # Computername & VMName
    $Name = "SRV-WSUS-01"

    # CPU's
    $CPUCount = 2

    # VM Generation
    $Generation = 2

    # RAM
    $RAMCount = 2GB
    $RAMCountMin = 1GB
    $RAMCountMax = 4GB

    # DNS Domain Name
    $DNSDomain = "schwab.local"
    
    # IP Address
    $IPDomain = "192.168.10.15"
    
    # Default Gateway to be used
    $DefaultGW = "192.168.10.1"
    
    # DNS Server
    $DNSServer1 = "192.168.10.11"
    $DNSServer2 = "192.168.10.10"
    
    # Hyper-V Switch Name
    $SwitchNameDomain = "Private Net"
    
    #Set the VM Domain access NIC name
    $NetworkAdapterName = "Primary Adapter"

    # Username & Password
    $AdminAccount = "Local-Admin"
    $AdminDisplayName = "Administrator (Local)"
    $AdminPassword = "ABCD-1234"

    # This ProductID is actually the AVMA key provided by MS
    $ProductID = "TMJ3Y-NTRTM-FJYXT-T22BY-CWG3J"
    
    # Where's the VM Default location? You can also specify it manually
    $Path = Get-VMHost | select VirtualMachinePath -ExpandProperty VirtualMachinePath
    
    # Where should I store the VM VHD?, you actually have nothing to do here unless you want a custom name on the VHD
    $VHDPath = $Path + $Name + "\" + "Virtual Disks"
    $VHDPathFile = $Path + $Name + "\" + "Virtual Disks" + "\" + $Name + ".vhdx"
    
    # Where are the folders with prereq software ?
    $StartupFolder = ".\01_Config\$Name"
    $TemplateLocation = ".\02_Sources\2016\SYSPREP\2016_SypPrep-GUI.vhdx"
    $UnattendLocation = ".\01_Config"
 
# -------------------------------------- Part 1 Stop --------------------------------------- #

function FN-Unattend
{
    Copy-Item $UnattendLocation\Unattend.xml $StartupFolder\Unattend-$Name.xml
    
    $DefaultXML = $StartupFolder+"\Unattend-"+$Name+".xml"
    $NewXML = $StartupFolder+"\Unattend-"+$Name+".xml"
    $DefaultXML = Get-Content $DefaultXML
    $DefaultXML  | Foreach-Object {
    $_ -replace '1AdminAccount', $AdminAccount `
    -replace '1AdminDisplayName', $AdminDisplayName `
    -replace '1Name', $Name `
    -replace '1ProductID', $ProductID`
    -replace '1AdminPassword', $AdminPassword `
    } | Set-Content $NewXML
}

function FN-Network
{
    Copy-Item $UnattendLocation\Network.ps1 $StartupFolder\Network-$Name.ps1

    $DefaultNetwork = $StartupFolder+ "\Network-"+$Name+".ps1"
    $NewNetwork = $StartupFolder+ "\Network-"+$Name+".ps1"
    $DefaultNetwork = Get-Content $DefaultNetwork
    $DefaultNetwork  | Foreach-Object {
    $_ -replace '1MACAddress', $MACAddress `
    -replace '1NetworkAdapterName', $NetworkAdapterName `
    -replace '1IPDomain', $IPDomain `
    -replace '1DefaultGW', $DefaultGW `
    -replace '1DNSServer1', $DNSServer1 `
    -replace '1DNSServer2', $DNSServer2 `
    -replace '1DNSDomain', $DNSDomain `
    } | Set-Content $NewNetwork
}

function FN-BGInfo
{
    Copy-Item $UnattendLocation\BGInfo.ps1 $StartupFolder\BGInfo-$Name.ps1

    $NewBGInfo = $StartupFolder+ "\BGInfo-"+$Name+".ps1"

}

# -------------------------------------- Part 2 Start -------------------------------------- #


# -- Check if VM exists -- # 

    $VMS = Get-VM
    Foreach($VM in $VMS)
    {
        if ($Name -match $VM.Name)
        {
            write-host -ForegroundColor Red "Found VM With the same name!!!!!"
            $Found=$True
        }
    }
 
# -- Create the VM -- #
    
    New-VM -Name $Name -Path $Path -MemoryStartupBytes $RAMCount -Generation 2 -NoVHD
 
# -- Remove any auto generated adapters and add new ones with correct names for Consistent Device Naming -- #

    Get-VMNetworkAdapter -VMName $Name | Remove-VMNetworkAdapter
    Add-VMNetworkAdapter -VMName $Name -SwitchName $SwitchNameDomain -Name $NetworkAdapterName -DeviceNaming On
 
# -- Start and stop VM to get mac address, then arm the new MAC address on the NIC itself -- #

    start-vm $Name
    sleep 5
    stop-vm $Name -Force
    sleep 5

    $MACAddress = Get-VMNetworkAdapter -VMName $Name -Name $NetworkAdapterName|select MacAddress -ExpandProperty MacAddress
    $MACAddress = ($MACAddress -replace '(..)','$1-').trim('-')
    Get-VMNetworkAdapter -VMName $Name -Name $NetworkAdapterName|Set-VMNetworkAdapter -StaticMacAddress $MACAddress

# -- Copy the template and add the disk on the VM. Also configure CPU and start - stop settings -- #

    mkdir $VHDPath
    Copy-item $TemplateLocation -Destination $VHDPathFile
    Set-VM -Name $Name -ProcessorCount $CpuCount  -AutomaticCheckpointsEnabled $false -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 -MemoryMinimumBytes $RAMCountMin -MemoryMaximumBytes $RAMCountMax
    Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPathFile
 
# -- Set first boot device to the disk we attached -- #

    $Drive = Get-VMHardDiskDrive -VMName $Name | where {$_.Path -eq "$VHDPathFile"}
    Get-VMFirmware -VMName $Name | Set-VMFirmware -FirstBootDevice $Drive
 
# -- Prepare the unattend.xml & SetupComplete.cmd file to send out, simply copy to a new file and replace values -- #

    mkdir $StartupFolder

    FN-Unattend

    FN-Network
    
    FN-BGInfo


# -- Mount the new virtual machine VHD -- #

    Mount-VHD -Path $VHDPathFile

# -- Find the drive letter of the mounted VHD -- #

    $VolumeDriveLetter = GET-DISKIMAGE $VHDPathFile | GET-DISK | GET-PARTITION |get-volume |?{$_.FileSystemLabel -ne "Recovery"}|select DriveLetter -ExpandProperty DriveLetter

# -- Construct the drive letter of the mounted VHD Drive -- #
    
    $DriveLetter = "$VolumeDriveLetter"+":"

# -- Copy the unattend.xml to the drive -- #

    Copy-Item $NewXML $DriveLetter\unattend.xml
    Copy-Item $NewNetwork $DriveLetter\Windows\Setup\Scripts\Network.ps1
    Copy-Item $NewBGInfo $DriveLetter\Windows\Setup\Scripts\BGInfo.ps1
    
# -- Dismount the VHD -- #

    Dismount-Vhd -Path $VHDPathFile

# -- Fire up the VM -- #

    Start-VM $Name

# -------------------------------------- Part 2 Stop --------------------------------------- #