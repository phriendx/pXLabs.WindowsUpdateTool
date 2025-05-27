@{
    RootModule        = 'pXLabs.WindowsUpdateTool.psm1'
    ModuleVersion     = '1.0.2'
    GUID              = 'd456075e-b2be-44a1-aca5-52a059c0c0e6'
    Author            = 'Jeff Pollock'
    CompanyName       = 'pXLabs'
    Copyright         = '(c) 2025 Jeff Pollock. All rights reserved.'
    Description       = 'WPF-based PowerShell utility designed to simplify and enhance the management of Windows Updates on local and remote systems. Inspired by real-world challenges in remote manual Windows Update management.'
    PowerShellVersion = '5.1'
	RequiredModules  = @('PSWindowsUpdate')

    FunctionsToExport = @('Start-WindowsUpdateTool')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData = @{
        PSData = @{
            Tags         = @('WindowsUpdate', 'Intune', 'WPF', 'PowerShell', 'Diagnostics')
            LicenseUri   = 'https://www.gnu.org/licenses/gpl-3.0.html'
            ProjectUri   = 'https://github.com/phriendx/pXLabs.UpdateTool'
            IconUri      = 'https://raw.githubusercontent.com/phriendx/pXLabs.UpdateTool/refs/heads/main/resources/WindowsUpdates.ico'
            ReleaseNotes = 'Initial release.'
        }
    }
}
