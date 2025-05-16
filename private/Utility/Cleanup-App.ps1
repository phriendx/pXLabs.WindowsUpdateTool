function Cleanup-App {
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
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    
    # Close any remote sessions
    if ($session -and $session.State -eq 'Opened') {
        Remove-PSSession -Session $session
    }
    
    # Clear variables (optional)
    Remove-Variable timerJobTracker, session, storyboard -ErrorAction SilentlyContinue
    
    Write-OutputBox "   Cleanup complete."
}