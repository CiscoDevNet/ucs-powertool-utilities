<#
.SYNOPSIS
    Inspect Cisco UCS for compatibility with Intersight Manged Mode (IMM).
.DESCRIPTION
    This script compares a UCS environment against minimum requirements for IMM
    compatibility specified in separate JSON config files.
.INPUTS
    None
.OUTPUTS
     A CSV file containing every element inspected and whether or not it meets
     the IMM compatibility requirements.
.NOTES
    Version:        0.2
    Authors:        Doron Chosnek
                    Brandon Beck
    Creation Date:  August 2020
    Purpose/Change: Initial script development
#>

# required to enable Verbose output
[cmdletbinding()] param()


# =============================================================================
# GLOBALS
# -----------------------------------------------------------------------------
$script:configFilePath = './config'
$script:outputCsvFilename = 'log.csv'


# =============================================================================
# CLASS DEFINITIONS
# -----------------------------------------------------------------------------

# Class representing an individual UCS Component like a blade or adapter. This
# is a very simple class and a list of these elements will be used to populate
# a CSV file of incompatible elements when this script concludes.
class UcsComponent {
    [bool]$Compatible
    [string]$TestPerformed
    [string]$Dn
    [string]$Model
    [string]$Serial
    [string]$Desc
      
    # constructor for new instances of the Class
    UcsComponent(
        [bool]$Compatible,
        [string]$Dn,
        [string]$Model,
        [string]$Serial,
        [string]$Desc,
        [string]$TestName
    ) {
        $this.Compatible = $Compatible
        $this.Dn = $Dn
        $this.Model = $Model
        $this.Serial = $Serial
        $this.Desc = $Desc
        $this.TestPerformed = $TestName
    }
}
      
# Class representing each test case
class CompatibilityTest {
    [string]$Description
    [string]$Cmdlet
    [string]$Attribute
    [string]$Operation
    [string[]]$Value
    [bool]$Pass
      
    # constructor for new instances of the Class
    CompatibilityTest(
        [string]$desc,
        [string]$cmd,
        [string]$attr,
        [string]$oper,
        [string[]]$value

    ) {
        $this.Description = $desc
        $this.Cmdlet = $cmd
        $this.Attribute = $attr
        $this.Operation = $oper
        $this.Value = $value
        $this.Pass = $true
    }

    # this is the method that actually runs the compatibility check and returns
    # any components that do not meet the compatiblity checks
    [UcsComponent[]] Compare(){
        $results = @()
        $components = Invoke-Expression $this.Cmdlet

        if ($this.Operation -eq "or") {

            # check every element 
            foreach ($comp in $components) {
                # retrieve description
                if ('Model' -in $comp.PSobject.Properties.Name) {
                    $elemDesc = $script:EquipmentManDef | ? {$_.Dn -imatch "$($comp.Model)"} | Select -ExpandProperty Description
                } else {
                    $elemDesc = ''
                }

                # this component's "attribute" must match one of the specified values
                $flag = $false
                foreach ($val in $this.Value) {
                    if ($comp.($this.Attribute) -eq $val) { $flag = $true }
                }

                $results += [UcsComponent]::new(
                    $flag,
                    $comp.Dn,
                    $comp.Model,
                    $comp.Serial,
                    $elemDesc,
                    $this.Description
                )
            }
        }
        elseif ($this.Operation -match "ge") {
            $elemDesc = ''
            $model = ''
            $serial = ''
            # check every element
            foreach ($comp in $components) {
                # retrieve description
                if (-not ('Model' -in $comp.PSobject.Properties.Name)) {
                    # check if parent object contains a Model
                    $parent = $comp | Get-UcsParent
                    if ('Model' -in $parent.PSobject.Properties.Name) {
                        $elemDesc = $script:EquipmentManDef | ? {$_.Dn -imatch "$($parent.Model)"} | Select -ExpandProperty Description
                        $model = $parent.Model
                        $serial = $parent.serial
                    }
                }
                else {
                    $elemDesc = $script:EquipmentManDef | ? {$_.Dn -imatch "$($comp.Model)"} | Select -ExpandProperty Description
                    $model = $comp.Model
                    $serial = $comp.serial
                }

                # this component's "attribute" must match be >= "value"
                $flag = ([string]$comp.($this.Attribute) -ge [string]$this.Value)

                $results += [UcsComponent]::new(
                    $flag,
                    $comp.Dn,
                    $model,
                    $serial,
                    $elemDesc,
                    $this.Description
                )
            }
        }
        else {
            throw "$($this.Operation) is an unsupported operation type."
        }
        return $results
    }

}

# =============================================================================
# INITIALIZE
# -----------------------------------------------------------------------------

# Load UCS Powershell Modules
Import-Module Cisco.UcsManager

try {
    # Login to UCS Domain with supplied Envrionment variables if passed
    if ($env:UCS_HOST -and $env:UCS_USERNAME -and $env:UCS_PASSWORD) {
        $password = ConvertTo-SecureString "$env:UCS_PASSWORD" -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($env:UCS_USERNAME, $password)
        Write-Host "Connecting to UCS Manager..."
        Write-Progress -Activity "Running IMM compatibility checks" -Status "Starting" -PercentComplete 0
        $handle = Connect-Ucs -Name $env:UCS_HOST -Credential $credential -ErrorAction Stop
        #--- Checks that handle actually exists ---#
		Get-UcsStatus -Ucs $handle | Out-Null
    }
    else {
        # Connect interactively if required environment variables are not set
        Write-Host ""
        $hostname = Read-Host "UCSM Hostname or IP"
        $username = Read-Host "username"
        $password = Read-Host "password" -AsSecureString
        $credential = New-Object System.Management.Automation.PSCredential ($username, $password)
        Write-Host "Connecting to UCS Manager..."
        Write-Progress -Activity "Running IMM compatibility checks" -Status "Starting" -PercentComplete 0
        $handle = Connect-Ucs -Name $hostname -Credential $credential
        #--- Checks that handle actually exists ---#
		Get-UcsStatus -Ucs $handle | Out-Null
    }
}
catch [Exception] {
    $message = "Error connecting to UCS Domain using supplied credentials"
    Write-Host -ForegroundColor DarkRed $message
    $message | Out-File $outputCsvFilename
    Exit
}

Clear-Host
Write-Progress -Activity "Running IMM compatibility checks" -Status "Initializating" -PercentComplete 0

# retrieve all JSON files from the subdirectory
try {
    $filenames = Get-ChildItem -Path $configFilePath -Filter '*.json'
}
catch {
    Write-Host -ForegroundColor DarkRed "Could not locate any config files in the '$configFilePath' path."
}
Write-Verbose -Message "$($filenames.Count) config files located."

# create empty list of incompatibilities
$logList = @()

# get manufacturing definition of all UCS components so we can populate a
# detailed description for each component we encounter
$script:EquipmentManDef = Get-UcsEquipmentManufacturingDef


# =============================================================================
# MAIN
# -----------------------------------------------------------------------------

foreach ($fname in $filenames) {
    $all_checks = Get-Content -Raw $fname | ConvertFrom-Json
    $counter = 0
    foreach ($check in $all_checks) {
        
        # handle progress bar
        $activity = "Running tests from config file $($fname.Name)"
        $status = "Running check $($check.description)"
        $percent = $counter * 100 / $all_checks.Count
        Write-Progress -Activity $activity -Status $status -PercentComplete $percent
        $counter += 1
        
        # create a new check/test instance
        $current = [CompatibilityTest]::new(
            $check."description",
            $check."cmdlet",
            $check."attribute",
            $check."operation",
            $check."value"
            )
            
            # run the check/test operation
            $logList += $current.Compare()
        }
    }
    

# =============================================================================
# OUTPUT
# -----------------------------------------------------------------------------
# close the progress bar
Write-Progress -Activity " " -Status " " -PercentComplete 100

# create output
if ($filenames.Count -gt 0) {
    $failure_counter = ($logList | Where-Object { -not $_.Compatible }).Count
    if ($failure_counter -eq 0) {
        Write-Host -ForegroundColor Green "No incompatibilities found! Log saved as $outputCsvFilename"
    }
    else {
        $message = "$($failure_counter) incompatibilities found and saved in $outputCsvFilename."
        Write-Host -ForegroundColor DarkRed $message
    }
    # if there are no incompatibilities, this will create an empty CSV
    $logList | Export-Csv $outputCsvFilename -NoTypeInformation
}
else {
    Write-Host "No checks performed because no config files were found."
}

# Disconnect from UCS
$handle = Disconnect-Ucs
