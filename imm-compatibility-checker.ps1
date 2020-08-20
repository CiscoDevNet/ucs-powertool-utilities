<#
.SYNOPSIS
    Inspect Cisco UCS for compatibility with Intersight Manged Mode (IMM).
.DESCRIPTION
    This script compares a UCS environment against minimum requirements for IMM
    compatibility specified in separate JSON config files.
.INPUTS
    None
.OUTPUTS
     A CSV file named incompatible.csv contains a list of elements that do not
     meet the minimum requirements for IMM.
.NOTES
    Version:        0.1
    Authors:        Doron Chosnek
                    Brandon Beck
    Creation Date:  August 2020
    Purpose/Change: Initial script development
#>

# required to enable Verbose output
[cmdletbinding()] param()


<# =========================================================================
   GLOBALS
   ------------------------------------------------------------------------- #>
$script:configFilePath = './config'
$script:outputCsvFilename = 'incompatible.csv'


<# =========================================================================
   CLASS DEFINITIONS
   ------------------------------------------------------------------------- #>

# Class representing an individual UCS Component like a blade or adapter. This
# is a very simple class and a list of these elements will be used to populate
# a CSV file of incompatible elements when this script concludes.
class UcsComponent {
    [string]$Dn
    [string]$Model
    [string]$Serial
    [string]$Desc
      
    # constructor for new instances of the Class
    UcsComponent(
        [string]$Dn,
        [string]$Model,
        [string]$Serial,
        [string]$Desc
    ) {
        $this.Dn = $Dn
        $this.Model = $Model
        $this.Serial = $Serial
        $this.Desc = $Desc
    }
}
      
# Class representing each test case
class CompatibilityTest {
    [string]$Description
    [string]$Cmdlet
    [string]$Attribute
    [string]$Operation
    [string]$Value
    [bool]$Pass
      
    # constructor for new instances of the Class
    CompatibilityTest(
        [string]$desc,
        [string]$cmd,
        [string]$attr,
        [string]$oper,
        [string]$value

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
        $rejects = @()
        $components = Invoke-Expression $this.Cmdlet

        if ($this.Operation -eq "or") {
            # check every element 
            foreach ($comp in $components) {
                # this component's "attribute" must match one of the specified values
                $flag = $false
                foreach ($val in $this.Value) {
                    if ($val[$this.Attribute] -eq $val) { $flag = $true }
                }
                # if component attribute does not match any of the values then
                # we add it to the list of incompatible components
                if (-not $flag) {
                    $rejects += [UcsComponent]::new(
                        $comp.Dn,
                        $comp.Model,
                        $comp.Serial,
                        $comp.Desc
                    )
                }
            }
        }
        else {
            throw "$($this.Operation) is an unsupported operation type."
        }
        return $rejects
    }

}

<# =========================================================================
   MAIN
   ------------------------------------------------------------------------- #>

$filenames = Get-ChildItem -Path $configFilePath -Filter '*.json'
Write-Verbose -Message "$($filenames.Count) config files located."

# create empty list of incompatibilities
$incompatible = @()

# initialize progress bar
Write-Progress -Id 1 -Activity "initial state" -Status " " -PercentComplete 20
Start-Sleep -Seconds 2

foreach ($fname in $filenames) {
    
    $all_checks = Get-Content -Raw $fname | ConvertFrom-Json
    $counter = 0
    foreach ($check in $all_checks) {
        
        # handle progress bar
        $activity = "Running tests from config file $($fname.Name)"
        $status = "Running check $($check.description)"
        $percent = $counter * 100 / $all_checks.Count
        Write-Progress -Id 1 -Activity $activity -Status $status -PercentComplete $percent
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
        $incompatible += $current.Compare()
    }
}

# create output
if ($incompatible.Count -eq 0) {
    Write-Host -ForegroundColor Green "No incompatibilities found!"
}
else {
    $message = "$($incompatible.Count) incompatibilities found and saved in $outputCsvFilename."
    Write-Host -ForegroundColor DarkRed $message
}
# if there are no incompatibilities, this will create an empty CSV
$incompatible | Export-Csv $outputCsvFilename -NoTypeInformation