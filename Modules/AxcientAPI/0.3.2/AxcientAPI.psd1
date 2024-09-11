#
# Module manifest for module 'AxcientAPI'
#
# Generated by: Adam Burley
#
# Generated on: 9/25/2024
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AxcientAPI.psm1'

# Version number of this module.
ModuleVersion = '0.3.2'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '823406e1-1b10-4e2f-b5f7-63998f210d4f'

# Author of this module
Author = 'Adam Burley'

# Company or vendor of this module
CompanyName = 'Adam Burley'

# Copyright statement for this module
Copyright = 'Adam Burley 2024'

# Description of the functionality provided by this module
Description = 'PowerShell wrapper for the Axcient x360Recover public API'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Get-Appliance','Get-BackupJob','Get-BackupJobHistory','Get-Client','Get-Device','Get-DeviceAutoVerify','Get-DeviceRestorePoint','Get-Organization','Get-Vault','Initialize-AxcientAPI')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'PSEdition_Core','Windows','Linux','MacOS','Axcient','x360Recover','Axcient_x360Recover'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/adamburley/AxcientAPI/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/adamburley/AxcientAPI'

        # A URL to an icon representing this module.
        IconUri = 'https://github.com/adamburley/AxcientAPI/blob/main/axcient-logo-85x85.png?raw=true'

        # ReleaseNotes of this module
        ReleaseNotes = @'
        Version 0.3.2 resolved issue with client_id property conflict, removed warning from Get-BackupJobHistory
        Version 0.3.1 first published release
        Version 0.2.0 supports the July 2024 API Schema
'@
        # Prerelease string of this module
        Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/adamburley/AxcientAPI/tree/main/docs'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
