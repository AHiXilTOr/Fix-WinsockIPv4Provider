# Repairs a broken IPv4 MSAFD Winsock provider source and rebuilds Winsock catalog.
# Run as Administrator. A reboot is required after the reset.

[CmdletBinding()]
param(
    [switch]$NoReset
)

$ErrorActionPreference = "Stop"

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script as Administrator."
    }
}

function Set-DwordValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int]$Value
    )

    if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value
    } else {
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value | Out-Null
    }
}

function Set-BinaryValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][byte[]]$Value
    )

    if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
    } else {
        New-ItemProperty -Path $Path -Name $Name -PropertyType Binary -Value $Value | Out-Null
    }
}

function Set-ExpandStringValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )

    if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
    } else {
        New-ItemProperty -Path $Path -Name $Name -PropertyType ExpandString -Value $Value | Out-Null
    }
}

function Set-TcpipEntry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][int]$SocketType,
        [Parameter(Mandatory=$true)][int]$Protocol,
        [Parameter(Mandatory=$true)][int]$ProtocolMaxOffset,
        [Parameter(Mandatory=$true)][int]$MessageSize,
        [Parameter(Mandatory=$true)][string]$ProtocolName,
        [Parameter(Mandatory=$true)][int]$ProviderFlags,
        [Parameter(Mandatory=$true)][int]$ServiceFlags
    )

    New-Item -Path $Path -Force | Out-Null
    Set-DwordValue $Path "Version" 2
    Set-DwordValue $Path "AddressFamily" 2
    Set-DwordValue $Path "MaxSockAddrLength" 16
    Set-DwordValue $Path "MinSockAddrLength" 16
    Set-DwordValue $Path "SocketType" $SocketType
    Set-DwordValue $Path "Protocol" $Protocol
    Set-DwordValue $Path "ProtocolMaxOffset" $ProtocolMaxOffset
    Set-DwordValue $Path "ByteOrder" 0
    Set-DwordValue $Path "MessageSize" $MessageSize
    Set-ExpandStringValue $Path "szProtocol" $ProtocolName
    Set-DwordValue $Path "ProviderFlags" $ProviderFlags
    Set-DwordValue $Path "ServiceFlags" $ServiceFlags
}

Assert-Admin

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $env:SystemDrive "winsock-ipv4-provider-backup-$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "Backup directory: $backupDir"
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Winsock" (Join-Path $backupDir "tcpip-winsock-before.reg") /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Winsock\Setup Migration" (Join-Path $backupDir "winsock-setup-migration-before.reg") /y | Out-Null
reg export "HKLM\SYSTEM\CurrentControlSet\Services\WinSock2\Parameters\Protocol_Catalog9" (Join-Path $backupDir "winsock2-protocol-catalog9-before.reg") /y | Out-Null

$tcpipWinsock = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Winsock"
$setupMigration = "HKLM:\SYSTEM\CurrentControlSet\Services\Winsock\Setup Migration"
$providers = Join-Path $setupMigration "Providers"

$tcpipGuid = [byte[]](0xA0,0x1A,0x0F,0xE7,0x8B,0xAB,0xCF,0x11,0x8C,0xA3,0x00,0x80,0x5F,0x48,0xA1,0x92)
$mapping = [byte[]](
    0x08,0x00,0x00,0x00,0x03,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x06,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x06,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x11,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x11,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,
    0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00
)

New-Item -Path $tcpipWinsock -Force | Out-Null
Set-DwordValue $tcpipWinsock "UseDelayedAcceptance" 0
Set-DwordValue $tcpipWinsock "MaxSockAddrLength" 16
Set-DwordValue $tcpipWinsock "MinSockAddrLength" 16
Set-ExpandStringValue $tcpipWinsock "HelperDllName" "%SystemRoot%\System32\wshtcpip.dll"
Set-BinaryValue $tcpipWinsock "ProviderGUID" $tcpipGuid
Set-DwordValue $tcpipWinsock "OfflineCapable" 1
Set-BinaryValue $tcpipWinsock "Mapping" $mapping

Set-TcpipEntry (Join-Path $tcpipWinsock "0") 1 6 0 0 "@%SystemRoot%\System32\mswsock.dll,-60100" 8 0x20066
Set-TcpipEntry (Join-Path $tcpipWinsock "1") 2 17 0 0xfff7 "@%SystemRoot%\System32\mswsock.dll,-60101" 8 0x20609
Set-TcpipEntry (Join-Path $tcpipWinsock "2") 3 0 0xff 0x8000 "@%SystemRoot%\System32\mswsock.dll,-60102" 0xc 0x20609

New-Item -Path $providers -Force | Out-Null
New-Item -Path (Join-Path $providers "Tcpip") -Force | Out-Null
Set-ItemProperty -Path $setupMigration -Name "Provider List" -Type MultiString -Value @("Tcpip","Tcpip6","afunix","Psched","vmbus","RFCOMM")
Set-BinaryValue (Join-Path $providers "Tcpip") "WinSock 2.0 Provider ID" $tcpipGuid

Write-Host ""
Write-Host "IPv4 Winsock provider source repaired."

if (-not $NoReset) {
    Write-Host "Resetting Winsock catalog..."
    netsh winsock reset
    Write-Host ""
    Write-Host "Catalog check:"
    netsh winsock show catalog | Select-String -Pattern "MSAFD Tcpip \[TCP/IP\]|MSAFD Tcpip \[UDP/IP\]|MSAFD Tcpip \[RAW/IP\]|MSAFD Tcpip \[TCP/IPv6\]"
    Write-Host ""
    Write-Host "Done. Reboot Windows now."
} else {
    Write-Host "NoReset was specified. Run 'netsh winsock reset' and reboot later."
}
