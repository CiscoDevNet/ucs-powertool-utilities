param(
[parameter(Mandatory=${true})][String]$Ucs,
    [parameter(Mandatory=${true})][String]$UcsOrg,
    [parameter(Mandatory=${true})][String]$UcsSpTemplate,
    [parameter(Mandatory=${true})][String]$UcsBladeDn,
    [parameter(Mandatory=${true})][string]$Hostname
)

# Global Variables
$ImageFileName = 'VMware-ESXi-6.7.0-9484548-Custom-Cisco-6.7.0.2.iso'
$ImagePath = '/'
$RemoteIpAddress = '10.105.219.102'
$UserId = 'root'
$Password = 'Tpi12345'
$RemotePort = '80'
$DeviceType = 'cdd'
$Protocol = 'http'
$BootPolicyName = 'TestBootPolicy'
$vMediaPolicyName = 'TestvMediaPolicy'

$Global:LogFile = ".\AutomateUCSLog.log"
if ([System.IO.File]::Exists($Global:LogFile) -eq $false) {
	$null = New-Item -Path $Global:LogFile -ItemType File -Force
}

function Write-InfoLog {
	[CmdletBinding()]
	param ( 
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[String] $Message
	)

	"Info: $(Get-Date -Format g): $Message" | Out-File $Global:LogFile -Append
	Write-Host "Info: $Message"
}

function Write-ErrorLog {
	[CmdletBinding()] 
	param ( 
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[object] $Message
	)
        
	"Error: $(Get-Date -Format g):" | Out-File $Global:LogFile -Append
	$Message | Out-File $LogFile -Append 
	Write-Host "Error: $($Message)" -ForegroundColor Red
}

function Start-Countdown{

	Param(
		[INT]$Seconds = (Read-Host "Enter seconds to countdown from")
	)

	while ($seconds -ge 1){
	    Write-Progress -Activity "Sleep Timer Countdown" -SecondsRemaining $Seconds -Status "Time Remaining"
	    Start-Sleep -Seconds 1
	$Seconds --
	}
}

function VerifyPowershellVersion {
	try {
		Write-InfoLog "Checking for proper PowerShell version"
		$PSVersion = $psversiontable.psversion
		$PSMinimum = $PSVersion.Major
		Write-InfoLog "You are running PowerShell version $PSVersion"
		if ($PSMinimum -ge "3") {
			Write-InfoLog "Your version of PowerShell is valid for this script."
			
		}
		else {
			Write-ErrorLog "This script requires PowerShell version 3 or above. Please update your system and try again."
			Write-InfoLog "Exiting..."
			exit
		}
	}
	catch {
		throw;
	}
}

function LoadUCSMModule {
	try {
		#Load the UCSM PowerTool
		Write-InfoLog "Checking Cisco Powertool UCSM Module"
		$Modules = Get-Module
		if ( -not ($Modules -like "Cisco.UCSManager")) {
			Write-InfoLog "Importing Module: Cisco Powertool UCSM Module"
			Import-Module Cisco.UCSManager
			$Modules = Get-Module
			if ( -not ($Modules -like "Cisco.UCSManager")) {
				
				Write-ErrorLog "Cisco Powertool UCSM Module did not load.  Please use command : Install-Module -Name Cisco.UCSManager"
				Write-InfoLog "Exiting..."
				exit
			}
			else {
				$PTVersion = (Get-Module Cisco.UCSManager).Version
				Write-InfoLog "Cisco Powertool UCSM module version $PTVersion is now Loaded"
			}
		}
		else {
			$PTVersion = (Get-Module Cisco.UCSManager).Version
			Write-InfoLog "Cisco Powertool UCSM module version $PTVersion is already Loaded"
		}
	}
	catch {
		throw;
	}
}

function ConfigureMultipleUCS {
	try {
		$MultipleConnection = Set-UcsPowerToolConfiguration -SupportMultipleDefaultUcs $true -Force -ErrorAction stop
	}
	catch {
		throw;
	}
}

function CreateVMediaPolicy {
	param(	
		[Parameter(mandatory = $true)]
		[string]$ImageFileName,
		[Parameter(mandatory = $true)]
		[string]$ImagePath,
		[Parameter(mandatory = $true)]
		[string]$RemoteIpAddress,
		[Parameter(mandatory = $true)]
		[string]$UserId,
		[Parameter(mandatory = $true)]
		[string]$Password,
		[Parameter(mandatory = $true)]
		[string]$RemotePort,
		[Parameter(mandatory = $true)]
		[string]$DeviceType,
		[Parameter(mandatory = $true)]
		[string]$Protocol,
		[Parameter(mandatory = $true)]
		[Cisco.Ucs.Common.BaseHandle[]] $Ucs,
		[Parameter(mandatory = $true)]
		[Cisco.Ucsm.UcsmManagedObject]$TargetOrg,
		[Parameter(mandatory = $true)]
		[string]$vMediaPolicyName
	)
	try {
		
		Write-InfoLog "Creating VMedia Policy : $vMediaPolicyName" 
		
		Start-UcsTransaction -Ucs $Ucs
		
		$VMediaPolicy = $TargetOrg | Add-UcsVmediaPolicy -ModifyPresent  -Descr '' -Name $vMediaPolicyName -PolicyOwner 'local' -RetryOnMountFail 'yes' -Ucs $Ucs

		Write-InfoLog "ImageFileName: $ImageFileName  ImagePath: $ImagePath  RemoteIpAddress: $RemoteIpAddress  UserId: $UserId  Password: $Password RemotePort: $RemotePort DeviceType: $DeviceType Protocol: $Protocol"
		
		$VmediaMountEntry = $VMediaPolicy | Add-UcsVmediaMountEntry -ModifyPresent -AuthOption 'none' -Description '' -DeviceType $DeviceType -ImageFileName $ImageFileName -ImagePath $ImagePath -ImageNameVariable 'none' -MappingName 'cdd-http-VMedia' -MountProtocol $Protocol -Password $Password -RemapOnEject 'no' -RemoteIpAddress $RemoteIpAddress -RemotePort $RemotePort -UserId $UserId -Writable 'no'	-Ucs $Ucs
		
		Complete-UcsTransaction -Ucs $Ucs
		
		Write-InfoLog "Successfully created VMedia Policy : $vMediaPolicyName" 		
		
		
	}
	catch {
		Write-ErrorLog "Failed to Create VMedia Policy : $vMediaPolicyName" 
		Write-InfoLog "Disconnecting UCS"
		$Ucs = Disconnect-Ucs
		throw;
	}
}

function ModifyBootOrder
{
	param(	
		[Parameter(mandatory = $true)]
		[string]$BootPolicyName,
		[Parameter(mandatory = $true)]
		[Cisco.Ucs.Common.BaseHandle[]] $Ucs,
		[Parameter(mandatory = $true)]
		[Cisco.Ucsm.UcsmManagedObject]$TargetOrg
	)
	try {
		
		Write-InfoLog "Modifying boot order" 
		
		Start-UcsTransaction -Ucs $Ucs
		$mo = $TargetOrg | Add-UcsBootPolicy -ModifyPresent -Name $BootPolicyName -Ucs $Ucs
		#CIMC mounted vMedia : CD/DVD 
		$mo_1 = $mo | Add-UcsLsbootVirtualMedia -ModifyPresent -Access "read-only-remote-cimc" -LunId "0" -Order 1 -Ucs $Ucs
		#Local Device : Local CD/DVD
		$mo_2 = $mo | Add-UcsLsbootVirtualMedia -ModifyPresent -Access "read-only-local" -LunId "0" -Order 2 -Ucs $Ucs
		Complete-UcsTransaction -Ucs $Ucs
		
		Write-InfoLog "Modifying boot order completed" 
	}
	catch {
		Write-ErrorLog "Failed to modify boot order of boot policy : $BootPolicyName" 
		Write-InfoLog "Disconnecting UCS"
		$Ucs = Disconnect-Ucs
		throw;
	}
}             

function ModifyBootPolicyOfServiceProfile
{
	param(	
		[Parameter(mandatory = $true)]
		[string]$BootPolicyName,
		[Parameter(mandatory = $true)]
		[string]$SPName,
		[Parameter(mandatory = $true)]
		[Cisco.Ucs.Common.BaseHandle[]] $Ucs,
		[Parameter(mandatory = $true)]
		[Cisco.Ucsm.UcsmManagedObject]$TargetOrg,
		[Parameter(mandatory = $true)]
		[string]$vMediaPolicyName
	)
	try {
		
		Write-InfoLog "Updating Service Profile template : $SPName with Boot Policy : $BootPolicyName and  vMedia Policy: $vMediaPolicyName" 
		
		$CheckBootPolicy = (Get-UcsBootPolicy -Name $BootPolicyName -Ucs $Ucs | measure).Count
		
		if ($CheckBootPolicy -eq 1) {
			$SP = $TargetOrg | Add-UcsServiceProfile -Name $SPName -ModifyPresent -BootPolicyName $BootPolicyName -VmediaPolicyName $vMediaPolicyName -Ucs $Ucs
			Write-InfoLog "Updating Service Profile template completed" 
		}
		else
		{
			Write-ErrorLog "Boot policy : $BootPolicyName not found" 
		}
		
	}
	catch {
		Write-ErrorLog "Failed to update Service Profile template" 
		Write-InfoLog "Disconnecting UCS"
		$Ucs = Disconnect-Ucs
		throw;
	}
	
}

#####################**************************************#####################

try {
	
	VerifyPowershellVersion

	LoadUCSMModule

	ConfigureMultipleUCS

	# Get UCS PS Connection
	Write-InfoLog "UCS: Checking for current UCS Connection for UCS Domain: '$($ucs)'"
	$UcsConn = Get-UcsPSSession | where { $_.Name -eq $Ucs }
	if ( ($UcsConn).Name -ne $Ucs ) {
		Write-InfoLog "UCS: UCS Connection: '$($ucs)' is not connected"
		Write-InfoLog "UCS: Enter UCS Credentials"
		$cred = Get-Credential
		$UcsConn = connect-ucs $Ucs -Credential $cred
	}

	# Get UCS org in connected UCS session
	Write-InfoLog "UCS: Checking for UCS Org: '$($UcsOrg)' on UCS Domain: '$($ucs)'"
	$TargetOrg = Get-UcsOrg -Name $UcsOrg
	if ( $TargetOrg -eq $null ) {
		Write-InfoLog "UCS: UCS Organization: '$($TargetOrg)' is not present"
		exit
	}
	
	 # Get UCS Blade on connected UCS session, check availability of UCS Blade
    Write-InfoLog "UCS: Checking availability on UCS Blade: '$($UcsBladeDn)' on UCS Domain: '$($ucs)'"
    $TargetBlade = Get-UcsBlade -dn $UcsBladeDn 
    if ( $TargetBlade -eq $null ) {
        Write-InfoLog "UCS: UCS Blade: '$($TargetBlade.Dn)' is not present"
        exit
    } elseif ( ($TargetBlade).Association -ne "none" -and ($TargetBlade).Availability -ne "available" ) {
        Write-InfoLog "UCS: UCS Blade: '$($TargetBlade.Dn)' is not available"
        exit
    }
	
	# Check to see if SP is already created on connected UCS Session
    Write-InfoLog "UCS: Checking to see if SP: '$($hostname)' exists on UCS Domain: '$($ucs)'"
    $SpToCreate = $TargetOrg | Get-UcsServiceProfile -Name $Hostname -LimitScope
    if ( $SpToCreate -ne $null ) {
        Write-InfoLog "UCS: UCS Service Profile: '$($Hostname)' is already created"
        exit
    }

	# Get UCS SP template on connected UCS session
    Write-InfoLog "UCS: Checking for UCS Service Profile: '$($UcsSpTemplate)' on UCS Domain: '$($ucs)'"
    $TargetSpTemplate = $TargetOrg | Get-UcsServiceProfile -Name $UcsSpTemplate -ucs $UcsConn -LimitScope
    if ( $TargetSpTemplate -eq $null ) {
        Write-InfoLog "UCS: UCS Service Profile Template: '$($TargetSpTemplate.Dn)' is not present"
        exit
    } elseif ( ($TargetSpTemplate).Type -notlike "*-template*" ) {
        Write-InfoLog "UCS: UCS Service Profile: '$($TargetSpTemplate.Dn)' is not a service profile template"
        exit
    }  
	
	#Create vMedia Policy
	$VMediaPolicy = CreateVMediaPolicy -vMediaPolicyName $vMediaPolicyName -ImageFileName $ImageFileName -ImagePath $ImagePath -RemoteIpAddress $RemoteIpAddress -UserId $UserId -Password $Password -RemotePort $RemotePort -DeviceType $DeviceType -Protocol $Protocol -Ucs $UcsConn -TargetOrg $TargetOrg
	
	#Modify Boot order using boot policy
	$BootOrder = ModifyBootOrder -BootPolicyName $BootPolicyName -Ucs $UcsConn -TargetOrg $TargetOrg
		
	#Associate boot policy to ServiceProfile Template
	$AssociateBootPolicy = ModifyBootPolicyOfServiceProfile  -BootPolicyName $BootPolicyName -vMediaPolicyName $vMediaPolicyName -SPName $TargetSpTemplate.name -Ucs $UcsConn -TargetOrg $TargetOrg
	

	# Create New UCS SP from Template
    Write-InfoLog "UCS: Creating new SP: '$($hostname)' from UCS SP Template: '$($TargetSpTemplate.Dn)' on UCS Domain: '$($ucs)'"
    $NewSp = Add-UcsServiceProfile -org $TargetOrg -Ucs $UcsConn -SrcTemplName ($TargetSpTemplate).Name -Name $Hostname 
    $devnull = $NewSp | Set-UcsServerPower -ucs $UcsConn -State "down" -Force
	
	
	# Associate Service Profile to Blade
   	Write-InfoLog "UCS: Associating new UCS SP: '$($NewSp.Name)' to UCS Blade: '$($TargetBlade.Dn)' on UCS Domain: '$($Ucs)'"
    $devnull = Associate-UcsServiceProfile -ucs $UcsConn -ServiceProfile $NewSp.name -Blade $TargetBlade -Force


	# Monitor UCS SP Associate for completion
	Write-InfoLog "UCS: Waiting for UCS SP: '$($NewSp.name)' to complete SP association process on UCS Domain: '$($Ucs)'"
    Write-InfoLog "Sleeping 3 minutes"
    Start-Countdown -seconds 180

    $i = 0

		do {
			if ( (Get-UcsServiceProfile -Dn $NewSp.Dn).AssocState -ieq "associated" )
			{
				break
			} else {
                Write-InfoLog "Sleeping 30 seconds"
    			Start-Countdown -seconds 30
                $i++
                Write-InfoLog "UCS: RETRY $($i): Checking for UCS SP: '$($NewSp.name)' to complete SP association process on UCS Domain: '$($Ucs)'"
                
            }		
        } until ( (Get-UcsServiceProfile -Dn $NewSp.Dn).AssocState -ieq "associated" -or $i -eq 24 )

    if ( $i -eq 24 ) {
    	Write-InfoLog "UCS: Association process of UCS SP: '$($NewSp.name)' failed on UCS Domain: '$($Ucs)'"	
        exit
    } 
    
   	Write-InfoLog "UCS: Association process of UCS SP: '$($NewSp.name)' completed on UCS Domain: '$($Ucs)'"	
	
	
	# Set SP Power State to Up		
	Write-Host "UCS: Setting Desired Power State to 'up' of Service Profile: '$($NewSp.name)' on UCS Domain: '$($Ucs)'"
	$PowerSpOn = $NewSp | Set-UcsServerPower -ucs $UcsConn -State "up" -Force
	
	# Reset Blade server
	if ( $TargetBlade -ne $null ) {
		Write-InfoLog "Resetting Blade Server : $UcsBladeDn"
		$ResetBlade = $TargetBlade | Reset-UcsServer -Force
	}
}
catch {
	Write-ErrorLog "Failed Automate UCS" 
	Write-InfoLog "Disconnecting UCS"
	$Ucs = Disconnect-Ucs
	throw;
}


