@{
    RootModule        = 'pXLabs.UpdateTool.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd456075e-b2be-44a1-aca5-52a059c0c0e6'
    Author            = 'Jeff Pollock'
    CompanyName       = 'pXLabs'
    Copyright         = '(c) 2025 Your Name. All rights reserved.'
    Description       = 'PowerShell module with WPF GUI for Windows Update diagnostics and Intune integration. Inspired by real-world challenges in remote manual Windows Update management.'
    PowerShellVersion = '5.1'

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
