<#
.SYNOPSIS
    DHCP configuration to support UEFI and legacy BIOS imaging via WDS.
.DESCRIPTION	
	This is accomplished by creating vendor classes and DHCP policies to identify clients requesting PXE service.
	When clients request PXE service, the vendor class (BIOS x86/x64, UEFI x64, or UEFI x86) is evaluated. The client
	is then directed to the appropriate NBP, hosted on the PXE/WDS server. This allows a single PXE server to support
	modern and legacy hardware.
	.
	Prerequisites:
	Windows Server 2012 or newer
	Existing PXE/WDS server
.PARAMETER dhcpserver
    Hostname of the target DHCP server.
.PARAMETER pxeserver
    Target site's PXE/WDS server, preferably formatted as an IP address.
.PARAMETER scope
	Scope ID of the targeted DHCP scope, formatted as an IP address.
	If you intend to apply the new policies at server-level, provide scope value "0.0.0.0".
.EXAMPLE
    C:\PS> 
    <Description of example>
.NOTES
    Author: Kyle Brewer
    Date:   3 November, 2016
#>

# CLI Input parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1)]
	[string]$dhcpserver,

	[Parameter(Mandatory=$True,Position=2)]
	[string]$pxeserver,

	[Parameter(Mandatory=$True,Position=3)]
	[ValidateScript({$_ -match [IPAddress]$_ })]
	[IPAddress]$scope
	
)

# Define variables
#$dhcpserver = ""
# (066) PXE server value should be defined as an IP address.
#$pxeserver = ""
# (Option 067) UEFI x64 NBP value should be defined by the relative path to the UEFI NBP file. ex.: SMSBoot\x64\wdsmgfw.efi
$uefinbpx64 = "SMSBoot\x64\wdsmgfw.efi"
# (Option 067) UEFI x86 NBP value should be defined by the relative path to the UEFI NBP file. ex.: SMSBoot\x86\wdsmgfw.efi
$uefinbpx86 = "SMSBoot\x86\wdsmgfw.efi"
# (Option 067) BIOS NBP value should be defined by the relative path to the BIOS NBP file. ex.: SMSBoot\x86\wdsnbp.com
$biosnbp = "SMSBoot\x86\wdsnbp.com"

# Functions
# Remove old DHCP option 066 and 067 values, as they have been replaced by options within the new policies.
function removeoldoptions {
	Write-Host "Removing old value of DHCP options 066 and 067 in affected scope."
	Remove-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 066 -Confirm
	Remove-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 067 -Confirm

}

# Create DHCP option 060 - does not exist by default.
# We create this option at server-level, and assign it to specific policies below.
function addoption060 {
	Write-Host "Creating DHCP option 060."
	Add-DhcpServerv4OptionDefinition -ComputerName "$dhcpserver" -Name "PXEClient" -Description "PXEClient" -OptionId 060 -Type String

}

# Define vendor classes.
function addclasses {
	Write-Host "Defining vendor classes."
	Add-DhcpServerv4Class -ComputerName "$dhcpserver" -Type Vendor -Name "PXEClient (UEFI x64)" -Description "PXEClient (UEFI x64)" -Data "PXEClient:Arch:00007"
	Add-DhcpServerv4Class -ComputerName "$dhcpserver" -Type Vendor -Name "PXEClient (UEFI x86)" -Description "PXEClient (UEFI x86)" -Data "PXEClient:Arch:00006"
	Add-DhcpServerv4Class -ComputerName "$dhcpserver" -Type Vendor -Name "PXEClient (BIOS x86 and x64)" -Description "PXEClient (BIOS x86 and x64)" -Data "PXEClient:Arch:00000"

}

# Define DHCP policies.
# Note that we do not enable these policies, as they are not yet complete.
function addpolicies {
	Write-Host "Defining DHCP policies."
	Add-DhcpServerv4Policy -ComputerName "$dhcpserver" -Name "PXEClient (UEFI x64)" -Description "Define NBP for UEFI x64 clients" -Enabled $False -ScopeId "$scope" -ProcessingOrder "1" -Condition "OR" -VendorClass EQ,"PXEClient (UEFI x64)*"
	Add-DhcpServerv4Policy -ComputerName "$dhcpserver" -Name "PXEClient (UEFI x86)" -Description "Define NBP for UEFI x86 clients" -Enabled $False -ScopeId "$scope" -ProcessingOrder "2" -Condition "OR" -VendorClass EQ,"PXEClient (UEFI x86)*"
	Add-DhcpServerv4Policy -ComputerName "$dhcpserver" -Name "PXEClient (BIOS x86 and x64)" -Description "Define NBP for BIOS x86 and x64 clients" -Enabled $False -ScopeId "$scope" -ProcessingOrder "3" -Condition "OR" -VendorClass EQ,"PXEClient (BIOS x86 and x64)*"

}

# Define server-level options 060, 066, and 067 for UEFI x64 DHCP policy.
function setoptionvalue_server_uefix64 {
	Write-Host "Defining DHCP options 060, 066, and 067 for UEFI x64 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 060 -Value "PXEClient" -PolicyName "PXEClient (UEFI x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (UEFI x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 067 -Value "$uefinbpx64" -PolicyName "PXEClient (UEFI x64)"

}

# Define scope-level options 060, 066, and 067 for UEFI x64 DHCP policy.
function setoptionvalue_scope_uefix64 {
	Write-Host "Defining DHCP options 060, 066, and 067 for UEFI x64 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 060 -Value "PXEClient" -PolicyName "PXEClient (UEFI x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (UEFI x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 067 -Value "$uefinbpx64" -PolicyName "PXEClient (UEFI x64)"

}

# Define server-level DHCP options 060, 066, and 067 for UEFI x86 DHCP policy.
function setoptionvalue_server_uefix86 {
	Write-Host "Defining DHCP options 060, 066, and 067 for UEFI x86 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 060 -Value "PXEClient" -PolicyName "PXEClient (UEFI x86)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (UEFI x86)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 067 -Value "$uefinbpx86" -PolicyName "PXEClient (UEFI x86)"

}

# Define scope-level DHCP options 060, 066, and 067 for UEFI x86 DHCP policy.
function setoptionvalue_scope_uefix86 {
	Write-Host "Defining DHCP options 060, 066, and 067 for UEFI x86 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 060 -Value "PXEClient" -PolicyName "PXEClient (UEFI x86)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (UEFI x86)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 067 -Value "$uefinbpx86" -PolicyName "PXEClient (UEFI x86)"

}

# Define server-level DHCP options 066 and 067 for BIOS DHCP policy.
# Note DHCP option 060 is NOT defined for BIOS clients.
function setoptionvalue_server_bios {
	Write-Host "Defining DHCP options 060, 066, and 067 for BIOS x86 and x64 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (BIOS x86 and x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -OptionId 067 -Value "$biosnbp" -PolicyName "PXEClient (BIOS x86 and x64)"

}

# Define scope-level DHCP options 066 and 067 for BIOS DHCP policy.
# Note DHCP option 060 is NOT defined for BIOS clients.
function setoptionvalue_scope_bios {
	Write-Host "Defining DHCP options 060, 066, and 067 for BIOS x86 and x64 DHCP policy."
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 066 -Value "$pxeserver" -PolicyName "PXEClient (BIOS x86 and x64)"
	Set-DhcpServerv4OptionValue -ComputerName "$dhcpserver" -ScopeId "$scope" -OptionId 067 -Value "$biosnbp" -PolicyName "PXEClient (BIOS x86 and x64)"

}

# Enable new DHCP policies.
function enablepolicies {
	Write-Host "Enabling new DHCP Policies."
	Set-DhcpServerv4Policy -ComputerName "$dhcpserver" -ScopeId "$scope" -Name "PXEClient (UEFI x64)" -Enabled $True
	Set-DhcpServerv4Policy -ComputerName "$dhcpserver" -ScopeId "$scope" -Name "PXEClient (UEFI x86)" -Enabled $True
	Set-DhcpServerv4Policy -ComputerName "$dhcpserver" -ScopeId "$scope" -Name "PXEClient (BIOS x86 and x64)" -Enabled $True

}

# Main
# The part where stuff happens!
# Evaluate scope variable and output plan.
if ($scope -eq '0.0.0.0') {

	Write-Host "`nDHCP server:`t$dhcpserver`nPXE server:`t$pxeserver`nScope:`t`tserver-level`n"

}

else {

	Write-Host "`nDHCP server:`t$dhcpserver`nPXE server:`t$pxeserver`nScope:`t`t$scope`n"

}

# Prompt operator to confirm.
$confirmation = Read-Host "Continue? [y/n]"

# Affirmative. Continue.
if ($confirmation -eq 'y') {

	# Run server-level functions.
	if ($scope -eq '0.0.0.0') {

#		removeoldoptions
		addoption060
		addclasses
		addpolicies
		setoptionvalue_server_uefix64
		setoptionvalue_server_uefix86
		setoptionvalue_server_bios
#		enablepolicies

	}

	# Run scope-level functions.
	else {

#		removeoldoptions
		addoption060
		addclasses
		addpolicies
		setoptionvalue_scope_uefix64
		setoptionvalue_scope_uefix86
		setoptionvalue_scope_bios
#		enablepolicies

	}

}

# Negative. Exit with no change.
else {

	Write-Host "`nExiting with no change.`n"
	exit

}