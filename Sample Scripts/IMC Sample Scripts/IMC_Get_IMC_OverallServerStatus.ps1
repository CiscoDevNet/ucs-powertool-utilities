<###############################################################
 ###############################################################
 # Copyright (C) 2021 Cisco Systems Inc. All rights reserved.  # 
 ###############################################################
 ###############################################################>
 
 
<#

.SYNOPSIS
	This script allows the user to GET Overall server status

.DESCRIPTION
	This script allows the user to GET Overall server status	
	
.EXAMPLE
	.\IMC_Get_IMC_OverallServerStatus.ps1 -IP 1.1.1.1

.NOTES
	Author: Amol Mhetre
	Email: amhetre@cisco.com
	Company: Cisco Systems, Inc.
	Version: v0.1.01
	Date: 21/06/2021
	Disclaimer: Code provided as-is.  No warranty implied or included.  This code is for example use only and not for production

#>

#Command Line Parameters
param(	
	[Parameter(mandatory = $true)]
	[string]$IP
)

function VerifyPowershellVersion {
	try {
		$PSVersion = $psversiontable.psversion
		$PSMinimum = $PSVersion.Major
		if ($PSMinimum -le "3") {
			Write-Error "This script requires PowerShell version 3 or above. Please update your system and try again."
			Write-Output "Exiting..."
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
		
		$Modules = Get-Module
		if ( -not ($Modules -like "Cisco.IMC")) {
			Import-Module Cisco.IMC
			$Modules = Get-Module
			if ( -not ($Modules -like "Cisco.IMC")) {
				Write-Output ""
				Write-Error "Cisco Powertool IMC Module did not load.  Please correct his issue and try again"
				Write-Output "Exiting..."
				exit
			}
			else {
				$PTVersion = (Get-Module Cisco.IMC).Version
			}
		}
		else {
			$PTVersion = (Get-Module Cisco.IMC).Version
		}
	}
	catch {
		throw;
	}
}

function Get_OverallServerStatus {
	param(	
		[Parameter(mandatory = $true)]
		[string]$IP
	)
	try {
		$cred = Get-Credential -Message "Enter IMC credential for $IP"	

		$Conn = Connect-Imc $IP -Credential $cred -ErrorAction Stop
		
		if ($null -eq $Conn) {
			Write-Error "Unsuccessful login to IMC $IP" 
			exit
		}		
		
		$IndicatorLED = Get-ImcEquipmentIndicatorLed -Name 'LED_HLTH_STATUS'
		
		if ($null -ne $IndicatorLED) {
			$ledColor = $IndicatorLED.Color;
			$ledState = $IndicatorLED.OperState;
			
			if ($ledColor -eq 'GREEN') {
				if ($ledState -eq 'ON') {
					Write-Output "Good"
				} 
				else {
					#assume blinking
					Write-Output "Memory Test In Progress"
				}
			} 
			else {
				# #assume it's red/amber
				if ($ledState -eq 'ON') {
					Write-Output "Moderate Fault"
				} 
				else {
					#assume blinking
					Write-Output "Severe Fault"
				}
			}
		}
		
		#Disconnect from IMC(s)
		$Disconnect = Disconnect-Imc
	}
	catch {
		Write-Output "Disconnecting IMC"
		$Disconnect = Disconnect-Imc
		throw;
	}
}

# Script start from here
VerifyPowershellVersion
LoadIMCModule
Get_OverallServerStatus -IP $IP

#Exit the Script
exit

