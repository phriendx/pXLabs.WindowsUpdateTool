function Write-Log {
    [cmdletbinding()]
    Param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [Parameter()]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info",
        [Parameter()]
        [Switch]$NoConsoleOut,
        [Parameter()]
        [String]$ConsoleForeground = 'White',
        [Parameter()]
        [ValidateRange(1, 30)]
        [Int16]$Indent = 0,
        [Parameter()]
        [IO.FileInfo]$Path = "$env:temp\PowerShellLog.log",
        [Parameter()]
        [Switch]$LogToVariable,
        [Parameter()]
        [Switch]$Clobber,
        [Parameter()]
        [String]$EventLogName,
        [Parameter()]
        [String]$EventSource,
        [Parameter()]
        [Int32]$EventID = 1,
        [Parameter()]
        [String]$LogEncoding = "ASCII",
        [Parameter()]
        [switch]$NoTimestamp,
        [Parameter()]
        [string]$UserIdStamp
        
    )
    
    Begin {
    }
    
    Process {
        If ($UserIdStamp) {
            $Message = "$($UserIdStamp) : $Message" #"{0}:$($Message | out-string)" -f $UserIdStamp
        }
        
        try {
            If (-NOT $NoTimestamp) {
                $msg = '{0}{1} : {2} : {3}' -f (" " * $Indent), (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
            } Else {
                $msg = '{0}' -f $Message
            }
            
            if ($NoConsoleOut -eq $false) {
                switch ($Level) {
                    'Error' {
                        Write-Error $msg
                    }
                    'Warn' {
                        Write-Warning $msg
                    }
                    'Info' {
                        #Write-OutputBox ('{0}{1}' -f (" " * $Indent), $Message) -ForegroundColor [System.Drawing.Color]::White #$ConsoleForeground
                    }
                }
            }
            
            if ($Clobber) {
                $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Force
            } else {
                $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Append
            }
            
            if ($EventLogName) {
                if (-not $EventSource) {
                    $EventSource = ([IO.FileInfo]$MyInvocation.ScriptName).Name
                }
                
                if (-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
                    [Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
                }
                
                $log = New-Object System.Diagnostics.EventLog
                $log.set_log($EventLogName)
                $log.set_source($EventSource)
                
                switch ($Level) {
                    "Error" {
                        $log.WriteEntry($msg, 'Error', $EventID)
                    }
                    "Warn"  {
                        $log.WriteEntry($msg, 'Warning', $EventID)
                    }
                    "Info"  {
                        $log.WriteEntry($msg, 'Information', $EventID)
                    }
                }
            }
        } catch {
            throw "Failed to create log entry in: '$Path'. The error was: '$_'."
        }
        
        If ($LogToVariable -and $NoConsoleOut) {
            return $msg
        }
    }
    
    End {
    }
}