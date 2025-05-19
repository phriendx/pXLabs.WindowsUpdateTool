function Start-AppCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    if ($PSCmdlet.ShouldProcess("Application", "Perform cleanup")) {
        Write-OutputBox "Performing cleanup..."
        
        # Stop and dispose timers
        if ($timerJobTracker -and $timerJobTracker.Enabled) {
            $timerJobTracker.Stop()
            $timerJobTracker.Dispose()
        }

        # Stop animations or storyboards
        if ($storyboard) {
            $storyboard.Stop()
        }

        # Dispose PowerShell runspaces/jobs
        if ($PSCmdlet.ShouldProcess("Background Jobs", "Remove all jobs")) {
            Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        # Close any remote sessions
        if ($session -and $session.State -eq 'Opened') {
            if ($PSCmdlet.ShouldProcess("Remote session", "Remove PSSession")) {
                Remove-PSSession -Session $session
            }
        }

        # Clear variables (optional)
        Remove-Variable timerJobTracker, session, storyboard -ErrorAction SilentlyContinue

        Write-OutputBox "   Cleanup complete."
    }
}
