<###############################################################
 ###############################################################
 # Copyright (C) 2021 Cisco Systems Inc. All rights reserved.  # 
 ###############################################################
 ###############################################################>
 
 
<#

.SYNOPSIS
	This script allows the user to create/modify/clear LDAP group

.DESCRIPTION
	This script allows the user to create/modify/clear LDAP group
	
.PARAMETER CsvFilePath
	CSV file path. CSV should contain IP, UserName, Password columns and IP : valid IP address of IMC server, Username : UserName of IMC Server, Password : plaintext password of IMC Server
	
.PARAMETER GroupId	
	LDAP group ID -- You can use  Get-ImcLdapGroupMap cmdlet to find exact Group ID
	
.PARAMETER Domain
	Unique domain that need to be configured to group ID
	
.PARAMETER Name
	Unique Name of Group
	
.PARAMETER Role
	Valid values for Role: admin, read-only, user 
	
.EXAMPLE
	.\IMC_LDAP_GrpConfig.ps1 -GroupId 1 -AdminAction clear

.EXAMPLE
	.\IMC_LDAP_GrpConfig.ps1 -CsvFilePath .\myucscred.csv -GroupId 1 -Domain testing28.com -Name 'LiveTest' -Role admin
	-CsvFilePath -- CSV file path. CSV should contain IP, UserName, Password columns and IP : valid IP address of IMC server, Username : UserName of IMC Server, Password : plaintext password of IMC Server
	-GroupId -- LDAP group ID -- You can use  Get-ImcLdapGroupMap cmdlet to find exact Group ID
	-Domain -- Unique domain that need to be configured to group ID
	-Name -- Unique Name of Group
	-Role -- Valid values for Role: admin,read-only,user 	 

.EXAMPLE
	.\IMC_LDAP_GrpConfig.ps1 -GroupId 1 -Domain testing.com -Name 'Test' -Role user
	-GroupId -- LDAP group ID -- You can use  Get-ImcLdapGroupMap cmdlet to find exact Group ID
	-Domain -- Unique domain that need to be configured to group ID
	-Name -- Unique Name of Group
	-Role -- Valid values for Role: admin,read-only,user 
	User need to provide IP address of IMC Server when prompted and credentials for same.

.NOTES
	Author: Amol Mhetre
	Email: amhetre@cisco.com
	Company: Cisco Systems, Inc.
	Version: v0.1.01
	Date: 30/04/2021
	Disclaimer: Code provided as-is.  No warranty implied or included.  This code is for example use only and not for production

#>

#Command Line Parameters
param(	
	[Parameter(mandatory = $false)]
	[string]$CsvFilePath, # Path to saved IMC Credentials in csv  
	[Parameter(mandatory = $true)]
	[int]$GroupId,
	[Parameter(mandatory = $true)]
	[string]$Role, # Valid values for Role: admin,read-only,user 	 	
	[Parameter(mandatory = $false)]
	[string]$Domain,
	[Parameter(mandatory = $false)]
	[string]$Name,		
	[Parameter(mandatory = $false)]
	[string]$AdminAction			# Valid value for AdminAction : clear	
)

function VerifyPowershellVersion {
	try {
		Write-Output "Checking for proper PowerShell version"
		$PSVersion = $psversiontable.psversion
		$PSMinimum = $PSVersion.Major
		Write-Output "You are running PowerShell version $PSVersion"
		if ($PSMinimum -ge "3") {
			Write-Output "	Your version of PowerShell is valid for this script."
			Write-Output ""
		}
		else {
			Write-Error "	This script requires PowerShell version 3 or above. Please update your system and try again."
			Write-Output "			Exiting..."
			exit
		}
	}
	catch {
		throw;
	}
}

function LoadIMCModule {
	try {
		#Load the IMC PowerTool
		Write-Output "Checking Cisco Powertool IMC Module"
		$Modules = Get-Module
		if ( -not ($Modules -like "Cisco.IMC")) {
			Write-Output "	Importing Module: Cisco Powertool IMC Module"
			Import-Module Cisco.IMC
			$Modules = Get-Module
			if ( -not ($Modules -like "Cisco.IMC")) {
				Write-Output ""
				Write-Error "	Cisco Powertool IMC Module did not load.  Please correct his issue and try again"
				Write-Output "		Exiting..."
				exit
			}
			else {
				$PTVersion = (Get-Module Cisco.IMC).Version
				Write-Output "		Cisco Powertool IMC module version $PTVersion is now Loaded"
			}
		}
		else {
			$PTVersion = (Get-Module Cisco.IMC).Version
			Write-Output "	Cisco Powertool IMC module version $PTVersion is already Loaded"
		}
	}
	catch {
		throw;
	}
}

function ClearGroup {
	try {
		Write-Output "	Clearing Group values for $GroupId"
		$clear = Set-ImcLdapGroupMap -LdapGroupMap $GroupId -AdminAction $AdminAction -Force -ErrorAction stop
		Write-Output "	Clearing Group values completed."
	}
	catch {
		throw;
	}
}

function ModifyGroup {
	try {
		Write-Output "	Modifying Group values for $GroupId"
		$ModifyResult = Set-ImcLdapGroupMap -LdapGroupMap $GroupId -Domain $domain -Name $Name -Role $Role -Force -ErrorAction stop
		Write-Output "	Modifying Group values completed."
	}
	catch {
		throw;
	}
}

function CreateGroup {
	try {
		Write-Output "	Creating Group values for $GroupId"
		$AddResult = Add-ImcLdapGroupMap -Id $GroupId -Domain $Domain -Name $Name -Role $Role -ErrorAction stop
		Write-Output "	Creating Group values completed."
	}
	catch {
		throw;
	}
}

function ProcessGroup {
	try {
		Write-Output "Verifying IMC connection"
		$myCon = (Get-UcsPSSession | measure).Count
		if ($myCon -eq 0) {
			Write-Output ""
			Write-Output "You are not logged into any IMC systems"
			Write-Output "	Exiting..."						
			exit
		}
		
		if (-not ([string]::IsNullOrEmpty($AdminAction))) {
			ClearGroup				
		}
		
		Write-Output "Fetching LDAP Group"
		$ImcGroup = Get-ImcLdapGroupMap -Id $GroupId
		
		if (-not ([string]::IsNullOrEmpty($ImcGroup.Name))) {
			ModifyGroup
		}
		elseif ([string]::IsNullOrEmpty($AdminAction)) {
			CreateGroup
		}
	}
	catch {
		throw;
	}
}

function ProcessCSV {
	try {
		if ($CsvFilePath) {
			Write-Output "Importing csv file on given path $CsvFilePath"
			
			$CsvFile = import-csv $CsvFilePath
			
			foreach ($item in $CsvFile) {
				$IP = $item.IP
				$Username = $item.Username
				$Password = ConvertTo-SecureString $item.Password -AsPlainText -Force
				$cred = New-Object System.Management.Automation.PsCredential ($Username, $Password)

				Write-Output "Connecting to IMC $IP"
				
				$Conn = Connect-Imc $IP -Credential $cred -ErrorAction Stop
		
				if ($null -eq $Conn) {
					Write-Error "	Unsuccessful login to IMC $IP" 
				}
				else {
					Write-Output "	Successful login to IMC $IP"       
					ProcessGroup				
				}
			}
		}
		else {
			Write-Output ""
			$IP = Read-Host "Enter IMC system IP or Hostname"
			$cred = Get-Credential -Message "Enter IMC credential for $IP"			
			
			Write-Output "Connecting to IMC $IP"

			$Conn = Connect-Imc $IP -Credential $cred -ErrorAction Stop
		
			if ($null -eq $Conn) {
				Write-Error "	Unsuccessful login to IMC $IP" 
			}
			else {
				Write-Output "	Successful login to IMC $IP"       
				ProcessGroup				
			}
		}
	}
	catch {
		Write-Output "Disconnecting IMC"
		$Disconnect = Disconnect-Imc
		throw;
	}
}

# Script start from here
Write-Output ""
Write-Output "LDAP Group Configuration started"
Write-Output ""

VerifyPowershellVersion
LoadIMCModule

#Check to see if credential files exists
if ($CsvFilePath) {
	if ((Test-Path $CsvFilePath) -eq $false) {
		Write-Error "\n Your credentials file $CsvFilePath does not exist in the script directory"
		Write-Output "	Exiting..."
		exit
	}
}
	

$MultipleConnection = Set-UcsPowerToolConfiguration -SupportMultipleDefaultUcs $true -Force -ErrorAction stop

ProcessCSV

#Disconnect from IMC(s)
Write-Output "Disconnecting IMC"
$Disconnect = Disconnect-Imc

#Exit the Script
Write-Output ""
Write-Output "Script Complete"
exit

