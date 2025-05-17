@{
    RootModule        = 'pXLabs.UpdateTool.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd456075e-b2be-44a1-aca5-52a059c0c0e6'
    Author            = 'Jeff Pollock'
    CompanyName       = 'pXLabs'
    Copyright         = '(c) 2025 Your Name. All rights reserved.'
    Description       = 'pXLabs.UpdateTool is a user-friendly, WPF-based PowerShell utility designed to simplify and enhance the management of Windows Updates on local and remote systems.'
    PowerShellVersion = '5.1'
	RequiredModules  = @('PSWindowsUpdate')

    FunctionsToExport = @('Start-UpdateTool')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData = @{
        PSData = @{
            Tags         = @('WindowsUpdate', 'Intune', 'WPF', 'PowerShell', 'Diagnostics')
            LicenseUri   = 'https://yourdomain.com/license'
            ProjectUri   = 'https://yourdomain.com/project'
            IconUri      = 'https://yourdomain.com/icon'
            ReleaseNotes = 'Initial release.'
        }
    }
}
