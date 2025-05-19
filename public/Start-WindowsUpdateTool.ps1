function Start-WindowsUpdateTool {
	[cmdletbinding()]
	Param (
		[parameter()]
		[string]$ComputerName = $env:COMPUTERNAME,
		[parameter()]
		[string]$Domain = $env:USERDNSDOMAIN
	)
	
	$SettingsRegPath = "HKEY_Current_User\Software\pXLabs\Windows Update Tool"
	$LogFile = "$($env:ProgramData)\pXLabs-WindowsUpdateTool\pXLabs_WindowsUpdateTool.log"
	$Script:SectionBreak = "----------------------------------------------"
	
	# Hide the console
	$SW_HIDE, $SW_SHOW = 0, 5
	$TypeDef = '[DllImport("User32.dll")]public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
	Add-Type -MemberDefinition $TypeDef -Namespace Win32 -Name Functions
	$hWnd = (Get-Process -Id $PID).MainWindowHandle
	$Null = [Win32.Functions]::ShowWindow($hWnd, $SW_HIDE)
	
	Add-Type -AssemblyName PresentationFramework
	Add-Type -AssemblyName PresentationCore
	Add-Type -AssemblyName WindowsBase
	Add-Type -AssemblyName System.Xaml
	Add-Type -AssemblyName System.Windows.Forms
	
	# Check if running as admin
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
	$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	
	if (-not $isAdmin) {
		[System.Windows.MessageBox]::Show(
			"This tool must be run as Administrator. Please restart PowerShell as Administrator and try again.",
			"Administrator Privileges Required",
			'OK',
			'Warning'
		) | Out-Null
		
		return
	}
	
	IF (-not (Test-Path "$($env:ProgramData)\pXLabs-WindowsUpdateTool")) {
		New-Item -Path "$($env:ProgramData)\pXLabs-WindowsUpdateTool" -Force -ItemType Directory | out-null
	}
	
	# Create a Windows Forms Timer object
	$script:timerJobTracker = New-Object System.Windows.Forms.Timer
	$script:timerJobTracker.Interval = 1000 # e.g., every 1 second
	
	# Add timer tick
	$timerJobTracker.Add_Tick({
			Update-JobTracker
		})
	
	# Stop the tracker if the form is closed while it is running
	$jobTracker_FormClosed = [System.Windows.Forms.FormClosedEventHandler]{
		Stop-JobTracker
	}
	
	if (-not $script:JobTrackerList) {
		$script:JobTrackerList = New-Object System.Collections.ArrayList
	}
			
	class UpdateItem : System.ComponentModel.INotifyPropertyChanged {
		# Microsoft Update (PSWindowsUpdate)
		[string]$Title
		[string]$KB
		[string]$Size
		[string]$Description
		[string]$Status
		[string]$Deadline
		[string]$DeploymentAction
		[bool]$IsDownloaded
		[bool]$IsInstalled
		[bool]$IsMandatory
		[bool]$IsPresent
		[string]$LastDeploymentChangeTime
		
		# CMUpdate (CCM_SoftwareUpdate)
		[string]$Name
		[string]$Publisher
		[string]$ArticleID
		[string]$StartTime
		[string]$PercentComplete
		[string]$State
		[string]$ErrorCode
		[string]$UpdateID
		[string]$EvaluationState
		
		hidden [bool]$isRunning
		hidden [System.ComponentModel.PropertyChangedEventHandler]$PropertyChanged
		
		UpdateItem() {
			$this.IsRunning = $false
		}
		
		[bool]get_IsRunning() { return $this.isRunning }
		[void]set_IsRunning([bool]$value) {
			$this.isRunning = $value
			$this.OnPropertyChanged("IsRunning")
		}
		
		[void]OnPropertyChanged([string]$propertyName) {
			if ($this.PropertyChanged) {
				$this.PropertyChanged.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($propertyName))
			}
		}
		
		[void]add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
			$this.PropertyChanged = [System.Delegate]::Combine($this.PropertyChanged, $handler)
		}
		
		[void]remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
			$this.PropertyChanged = [System.Delegate]::Remove($this.PropertyChanged, $handler)
		}
	}
	
	#region Load XAML
	$XamlPath = Join-Path $PSScriptRoot '..\ui\App.xaml'
	[xml]$xaml = Get-Content -Path $XamlPath
	$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
	$window = [Windows.Markup.XamlReader]::Load($reader)
	$reader.Close()
	$reader.Dispose()
	
	# Find named controls
	$controls = @{ }
	$window.FindName("textbox_ComputerName") | ForEach-Object { $controls["ComputerName"] = $_ }
	$window.FindName("button_Ping") | ForEach-Object { $controls["Ping"] = $_ }
	$window.FindName("button_Clear") | ForEach-Object { $controls["Clear"] = $_ }
	$window.FindName("button_EventViewer") | ForEach-Object { $controls["EventViewer"] = $_ }
	$window.FindName("button_ExplorerHere") | ForEach-Object { $controls["ExplorerHere"] = $_ }
	$window.FindName("button_PSSessionHere") | ForEach-Object { $controls["PSSessionHere"] = $_ }
	$window.FindName("button_CheckServices") | ForEach-Object { $controls["CheckServices"] = $_ }
	$window.FindName("button_ResetWUComponents") | ForEach-Object { $controls["ResetWUComponents"] = $_ }
	$window.FindName("button_UpdateScan") | ForEach-Object { $controls["UpdateScan"] = $_ }
	$window.FindName("button_UpdateEvaluation") | ForEach-Object { $controls["UpdateEvaluation"] = $_ }
	$window.FindName("button_GetUpdateHistory") | ForEach-Object { $controls["GetUpdateHistory"] = $_ }
	$window.FindName("button_GetUpdates") | ForEach-Object { $controls["GetUpdates"] = $_ }
	$window.FindName("button_GetSettings") | ForEach-Object { $controls["GetSettings"] = $_ }
	$window.FindName("button_RefreshGPO") | ForEach-Object { $controls["RefreshGPO"] = $_ }
	$window.FindName("button_GetIntunePolicy") | ForEach-Object { $controls["GetIntunePolicy"] = $_ }
	$window.FindName("button_RefreshCMPolicy") | ForEach-Object { $controls["RefreshCMPolicy"] = $_ }
	$window.FindName("button_RestartCMAgent") | ForEach-Object { $controls["RestartCMAgent"] = $_ }
	$window.FindName("datagridview_UpdateList") | ForEach-Object { $controls["UpdateList"] = $_ }
	$window.FindName("richtextbox_Output") | ForEach-Object { $controls["Output"] = $_ }
	$window.FindName("toolstripstatuslabel_Status") | ForEach-Object { $controls["Status"] = $_ }
	$window.FindName("toolstripstatuslabel_SessionType") | ForEach-Object { $controls["SessionType"] = $_ }
	$window.FindName("toolstripstatuslabel_UpdateMethod") | ForEach-Object { $controls["UpdateMethod"] = $_ }
	$window.FindName("toolstripstatuslabel_Diskspace") | ForEach-Object { $controls["Diskspace"] = $_ }
	$window.FindName("progressbar_Status") | ForEach-Object { $controls["Progressbar"] = $_ }
	
	$groupboxes = @{ }
	$window.FindName("groupbox_CMUpdate") | ForEach-Object { $groupboxes["CMUpdate"] = $_ }
	$window.FindName("groupbox_MSUpdate") | ForEach-Object { $groupboxes["MSUpdate"] = $_ }
	$window.FindName("groupbox_Policy") | ForEach-Object { $groupboxes["Policy"] = $_ }
	
	$menuItems = @{ }
	$window.FindName("menuItem_InvokeDeviceSync") | ForEach-Object { $menuItems["InvokeDeviceSync"] = $_ }
	$window.FindName("menuItem_GetDeviceStatus") | ForEach-Object { $menuItems["GetDeviceStatus"] = $_ }
	$window.FindName("menuItem_GetComplianceState") | ForEach-Object { $menuItems["GetComplianceState"] = $_ }
	$window.FindName("menuItem_GetAssignedConfigurations") | ForEach-Object { $menuItems["GetAssignedConfigurations"] = $_ }
	$window.FindName("menuItem_GetIntuneUpdatePolicy") | ForEach-Object { $menuItems["GetIntuneUpdatePolicy"] = $_ }
	$window.FindName("menuItem_InstallUpdate") | ForEach-Object { $menuItems["InstallUpdate"] = $_ }
	$window.FindName("menuItem_DarkTheme") | ForEach-Object { $menuItems["DarkTheme"] = $_ }
	$window.FindName("menuItem_LightTheme") | ForEach-Object { $menuItems["LightTheme"] = $_ }
	$window.FindName("menuItem_MonokaiTheme") | ForEach-Object { $menuItems["MonokaiTheme"] = $_ }
	$window.FindName("menuItem_NordTheme") | ForEach-Object { $menuItems["NordTheme"] = $_ }
	$window.FindName("menuItem_EverForestTheme") | ForEach-Object { $menuItems["EverForestTheme"] = $_ }
	#endregion
	
	#Region Set control tooltips
	Set-ControlToolTip -ControlName "Ping" -Message "Ping computer (disabled for local sessions)"
	Set-ControlToolTip -ControlName "Clear" -Message "Clean up output"
	Set-ControlToolTip -ControlName "EventViewer" -Message "Open eventviewer"
	Set-ControlToolTip -ControlName "ExplorerHere" -Message "Open an explorer window"
	Set-ControlToolTip -ControlName "PSSessionHere" -Message "Opens remote PowerShell session (disabled for local sessions)"
	Set-ControlToolTip -ControlName "CheckServices" -Message "Check services related to Windows Update processes"
	Set-ControlToolTip -ControlName "ResetWUComponents" -Message "Reset Windows Update components"
	Set-ControlToolTip -ControlName "UpdateScan" -Message "Scan for missing updates against CMUpdate (disabled if a CMUpdate server is not found)"
	Set-ControlToolTip -ControlName "UpdateEvaluation" -Message "Evaluate Update deployments and check if updates should be installed (disabled if a CMUpdate server is not found)"
	Set-ControlToolTip -ControlName "RestartCMAgent" -Message "Restarts the MECM client agent (disabled if a CMUpdate server is not found)"
	Set-ControlToolTip -ControlName "GetUpdateHistory" -Message "Gets Windows Update History"
	Set-ControlToolTip -ControlName "GetUpdates" -Message "Forces an Update scan against Microsoft Updates"
	Set-ControlToolTip -ControlName "GetSettings" -Message "Gets the Windows Update settings"
	Set-ControlToolTip -ControlName "RefreshGPO" -Message "Invokes a GPUpdate /force"
	Set-ControlToolTip -ControlName "GetIntunePolicy" -Message "Invokes an Intune Policy refresh"
	Set-ControlToolTip -ControlName "RefreshCMPolicy" -Message "Invokes a CM Policy refresh (disabled if a CMUpdate server is not found)"
	#endregion
	
	#region Controls
	$script:storyboard = $controls["GetUpdates"].Resources["PulseAnimation"]
	
	# Button Event: ComputerName
	$controls["ComputerName"].Add_LostFocus({
			$controls["ComputerName"].Text = $controls["ComputerName"].Text.ToUpper()
			Invoke-SessionLoad -SessionLoad $SessionLoad
		})
	
	# Button Event: ComputerName
	$controls["ComputerName"].Add_KeyDown({
			if ($_.Key -eq 'Enter') {
				$controls["ComputerName"].Text = $controls["ComputerName"].Text.ToUpper()
				Invoke-SessionLoad -SessionLoad $SessionLoad
			}
		})
	
	# Button Event: Ping
	$controls["Ping"].Add_Click({
			$controls["Status"].Text = "Status: Pinging..."
			
			$computer = $controls["ComputerName"].Text
			if ([string]::IsNullOrWhiteSpace($computer)) {
				Write-OutputBox "   Computer name is empty."
				return
			}
			
			if ([string]::IsNullOrWhiteSpace($computer)) {
				Write-OutputBox "   Please enter a computer name."
				return
			}
			
			Write-OutputBox "Pinging $computer..."
			
			if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
				Write-OutputBox "   $computer is online."
			} else {
				Write-OutputBox "   $computer is offline or unreachable."
			}
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: Clear
	$controls["Clear"].Add_Click({
			Clear-WpfDataGrid -DataGrid $controls["UpdateList"]
			$controls["ComputerName"].Clear()
			$controls["Output"].Document.Blocks.Clear()
			$controls["Status"].Text = "Status: Cleared"
		})
	
	# Button Event: EventViewer
	$controls["EventViewer"].Add_Click({
			Start-Process eventvwr
		})
	
	# Button Event: ExplorerHere
	$controls["ExplorerHere"].Add_Click({
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "   Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
			}
			
			If (Test-Path "\\$Computer\c`$\Windows\CCM\Logs") {
				Start-Process explorer -ArgumentList "\\$Computer\c`$\Windows\CCM\Logs"
			} elseif (Test-Path "\\$Computer\c`$") {
				Start-Process explorer -ArgumentList "\\$Computer\c`$"
			} Else {
				Write-Prompt -PromptText "   $Computer unavailable for connection." -PromptTitle "Warning" -PromptType 16
			}
		})
	
	# Button Event: PSSessionHere
	$controls["PSSessionHere"].Add_Click({
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
			}
			
			Start-Process powershell -ArgumentList "-noexit -command (enter-pssession $($Computer))"
		})
	
	# Button Event: CheckServices
	$controls["CheckServices"].Add_Click({
			$controls["Status"].Text = "Status: Checking services..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$SectionBreak`nChecking Windows Update services..."
			
			IF ($SessionType -eq "Remote") {
				$services = Get-Service -ComputerName $computer wuauserv, bits, cryptsvc, msiserver | Select-Object Name, Status
			} Else {
				$services = Get-Service wuauserv, bits, cryptsvc, msiserver | Select-Object Name, Status
			}
			
			Write-OutputBox "$SectionBreak`n   Windows Update services`n$SectionBreak".Trim() -ReplaceLastLine
			Write-OutputBox "   $($services | out-string)"
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: ResetWUComponents
	$controls["ResetWUComponents"].Add_Click({
			$controls["Status"].Text = "Status: Resetting WU Components..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$SectionBreak`nResetting Windows Update Components..."
			
			$storyboard.Begin($controls["ResetWUComponents"])
			$controls["Progressbar"].Visibility = 'Visible'
			$controls["Progressbar"].IsIndeterminate = $true
			
			$paramAddJobTracker = @{
				Name	  = "ResetWUComponentsJob"
				JobScript = {
					Param (
						[string]$computer,
						[string]$SessionType,
						[PSCredential]$cred
					)
					
					try {
						$Scriptblock = {
							Try {
								Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
							} catch {
								$_
							}
							
							Import-Module PSWindowsUpdate
							Reset-WUComponents
						}
						
						if ($SessionType -eq "Local") {
							$Result = Invoke-Command -ScriptBlock $Scriptblock
						} else {
							If (-Not (Invoke-Command -ComputerName $Computer -ScriptBlock { Get-PSSessionConfiguration -Name 'VirtualAccount' -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> )) { 
								Invoke-Command -ComputerName $Computer -ScriptBlock { New-PSSessionConfigurationFile -RunAsVirtualAccount -Path .\VirtualAccount.pssc } #-UseSSL -Credential $cred
								Invoke-Command -ComputerName $Computer -ScriptBlock { Register-PSSessionConfiguration -Name 'VirtualAccount' -Path .\VirtualAccount.pssc -Force -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> | out-null
							}
							
							$Result = Invoke-Command -ComputerName $Computer -HideComputerName -ScriptBlock $Scriptblock -ConfigurationName 'VirtualAccount' #-UseSSL -Credential $cred
						}
						
						$Result
					} catch {
						Write-Output @{
							Success = $false
							Error   = $_.Exception.Message
						}
					}
				}
				
				ArgumentList = $computer, $SessionType, $cred
				
				CompletedScript = {
					Param ([System.Management.Automation.Job]$Job)
					
					# Stop animation and reset progress UI
					$controls["ResetWUComponents"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
					$controls["Progressbar"].IsIndeterminate = $false
					$controls["Progressbar"].Visibility = 'Collapsed'
					
					# Handle job-level failure
					if ($Job.State -eq 'Failed') {
						$reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
						Write-OutputBox "   Job failed: $reason"
						$controls["Status"].Text = "Status: Failed"
						return
					}
					
					try {
						# Collect all job results
						$results = Receive-Job -Job $Job -ErrorAction Stop
						
						if ($results -is [System.Management.Automation.ErrorRecord]) {
							Write-OutputBox "   ERROR: $($results.ToString())"
							$controls["Status"].Text = "Status: Error"
							return
						}
						
						# Handle output from job if it's a structured hashtable
						if ($results -is [hashtable]) {
							if ($results.ContainsKey("Success") -and -not $results["Success"]) {
								$errorMessage = $results["Error"] #?? "Unknown error"
								Write-OutputBox "   ERROR: $errorMessage"
								$controls["Status"].Text = "Status: Failed"
								return
							}
						}
						
						# If no errors
						Write-OutputBox "   Windows Update Components reset completed"
						$controls["Status"].Text = "Status: Ready"
					} catch {
						Write-OutputBox "Failed to process job results: $($_.Exception.Message)"
						$controls["Status"].Text = "Status: Failed"
					}
				}				
				
				UpdateScript = {
					Param ([System.Management.Automation.Job]$Job)
				}
			}
			
			Add-JobTracker @paramAddJobTracker
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: GetUpdateHistory
	$controls["GetUpdateHistory"].Add_Click({
			$controls["Status"].Text = "Status: Getting updates..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
					$script:QuickFixHistory = Get-CimInstance -ClassName Win32_QuickFixEngineering
				} Else {
					$SessionType = "Remote"
					$RemoteCimSession = New-CimSession -ComputerName $computer #-Credential $cred
					$script:QuickFixHistory = Get-CimInstance -ComputerName $Computer -ClassName Win32_QuickFixEngineering
					Remove-CimSession -CimSession $RemoteCimSession
				}
			}
			
			Write-OutputBox "$Sectionbreak`nGetting Update History..."
			
			$storyboard.Begin($controls["GetUpdateHistory"])
			$controls["Progressbar"].Visibility = 'Visible'
			$controls["Progressbar"].IsIndeterminate = $true
			
			$paramAddJobTracker = @{
				Name	  = "GetUpdateHistoryJob"
				JobScript = {
					Param (
						[string]$computer,
						[string]$SessionType,
						[PSCredential]$cred
					)
					
					try {
						$Scriptblock = {
							Param (
								[string]$Computer
							)
							
							Try {
								Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
							} catch {
								$_
							}
							
							Import-Module PSWindowsUpdate
							Get-WUHistory | Select-object KB, Date, Title, Description, Result -ExcludeProperty RunspaceId
						}
						
						if ($SessionType -eq "Local") {
							$UpdateHistory = Invoke-Command -ScriptBlock $Scriptblock
						} else {
							IF (-Not (Invoke-Command -ComputerName $Computer -ScriptBlock { Get-PSSessionConfiguration -Name 'VirtualAccount' -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #>)) {
								Invoke-Command -ComputerName $Computer -ScriptBlock { New-PSSessionConfigurationFile -RunAsVirtualAccount -Path .\VirtualAccount.pssc } #-UseSSL -Credential $cred
								Invoke-Command -ComputerName $Computer -ScriptBlock { Register-PSSessionConfiguration -Name 'VirtualAccount' -Path .\VirtualAccount.pssc -Force -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> | out-null
							}
							
							$UpdateHistory = Invoke-Command -ComputerName $Computer -HideComputerName -ScriptBlock $Scriptblock -ConfigurationName 'VirtualAccount' #-UseSSL -Credential $cred
						}
						
						$UpdateHistory
					} catch {
						Write-Output @{
							Success = $false
							Error   = $_.Exception.Message
						}
					}
				}
				
				ArgumentList = $computer, $SessionType, $cred
				
				JobData   = @{
					ComputerName = $computer
					Sectionbreak = $Sectionbreak
				}
				
				CompletedScript = {
					Param (
						[System.Management.Automation.Job]$Job,
						$JobData
					)
					
					# Stop animation and progress
					$controls["GetUpdateHistory"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
					$controls["Progressbar"].IsIndeterminate = $false
					$controls["Progressbar"].Visibility = 'Collapsed'
					
					# Check if the job itself failed
					if ($Job.State -eq 'Failed') {
						$reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
						Write-OutputBox "   Job failed: $reason"
						$controls["Status"].Text = "Status: Failed"
						return
					}
					
					try {
						# Safely receive job results
						$results = Receive-Job -Job $Job -ErrorAction Stop
						
						# Handle known ErrorRecord
						if ($results -is [System.Management.Automation.ErrorRecord]) {
							Write-OutputBox "   ERROR: $($results.ToString())"
							$controls["Status"].Text = "Status: Error"
							return
						}
						
						# Handle no results
						if (-not $results) {
							Write-OutputBox "   WARNING: No update history returned."
							$controls["Status"].Text = "Status: Warning"
							return
						}
						
						# Output structured update history
						Write-OutputBox "$($JobData.SectionBreak)`n   $($JobData.ComputerName.ToUpper()) Update History`n$($JobData.SectionBreak)" -ReplaceLastLine
						Write-OutputBox "$($results | Select-Object KB, Date, Title, Description, Result -ExcludeProperty RunspaceId | Out-String)".Trim()
						
						# Output QuickFixEngineering info
						Write-OutputBox "$($JobData.SectionBreak)`n   $($JobData.ComputerName.ToUpper()) QuickFixEngineering History`n$($JobData.SectionBreak)"
						Write-OutputBox "$($script:QuickFixHistory | Select-Object Description, HotFixID, InstalledBy, InstalledOn -ExcludeProperty PSComputerName | Sort-Object InstalledOn | Out-String)".Trim()
						
						$controls["Status"].Text = "Status: Ready"
					} catch {
						# Catch unexpected issues
						Write-OutputBox "Failed to process job results: $($_.Exception.Message)"
						$controls["Status"].Text = "Status: Failed"
					}
				}				
				
				UpdateScript = {
					Param ([System.Management.Automation.Job]$Job)
				}
			}
			
			Add-JobTracker @paramAddJobTracker
		})
	
	# Button Event: GetUpdates
	$controls["GetUpdates"].Add_Click({
			$controls["Status"].Text = "Status: Getting updates..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$Sectionbreak`nGetting Updates..."
			
			$storyboard.Begin($controls["GetUpdates"])
			$controls["Progressbar"].Visibility = 'Visible'
			$controls["Progressbar"].IsIndeterminate = $true
			
			$paramAddJobTracker = @{
				Name	  = "GetUpdatesJob"
				JobScript = {
					Param (
						[string]$computer,
						[string]$SessionType,						
						[object]$CMClientPresent,
                        [PSCredential]$cred
					)
					
					try {
						if ($CMClientPresent) {
							$Scriptblock = {
								Get-CimInstance -Query "SELECT * FROM CCM_SoftwareUpdate" -Namespace "ROOT\ccm\ClientSDK"
							}
						} else {
							$Scriptblock = {
								Try {
									Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
								} catch {
									$_
								}
								
								Import-Module PSWindowsUpdate -Force
								Get-WindowsUpdate
							}
						}
						
						if ($SessionType -eq "Local") {
							$Updates = Invoke-Command -ScriptBlock $Scriptblock
						} else {
							IF (-Not (Invoke-Command -ComputerName $Computer -ScriptBlock { Get-PSSessionConfiguration -Name 'VirtualAccount' -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #>)) {
								Invoke-Command -ComputerName $Computer -ScriptBlock { New-PSSessionConfigurationFile -RunAsVirtualAccount -Path .\VirtualAccount.pssc } #-UseSSL -Credential $cred
								Invoke-Command -ComputerName $Computer -ScriptBlock { Register-PSSessionConfiguration -Name 'VirtualAccount' -Path .\VirtualAccount.pssc -Force -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> | out-null
							}
							
							$Updates = Invoke-Command -ComputerName $Computer -HideComputerName -ScriptBlock $Scriptblock -ConfigurationName 'VirtualAccount' #-UseSSL -Credential $cred
						}
						
						$Updates
					} catch {
						Write-Output @{
							Success = $false
							Error   = $_.Exception.Message
						}
					}
				}
				
				ArgumentList = $computer, $SessionType, $CMClientPresent, $cred
				
				JobData   = @{
					ComputerName = $computer
					Sectionbreak = $Sectionbreak
				}
				
				CompletedScript = {
					Param (
						[System.Management.Automation.Job]$Job,
						$JobData
					)
					
					# Stop animation and progress
					$controls["GetUpdates"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
					$controls["Progressbar"].IsIndeterminate = $false
					$controls["Progressbar"].Visibility = 'Collapsed'
					
					# Job failure check
					if ($Job.State -eq 'Failed') {
						$reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
						Write-OutputBox "   Job failed: $reason"
						$controls["Status"].Text = "Status: Failed"
						return
					}
					
					try {
						# Safely retrieve results
						$results = Receive-Job -Job $Job -ErrorAction Stop
						
						# Handle if it's a direct error object
						if ($results -is [System.Management.Automation.ErrorRecord]) {
							Write-OutputBox "   ERROR: $($results.ToString())"
							$controls["Status"].Text = "Status: Error"
							return
						}
						
						# Handle empty result set
						if (-not $results) {
							Write-OutputBox "   No updates returned."
							$controls["Status"].Text = "Status: No Updates"
							return
						}
						
						# Safely build the update items list
						$updateItems = foreach ($r in $results) {
							try {
								$item = [UpdateItem]::new()
								
								if (-not $CMClient) {
									$item.KB = $r.KB
									$item.Size = $r.Size
									$item.Title = $r.Title
									$item.Description = $r.Description
									$item.Status = $r.Status
									$item.Deadline = "$($r.Deadline)"
									$item.DeploymentAction = $r.DeploymentAction
									$item.IsDownloaded = $r.IsDownloaded
									$item.IsInstalled = $r.IsInstalled
									$item.IsMandatory = $r.IsMandatory
									$item.IsPresent = $r.IsPresent
									$item.LastDeploymentChangeTime = "$($r.LastDeploymentChangeTime)"
								} else {
									$item.Name = $r.Name
									$item.Publisher = $r.Publisher
									$item.ArticleID = $r.ArticleID
									$item.StartTime = $r.StartTime
									$item.Deadline = $r.Deadline
									$item.PercentComplete = "$($r.PercentComplete)"
									$item.State = $r.State
									$item.ErrorCode = "$($r.ErrorCode)"
									$item.UpdateID = $r.UpdateID
									$item.Description = $r.Description
									$item.EvaluationState = "$($r.EvaluationState)"
								}
								
								$item
							} catch {
								Write-OutputBox "   Failed to parse update item: $($_.Exception.Message)"
							}
						}
						
						# Update the UI with parsed items
						Clear-WpfDataGrid -DataGrid $controls["UpdateList"]
						Update-WpfDataGrid -DataGrid $controls["UpdateList"] -Item $updateItems -AutoSizeColumns $true
						
						Write-OutputBox "$($JobData.SectionBreak)`n   Available Updates`n$($JobData.SectionBreak)" -ReplaceLastLine
						Write-OutputBox "$($results | Select-Object Status, KB, Size, Title, RebootRequired -ExcludeProperty RunspaceId | Out-String)".Trim()
						
						$controls["Status"].Text = "Status: Ready"
					} catch {
						Write-OutputBox "   ERROR: Failed to process job results: $($_.Exception.Message)"
						$controls["Status"].Text = "Status: Failed"
					}
				}				
				
				UpdateScript = {
					Param ([System.Management.Automation.Job]$Job)
				}
			}
			
			Add-JobTracker @paramAddJobTracker
		})
	
	# Button Event: GetSettings
	$controls["GetSettings"].Add_Click({
			$controls["Status"].Text = "Status: Getting settings..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			IF ($SessionType -eq "Remote") {
				$WUSettings = invoke-command -computername $Computer -HideComputerName -ScriptBlock { import-module PSWindowsUpdate -Force; Get-WUSettings } #-UseSSL -Credential $cred
			} Else {
				$WUSettings = Get-WUSettings
			}
			
			Write-OutputBox "$SectionBreak`n   Windows Update Settings`n$Sectionbreak"
			IF ($WUSettings) {
				Write-OutputBox "$($WUSettings | format-list | Out-string)"
			} Else {
				Write-OutputBox "   No settings found."
			}
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: UpdateScan
	$controls["UpdateScan"].Add_Click({
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			$Scriptblock = {
				Invoke-CimMethod -Namespace "ROOT\ccm" -ClassName "SMS_Client" -MethodName "TriggerSchedule" -Arguments @{ sScheduleID = "{00000000-0000-0000-0000-000000000113}" }
			}
			
			If ($SessionType -eq "Remote") {
				$result = invoke-command -computername $Computer -HideComputerName -ScriptBlock $Scriptblock #-UseSSL -Credential $cred
			} Else {
				$result = invoke-command -ScriptBlock $Scriptblock
			}
			
			If (-not $result.ReturnValue) {
				$result = "Successfully started"
			} Else {
				$result = $result.ReturnValue
			}
			
			Write-OutputBox "   Result: $($result)"
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: UpdateEvaluation
	$controls["UpdateEvaluation"].Add_Click({
			$controls["Status"].Text = "Status: Running update evaluation..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$SectionBreak`nStarting CM update evaluation..."
			
			$Scriptblock = {
				Invoke-CimMethod -Namespace "ROOT\ccm" -ClassName "SMS_Client" -MethodName "TriggerSchedule" -Arguments @{ sScheduleID = "{00000000-0000-0000-0000-000000000108}" }
			}
			
			If ($SessionType -eq "Remote") {
				$result = invoke-command -computername $Computer -HideComputerName -ScriptBlock { $Scriptblock } #-UseSSL -Credential $cred
			} Else {
				$result = invoke-command -ScriptBlock $Scriptblock
			}
			
			If (-not $result.ReturnValue) {
				$result = "Successfully started"
			} Else {
				$result = $result.ReturnValue
			}
			
			Write-OutputBox "   Update Evaluation Results`n$SectionBreak" -ReplaceLastLine
			Write-OutputBox "   Result: $($result)"
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: RefreshGPO
	$controls["RefreshGPO"].Add_Click({
			$controls["Status"].Text = "Status: Refreshing GPO..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$SectionBreak`nRefreshing Group Policy..."
			
			$storyboard.Begin($controls["RefreshGPO"])
			$controls["Progressbar"].Visibility = 'Visible'
			$controls["Progressbar"].IsIndeterminate = $true
			
			$paramAddJobTracker = @{
				Name	  = "RefreshGPOJob"
				JobScript = {
					Param (
						[string]$computer,
						[string]$SessionType,
						[PSCredential]$cred
					)
					
					try {
						$Scriptblock = {
							$result = (Start-Process -FilePath gpupdate -ArgumentList "/force" -Wait -PassThru).ExitCode
							
							If ($result -eq 0) {
								$output = "Successful"
							} Else {
								$output = "Unsuccessful"
							}
							
							$output | Out-File "C:\gporesult.txt"
							$output
						}
						
						if ($SessionType -eq "Local") {
							$Result = Invoke-Command -ScriptBlock $Scriptblock
						} else {
							IF (-Not (Invoke-Command -ComputerName $Computer -ScriptBlock { Get-PSSessionConfiguration -Name 'VirtualAccount' -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #>)) {
								Invoke-Command -ComputerName $Computer -ScriptBlock { New-PSSessionConfigurationFile -RunAsVirtualAccount -Path .\VirtualAccount.pssc } #-UseSSL -Credential $cred
								Invoke-Command -ComputerName $Computer -ScriptBlock { Register-PSSessionConfiguration -Name 'VirtualAccount' -Path .\VirtualAccount.pssc -Force -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> | out-null
							}
							
							$Result = Invoke-Command -ComputerName $Computer -HideComputerName -ScriptBlock $Scriptblock -ConfigurationName 'VirtualAccount' #-UseSSL -Credential $cred
						}
						
						$Result
					} catch {
						Write-Output @{
							Success = $false
							Error   = $_.Exception.Message
						}
					}
				}
				
				ArgumentList = $computer, $SessionType, $cred
				
				CompletedScript = {
					Param ([System.Management.Automation.Job]$Job)
					
					$controls["RefreshGPO"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
					$controls["Progressbar"].IsIndeterminate = $false
					$controls["Progressbar"].Visibility = 'Collapsed'
					
					if ($Job.State -eq 'Failed') {
						$reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
						Write-OutputBox "   Job failed: $reason"
						$controls["Status"].Text = "Status: Failed"
						return
					}
					
					try {
						$results = Receive-Job -Job $Job -ErrorAction Stop
						
						if ($results -is [System.Management.Automation.ErrorRecord]) {
							Write-OutputBox "   ERROR: $($results.ToString())"
							$controls["Status"].Text = "Status: Error"
							return
						}
						
						if (-not $results) {
							Write-OutputBox "   WARNING: No results returned."
							$controls["Status"].Text = "Status: No Results"
							return
						}
						
						Write-OutputBox "   Result: $results"
						$controls["Status"].Text = "Status: Ready"
					} catch {
						Write-OutputBox "Failed to process job results: $($_.Exception.Message)"
						$controls["Status"].Text = "Status: Failed"
					}
				}
				
				
				UpdateScript = {
					Param ([System.Management.Automation.Job]$Job)
				}
			}
			
			Add-JobTracker @paramAddJobTracker
		})
	
	# Button Event: GetIntunePolicy
	$controls["GetIntunePolicy"].Add_Click({
			$controls["Status"].Text = "Status: Getting Intune policy..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox $Sectionbreak
			Write-OutputBox "Refreshing Intune Policies..."
			
			$Scriptblock = {
				$Tasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq "Schedule #3 created by enrollment client" }
				
				IF (-NOT $Tasks) {
					return "No Task"
				}
				
				$Tasks | ForEach-Object {
					Start-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName
					Start-Sleep 5
				}
			}
			
			If ($SessionType -eq "Remote") {
				$result = invoke-command -computername $Computer -HideComputerName -ScriptBlock { $Scriptblock } #-UseSSL -Credential $cred
			} Else {
				$result = invoke-command -ScriptBlock $Scriptblock
			}
			
			If ($result -eq "No Task") {
				$result = "No Intune policy to refresh"
			} Else {
				$result = "Successfully started"
			}
			
			Write-OutputBox "   Result: $result"
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: RefreshCMPolicy
	$controls["RefreshCMPolicy"].Add_Click({
			$controls["Status"].Text = "Status: Refreshing CM policy..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox $SectionBreak
			Write-OutputBox "Starting CM policy refresh..."
			
			$Scriptblock = {
				If (Get-CimClass -Namespace 'ROOT\ccm' -ClassName 'SMS_Client' -ErrorAction SilentlyContinue) {
					Invoke-CimMethod -Namespace "ROOT\ccm" -ClassName "SMS_Client" -MethodName "TriggerSchedule" -Arguments @{ sScheduleID = "{00000000-0000-0000-0000-000000000021}" }
				} Else {
					return "No CM Client"
				}
			}
			
			If ($SessionType -eq "Remote") {
				$result = invoke-command -computername $Computer -HideComputerName -ScriptBlock { $Scriptblock } #-UseSSL -Credential $cred
			} Else {
				$result = invoke-command -ScriptBlock $Scriptblock
			}
			
			If ($result -eq "No CM Client") {
				
			} elseif ($null -eq $result.ReturnValue) {
				$result = "Successfully started"
			} Else {
				$result = $result.ReturnValue
			}
			
			Write-OutputBox "   Result: $($result)"
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: RestartCMAgent
	$controls["RestartCMAgent"].Add_Click({
			$controls["Status"].Text = "Status: Restarting CM agent..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
	<#			
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
#>
			}
			
			Write-OutputBox $SectionBreak
			Write-OutputBox "Restarting CM agent..."
			
			IF (Get-Service -ComputerName "$Computer" -name ccmexec -ErrorAction SilentlyContinue) {
				Restart-CMAgent -Computername $Computer
				Write-OutputBox "   CM restart command sent."
			} Else {
				Write-OutputBox "   CM service not found."
			}
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Button Event: UpdateList
	$controls["UpdateList"].Add_PreviewMouseRightButtonDown({
			param ($sender,
				$e)
			
			$originalSource = $e.OriginalSource
			
			while ($originalSource -and -not ($originalSource -is [System.Windows.Controls.DataGridRow])) {
				$originalSource = $originalSource.Parent
			}
			
			if ($originalSource -is [System.Windows.Controls.DataGridRow]) {
				$originalSource.IsSelected = $true
			}
		})
	
	# Menu Event: InstallUpdate
	$menuItems["InstallUpdate"].Add_Click({
			$controls["Status"].Text = "Status: Installing updates..."
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = Set-Computername -ComputerName $controls["ComputerName"].Text
				
				IF ($controls["ComputerName"].Text.ToUpper() -eq $env:computername.ToUpper()) {
					$SessionType = "Local"
				} Else {
					$SessionType = "Remote"
				}
			}
			
			Write-OutputBox "$Sectionbreak".Trim()
			$controls["Progressbar"].Visibility = 'Visible'
			$controls["Progressbar"].IsIndeterminate = $true
			
			$selectedItems = $controls["UpdateList"].SelectedItems
			
			if ($null -ne $selectedItems) {
				foreach ($item in $selectedItems) {
					if ($item.PSObject.Properties.Match("Title") -and $item.Title) {
						$Title = $item.Title
					}
					
					if ($item.PSObject.Properties.Match("KB") -and $item.KB) {
						$kbOrId = $item.KB
					} elseif ($item.PSObject.Properties.Match("UpdateId") -and $item.UpdateId) {
						$kbOrId = $item.UpdateId
					} else {
						#Write-OutputBox "WARNING: No KB or UpdateId found for item: $($item | Out-String)"
						
						#$controls["Progressbar"].IsIndeterminate = $false
						#$controls["Progressbar"].Visibility = 'Collapsed'
						
						#return
						$kbOrId = "NoKBOrId"
					}
					
					Write-OutputBox "Installing update: $kbOrId - $Title"
					
					$paramAddJobTracker = @{
						Name	  = "InstallUpdateJob"
						JobScript = {
							Param (
								[string]$computer,
								[string]$SessionType,
								[string]$Title,
								[string]$UpdateID,								
								[object]$CMClientPresent,
                                [PSCredential]$cred
							)
							
							try {
								if ($CMClientPresent) {
									$Scriptblock = {
										$updates = Get-CimInstance -Namespace "ROOT\ccm\ClientSDK" -ClassName "CCM_SoftwareUpdate" -Filter "UpdateID LIKE '$UpdateID'" -CimSession $cimSession
										Invoke-CimMethod -Namespace "ROOT\ccm\ClientSDK" -ClassName "CCM_SoftwareUpdatesManager" -MethodName "InstallUpdates" -Arguments @{ CCMUpdates = $updates } -CimSession $cimSession
										
										Write-output '   Installation invoked. Please use the `"Get Updates`" button to check on progress.'
									}
								} else {
									$Scriptblock = {
										Try {
											Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
										} catch {
											$_
										}
										
										Import-Module PSWindowsUpdate
										
										If ($UpdateID -ne "NoKBOrId") {
											Install-WindowsUpdate -AcceptAll -IgnoreReboot -KBArticleID $UpdateID
										} Else {
											Install-WindowsUpdate -AcceptAll -IgnoreReboot -Title "$Title"
										}										
									}
								}
								
								if ($SessionType -eq "Local") {
									$Result = Invoke-Command -ScriptBlock $Scriptblock
								} else {
									IF (-Not (Invoke-Command -ComputerName $Computer -ScriptBlock { Get-PSSessionConfiguration -Name 'VirtualAccount' -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #>)) {
										Invoke-Command -ComputerName $Computer -ScriptBlock { New-PSSessionConfigurationFile -RunAsVirtualAccount -Path .\VirtualAccount.pssc } #-UseSSL -Credential $cred
										Invoke-Command -ComputerName $Computer -ScriptBlock { Register-PSSessionConfiguration -Name 'VirtualAccount' -Path .\VirtualAccount.pssc -Force -ErrorAction SilentlyContinue } <# -UseSSL -Credential $cred #> | out-null
									}
									
									$Result = Invoke-Command -ComputerName $Computer -ScriptBlock $Scriptblock -ConfigurationName 'VirtualAccount' #-UseSSL -Credential $cred
								}
								
								$Result
							} catch {
								Write-Output @{
									Success = $false
									Error   = $_.Exception.Message
								}
							}
						}
						
						ArgumentList = $computer, $SessionType, $Title, $kbOrId, $CMClientPresent, $cred
						
						CompletedScript = {
							Param ([System.Management.Automation.Job]$Job)
							
							$controls["Progressbar"].IsIndeterminate = $false
							$controls["Progressbar"].Visibility = 'Collapsed'
							
							if ($Job.State -eq 'Failed') {
								$reason = $Job.ChildJobs[0].JobStateInfo.Reason.Message
								Write-OutputBox "Job failed: $reason"
								$controls["Status"].Text = "Status: Failed"
								return
							}
							
							try {
								$results = Receive-Job -Job $Job -ErrorAction Stop
								
								if ($results -is [System.Management.Automation.ErrorRecord]) {
									Write-OutputBox "   ERROR: $($results.ToString())"
									$controls["Status"].Text = "Status: Error"
									return
								}
								
								if (-not $results) {
									Write-OutputBox "   No installation performed"
									$controls["Status"].Text = "Status: No Changes"
									return
								}
								
								Write-OutputBox "$($results | Select-Object Result, KB, Size, Title | Out-String)"
								$controls["Status"].Text = "Status: Ready"
							} catch {
								Write-OutputBox "Failed to process job results: $($_.Exception.Message)"
								$controls["Status"].Text = "Status: Failed"
							}
						}						
						
						UpdateScript = {
							Param ([System.Management.Automation.Job]$Job)
							
							$controls["Progressbar"].Visibility = 'Visible'
							$controls["Progressbar"].IsIndeterminate = $true
						}
					}
					
					Add-JobTracker @paramAddJobTracker
				}
			} else {
				Write-OutputBox "No update selected."
			}
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: InvokeDeviceSync
	$menuItems["InvokeDeviceSync"].Add_Click({
			$controls["Status"].Text = "Status: Invoking Intune device sync..."
			Write-OutputBox "$SectionBreak`nInvoking Intune device sync...`n$SectionBreak"

			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = $controls["ComputerName"].Text
				$Connected = Test-GraphConnection
				
				If (-Not $Connected) {
					Connect-GraphWithDeviceRead
				}
				
				$device = Get-IntuneDevice -deviceName $computer -erroraction SilentlyContinue
				
				If (-Not $device) {
					Write-OutputBox "ERROR: Cannot retrieve device Id for $computer"
					return
				}
			}
			
			$output = Invoke-IntuneDeviceSync -deviceId $device.Id 
			Write-OutputBox "$output"
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: GetDeviceStattus
	$menuItems["GetDeviceStatus"].Add_Click({
			$controls["Status"].Text = "Status: Getting Intune device status..."
			Write-OutputBox "$SectionBreak`nGetting Intune device status...`n$SectionBreak"

			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = $controls["ComputerName"].Text
				$Connected = Test-GraphConnection
				
				If (-Not $Connected) {
					Connect-GraphWithDeviceRead
				}
				
				$device = Get-IntuneDevice -deviceName $computer -erroraction SilentlyContinue
				
				If (-Not $device) {
					Write-OutputBox "ERROR: Cannot retrieve device Id for $computer"
					return
				}
			}
			
			$output = Get-IntuneDeviceStatus -deviceId $device.Id
			Write-OutputBox ("Retrieved Intune device status for $($Device.Id):`n" + ($output | Format-List | Out-String))
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: GetComplianceState
	$menuItems["GetComplianceState"].Add_Click({
			$controls["Status"].Text = "Status: Getting Intune compliance state..."
			Write-OutputBox "$SectionBreak`nGetting Intune compliance state...`n$SectionBreak"
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = $controls["ComputerName"].Text
				$Connected = Test-GraphConnection
				
				If (-Not $Connected) {
					Connect-GraphWithDeviceRead
				}
				
				$device = Get-IntuneDevice -deviceName $computer -erroraction SilentlyContinue
				
				If (-Not $device) {
					Write-OutputBox "ERROR: Cannot retrieve device Id for $computer"
					return
				}
			}
			
			$output = Get-IntuneComplianceState -deviceId $device.Id
			
			Write-OutputBox ("   Intune device compliance state for $($Device.Id): " + ($output | Out-String))
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: GetAssignedConfigurations
	$menuItems["GetAssignedConfigurations"].Add_Click({
			$controls["Status"].Text = "Status: Getting Intune assigned configurations..."
			Write-OutputBox "$SectionBreak`nGetting Intune assigned configurations...`n$SectionBreak"
			
			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = $controls["ComputerName"].Text
				$Connected = Test-GraphConnection
				
				If (-Not $Connected) {
					Connect-GraphWithDeviceRead
				}
				
				$device = Get-IntuneDevice -deviceName $computer -erroraction SilentlyContinue
				
				If (-Not $device) {
					Write-OutputBox "ERROR: Cannot retrieve device Id for $computer"
					return
				}
			}
			
			$output = Get-IntuneAssignedConfigurations -deviceId $device.Id
			
			Write-OutputBox ("Intune device assigned configurations for $($Device.Id):`n" + ($output | Format-List | Out-String))
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: GetIntuneUpdatePolicy
	$menuItems["GetIntuneUpdatePolicy"].Add_Click({
			$controls["Status"].Text = "Status: Getting Intune update policy..."
			Write-OutputBox "$SectionBreak`nGetting Intune update policy...`n$SectionBreak"

			if ([string]::IsNullOrWhiteSpace($controls["ComputerName"].Text)) {
				Write-OutputBox "Computer name is empty."
				return
			} Else {
				$computer = $controls["ComputerName"].Text
				$Connected = Test-GraphConnection
				
				If (-Not $Connected) {
					Connect-GraphWithDeviceRead
				}
				
				$device = Get-IntuneDevice -deviceName $computer -erroraction SilentlyContinue
				
				If (-Not $device) {
					Write-OutputBox "ERROR: Cannot retrieve device Id for $computer"
					return
				}
			}
			
			$output = Get-IntuneUpdatePolicy -deviceId $device.Id
			
			Write-OutputBox ("Update-related configuration states for $($Device.Id):`n" + ($output | Format-List | Out-String))
			
			$controls["Status"].Text = "Status: Ready"
		})
	
	# Menu Event: DarkTheme
	$menuItems["DarkTheme"].Add_Click({
			Set-Theme -themePath $ThemePaths["Dark"] -Window $window 
			Set-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value "Dark"
		})
	
	# Menu Event: LightTheme
	$menuItems["LightTheme"].Add_Click({
			Set-Theme -themePath $ThemePaths["Light"] -Window $window
			Set-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value "Light"
		})
	
	# Menu Event: MonokaiTheme
	$menuItems["MonokaiTheme"].Add_Click({
			Set-Theme -themePath $ThemePaths["Monokai"] -Window $window
			Set-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value "Monokai"
		})
	# Menu Event: Nordtheme
	$menuItems["NordTheme"].Add_Click({
			Set-Theme -themePath $ThemePaths["Nord"] -Window $window
			Set-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value "Nord"
		})
	
	# Menu Event: EverForestTheme
	$menuItems["EverForestTheme"].Add_Click({
			Set-Theme -themePath $ThemePaths["EverForest"] -Window $window
			Set-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value "EverForest"
		})
	#endregion
	
	#region Startup
	if (-not (Get-Command Invoke-IntuneDeviceSync -ErrorAction SilentlyContinue)) {
		Import-module (Join-Path $PSScriptRoot '..\modules\IntuneGraph.psm1')
	}
	
	$iconPath = Join-Path $PSScriptRoot "..\resources\WindowsUpdates.ico"
	
	if (Test-Path $iconPath) {
		$icon = New-Object System.Windows.Media.Imaging.BitmapImage
		$icon.BeginInit()
		$icon.UriSource = New-Object System.Uri($iconPath, [System.UriKind]::Absolute)
		$icon.EndInit()
		
		$window.Icon = $icon
	} else {
		Write-Warning "Icon not found at $iconPath"
	}
	
	# Load theme file information
	$ThemePaths = @{ }
	$ThemeFiles = Get-ChildItem (Join-Path -Path $PSScriptRoot '..\resources\themes') -Filter *.xaml
	
	foreach ($file in $ThemeFiles) {
		$key = $file.BaseName
		$ThemePaths[$key] = $file.FullName
	}
	
	# Read saved theme or fall back to default
	If (-Not (Get-Item -path registry::"$SettingsRegPath" -ErrorAction SilentlyContinue)) {
		New-Item -Path registry::"$SettingsRegPath" -Force | out-null
	}
	
	$SavedThemeChoice = (Get-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -ErrorAction SilentlyContinue).Theme
	$defaultTheme = "Nord"
	
	$themeToLoad = if ($SavedThemeChoice) {
		$SavedThemeChoice
	} else {
		New-ItemProperty -Path registry::"$SettingsRegPath" -Name "Theme" -Value $defaultTheme -PropertyType String
		$defaultTheme
	}
	
	$themeToLoad = $themeToLoad.ToLower()
	
	switch ($themeToLoad) {
		"dark" { $themePath = $ThemePaths["Dark"] }
		"monokai" { $themePath = $ThemePaths["Monokai"] }
		"nord" { $themePath = $ThemePaths["Nord"] }
		"everforest" { $themePath = $ThemePaths["Everforest"] }
		default { $themePath = $ThemePaths["Light"] }
	}
	
	Set-Theme -themePath $themePath -Window $window
	
	$SessionLoad = {
		If ($controls["ComputerName"].Text -eq "") {
			$controls["ComputerName"].Text = $ComputerName
		} Else {
			$ComputerName = $controls["ComputerName"].Text
		}
		
		$computer = Set-Computername -ComputerName $ComputerName
		
		Write-OutputBox "Session starting on '$ComputerName'...".Trim()
		$controls["Status"].Text = "Session starting on '$ComputerName'..."
		
		IF ($ComputerName.ToUpper() -eq $env:computername.ToUpper()) {
			$SessionType = "Local"
			Update-ButtonState -State Disabled -ButtonPurpose "Remote"
		} Else {
			$SessionType = "Remote"
			Update-ButtonState -State Enabled -ButtonPurpose "Remote"
		}
		
		Write-OutputBox "   '$ComputerName' is $SessionType"
		$controls["SessionType"].Text = "| $SessionType"
		
		#Validate PSWindowsUpdate module is installed
		if ((Test-Connection -ComputerName $Computer -Count 1 -ErrorAction SilentlyContinue) -or ($ComputerName -eq $env:computername)) {
			# Start comment here if administrators do not have internet access
			
			$GetPSWindowsUpdateModule = {
				$ModulePresent = get-module -ListAvailable -name pswindowsupdate -ErrorAction SilentlyContinue
				
				If (-Not $ModulePresent) {
					$repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
					if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
						Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
					}
					
					Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -AllowClobber
				}
			}
			
			Write-OutputBox "Validating PSWindowsUpdate module installed..."
			
			IF ($SessionType -eq "Local") {
				Invoke-Command -ScriptBlock $GetPSWindowsUpdateModule
				Import-Module PSWindowsUpdate -PassThru | out-null
			} else {
				Invoke-Command -ComputerName $Computer -ScriptBlock $GetPSWindowsUpdateModule #-UseSSL -Credential $cred
			}
			
		<# If administrators do not have access to the internet, uncomment this section of code and comment out the above code, 
		   then manually stage the PSWindowsUpdate module in the modules directory. The process will then copy the module to the 
		   "C:\Program Files\WindowsPowerShell\Modules" directory if it is not already present.
		
		$ModuleSourcePath = "$ScriptDirectory\Modules\PSWindowsUpdate"
		$ComputerModulePath = "C:\Program Files\WindowsPowerShell\Modules"
		$FileProperties = Get-ItemProperty "$ModuleSourcePath\*\PSWindowsUpdate.dll"
		$ModuleVersion = $FileProperties.VersionInfo.FileVersion
		
		Write-OutputBox "Validating module version...".Trim()
		$controls["Status"].Text = "Status: Validating module version..."
		
		$GetModuleScript = {
			$ModuleResult = get-module -ListAvailable -name pswindowsupdate -ErrorAction SilentlyContinue | where-object { $_.ModuleBase -like "$ComputerModulePath\*" }
			
			If ($ModuleResult) {
				$ModuleResult
			} 
		}
		
		IF ($SessionType -eq "Local") {
			$ComputerModuleVersion = (Invoke-Command -ScriptBlock $GetModuleScript).Version
		} else {
			$ComputerModuleVersion = Invoke-Command -ComputerName $Computer -UseSSL -Credential $cred -ScriptBlock $GetModuleScript #).Version
			
			If (-Not $ComputerModuleVersion) {
				$ComputerModuleVersion = 0
				$ComputerModulePath = $ComputerModulePath.Replace("C:","\\$Computer\c`$")
			}
		}
		
		IF ($ComputerModuleVersion -ne $ModuleVersion) {
			Write-OutputBox "   Module outdated. Upgrading to version $ModuleVersion..."
			Copy-Item -Path $ModuleSourcePath -Destination $ComputerModulePath -Recurse -Force
		} else {
			Write-OutputBox "   Module version $($ModuleVersion) current."
		}
		
		IF ($SessionType -eq "Local") {
			Import-Module PSWindowsUpdate -PassThru | out-null
		}
		#>
		} Else {
			Write-OutputBox "   Computer offline: '$ComputerName'"
			Return
		}
		
		Write-OutputBox "Getting Windows Update Settings...".Trim()
		$controls["Status"].Text = "Status: Getting Windows Update Settings..."
		
		$wsusCheck = {
			$WindowsUpdateKey = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate"
			
			if (Test-Path $WindowsUpdateKey) {
				$WUServer = Get-ItemProperty -Path $WindowsUpdateKey -Name "WUServer" -ErrorAction SilentlyContinue
				if ($WUServer.WUServer) {
					$WSUSServer = $WUServer.WUServer
				} else {
					$WSUSServer = $null
				}
			} else {
				$WSUSServer = $null
			}
			
			$WSUSServer
		}
		
		IF ($SessionType -eq "Local") {
			If (-Not (Get-Module PSWindowsUpdate)) {
				Import-Module PSWindowsUpdate
			}
			
			$WSUSServer = Invoke-Command -ScriptBlock { $wsusCheck }
			$CMClient = Get-CimInstance -Namespace "root\ccm\clientsdk" -ClassName "CCM_Client" -ErrorAction SilentlyContinue | Select-Object -Property ClientActiveStatus
		} Else {
			$WSUSServer = Invoke-Command -ComputerName $Computer -ScriptBlock { $wsusCheck } #-UseSSL -Credential $cred
			
			$RemoteCimSession = New-CimSession -ComputerName $computer #-Credential $cred
			$CMClient = Get-CimInstance -CimSession $RemoteCimSession -Namespace "root\ccm\clientsdk" -ClassName "CCM_Client" -ErrorAction SilentlyContinue | Select-Object -Property ClientActiveStatus
			Remove-CimSession -CimSession $RemoteCimSession
		}
		
		If ($CMClient) {
			$Global:CMClientPresent = $True
		} else {
			$Global:CMClientPresent = $False
		}
		
		If ($CMClient -and ($Null -ne $wsusServer)) {
			$UpdateMethod = "CM Update"
			$Groupboxes["CMUpdate"].Visibility = [System.Windows.Visibility]::Visible #Collapsed, Visible
			Update-ButtonState -State Enabled -ButtonPurpose "CMUpdate"
		} Else {
			$UpdateMethod = "MS Update"
			$Groupboxes["CMUpdate"].Visibility = [System.Windows.Visibility]::Collapsed #Hidden, Visible
			Update-ButtonState -State Disabled -ButtonPurpose "CMUpdate"
		}
		
		Write-OutputBox "   Update method: $UpdateMethod"
		$controls["UpdateMethod"].Text = "| $UpdateMethod"
		
		$window.Title = "pXLabs Windows Update Tool - $ComputerName ($SessionType | $UpdateMethod)"
		
		Write-OutputBox "Getting disk space...".Trim()
		$controls["Status"].Text = "Status: Getting disk space..."
		
		IF ($SessionType -eq "Local") {
			$Diskspace = (Get-PSDrive C) | Select-Object Used, Free
		} Else {
			$Diskspace = Invoke-Command -ComputerName $Computer -ScriptBlock {
				Get-PSDrive C
			} <# -UseSSL -Credential $cred #> | Select-Object Used, Free
		}
		
		$DiskspaceText = "$([Math]::Round($Diskspace.Used / 1GB))GB Used / $([Math]::Round($Diskspace.Free / 1GB))GB Free"
		Write-OutputBox "   $DiskspaceText"
		$controls["Diskspace"].Text = "| $DiskspaceText"
		
		$controls["Status"].Text = "Status: Ready"
	}
	
	Invoke-Command -ScriptBlock $SessionLoad
	#endRegion
	
	$window.add_Closing({
			[Win32.Functions]::ShowWindow($hWnd, $SW_SHOW)
			Start-AppCleanup
			$window.Resources.MergedDictionaries.Clear()			
		})
	
	# Show Window
	$window.ShowDialog()
}
	