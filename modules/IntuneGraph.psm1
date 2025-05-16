# Auto-import necessary Graph modules
Import-Module Microsoft.Graph.DeviceManagement.Actions -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.DeviceManagement.Configuration -ErrorAction SilentlyContinue


function Test-GraphConnection {
    try {
        $context = Get-MgContext
        if ($null -ne $context -and $context.Scopes -contains "Device.Read.All") {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

function Get-IntuneDevice {
	param (
		[string]$deviceName
	)
	
	Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$deviceName'" -ErrorAction SilentlyContinue	
}

function Invoke-IntuneDeviceSync {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$DeviceId
	)
	
	try {
		$uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/syncDevice"
		Invoke-MgGraphRequest -Method POST -Uri $uri
		$output = "Sync initiated for device ID: $DeviceId"
	} catch {
		$output = "ERROR: Failed to sync device: $_"
	}
	
	$output
}


function Get-IntuneDeviceStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceId
    )

    try {
        $output = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId
    } catch {
        $output = "ERROR: Failed to retrieve device status: $_"
	}
	
	if ($output.LastSyncDateTime) {
		$output | Add-Member -NotePropertyName LocalLastSyncDateTime -NotePropertyValue $output.LastSyncDateTime.ToLocalTime() -Force
	}
	
	$output | Select-Object DeviceName, OperatingSystem, ComplianceState, LocalLastSyncDateTime, LastSyncDateTime, Model
}

function Get-IntuneComplianceState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceId
    )

    try {
		$output = (Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId).ComplianceState
    } catch {
		$output = "ERROR: Failed to retrieve compliance state: $_"
	}
	
	$output
}

function Get-IntuneAssignedConfigurations {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceId
    )

    try {
		$output = Get-MgDeviceManagementManagedDeviceConfigurationState -ManagedDeviceId $DeviceId
    } catch {
		$output = "ERROR: Failed to retrieve assigned configurations: $_"
	}
	
	$output
}

function Get-IntuneUpdatePolicy {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$DeviceId
	)
	
	try {
		$states = Get-MgDeviceManagementManagedDeviceConfigurationState -ManagedDeviceId $DeviceId		
		return $states
	} catch {
		$states = "ERROR: Failed to retrieve update policy: $_"
	}
	
	$states
}


function Connect-GraphWithDeviceRead {
    try {
		Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "DeviceManagementConfiguration.Read.All", "Device.Read.All", "DeviceManagementManagedDevices.PrivilegedOperations.All"
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
    }
}
