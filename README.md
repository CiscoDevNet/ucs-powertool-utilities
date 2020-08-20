# Intersight Managed Mode (IMM) compatibility checker

This script validates that a UCS domain meets the minimum requirements for Intersight Managed Mode (IMM). It checks:
* Fabric Interconnect model and firmware version
* Chassis model and firmware version
* Chassis IOM model and firmware version
* Blade and rack server model and firmware version
* Adapter model and firmware version
* Rack server connectivity method
* Rack server IMC connectivity method

**Be sure to check this repository for updates as the minimum requirements for IMM are subject to change**. Make sure you have the latest version of all files in this repository before running.

## Operation

You can run the this script as a Docker container by following the instructions [here](DOCKER.md) or use the following instructions to run it using Powershell for Windows or Powershell Core.

### Minimum requirements

You'll need Powershell for Windows 5.0 or later *or* Powershell Core 7.0 or later. Install the Cisco PowerTool module from PSGallery:

```powershell
Install-Module Cisco.UCSManager
```

### Running the script

To run the compatibility checker, set three environment variables:

`UCS_HOST`: The virtual IP (VIP) or DNS name for UCS Manager.

`UCS_USERNAME`: Your UCS Manager username.

`UCS_PASSWORD`: Your UCS Manager password.

If those three environment variables are not properly set, you will be prompted for that information at runtime.

Simply type the following command and a progress bar will keep you informed of the script status.

```powershell
./imm-compatibility-checker.ps1
```

## Output

Whether you run the script natively or through Docker, it will produce a file (`log.csv`) listing every component analyzed and the result of the analysis. Any item whose `Compatible` column is not marked as `TRUE` must be remediated prior to attempting to migrate to IMM.

Each hardware component will be identified by its Dn (distinguished name) and serial number. Each software components will be identified by the hardware on which it resides.
