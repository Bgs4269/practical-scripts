#
# Discord doesn't have a native way to configure a proxy for its connections, but has the functionality.
# If you have a http/https proxy, you can use this script to launch Discord using that.
#
# The only two things you need to set are:
# - the proxyHostIP, the IP address of the proxy, which can use a hostname if you can resolve it.
# - the proxyPort, which is the TCP port on which the proxy is accepting connections.
#
# The script will log its output into your Documents directory. If you want to place it somewhere else
# comment out the first LogFilePath line, and user the second one to explicitly set your chosen file path.


#
# Optional steps
#
# How to set up to run on startup:
#
# 1. Disable auto start within Discord
# 2. Save this script somewhere in your system
# 3. Create a startup link with the following:
#		C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "D:\path\to\script\discord-start-with-proxy.ps1"
# 		Replace the path with your location.
#
# How to disable Discord's default auto star:
# - Go to settings -> App settings -> Windows Settings
# - In section "System Start-Up Behaviour"
# - Set "Open Discord" to off/disabled.
#
# How to create a startup link (generic Windows):
# 1. Press Win-R
# 2. Type shell:startup
# 3. In the new explorer window chose New->Shortcut
# 4. Paste the string from 3 above (with the correct path.)
#
# Notes:
# - You may need to enable the ability to run powershell scripts. Some systems have it disabled by policy.
#	See: https://learn.microsoft.com/en-gb/powershell/module/microsoft.powershell.core/about/about_execution_policies
#

# --- Configuration Variables ---
$proxyHostIP = "172.18.18.1"
$proxyPort = "4242"
$LogFilePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "discord-proxy-start.log"
#$logFilePath = "X:\your\log\path\my-discord.log"
# --- End Configuration Variables ---

######################################
# Nothing to change below this point #
######################################

# --- Function to write to log file ---
# This function takes a message and appends it to the specified log file.
# It also includes a timestamp for each log entry.
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"

    try {
        # Append the log entry to the file.
        # -Path: Specifies the path to the log file.
        # -Value: The content to append.
        # -Force: Creates the file if it doesn't exist.
        # -Encoding UTF8: Ensures proper character encoding.
        Add-Content -Path $LogFilePath -Value $LogEntry -Force -Encoding UTF8

        # Optionally, you can still display the message to the console
        # for real-time feedback during script execution, but it's not
        # strictly necessary if all output should go to the log.
        # Write-Log $LogEntry -ForegroundColor Green

    } catch {
        # Handle any errors that occur during file writing.
        Write-Log "ERROR: Could not write to log file '$LogFilePath'. Details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Autodetect the base path for Discord using the LOCALAPPDATA environment variable
# $env:LOCALAPPDATA typically resolves to C:\Users\<current_username>\AppData\Local
try {
    if (-not ($env:LOCALAPPDATA)) {
        throw "The LOCALAPPDATA environment variable is not set."
    }
    $basePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Discord"

    if (-not (Test-Path -Path $basePath -PathType Container)) {
        throw "Discord directory not found at the expected location: $basePath"
    }
}
catch {
    Write-Log "ERROR: Error determining Discord base path: $($_.Exception.Message)"
    # Exit the script if the base path can't be determined or found
    exit 1
}


Write-Log "Using Discord base path: $basePath"

# Find all app directories and sort them by version to get the latest
$latestAppDir = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue -Directory |
                Where-Object {$_.Name -match "^app-\d+\.\d+\.\d+$"} |
                Sort-Object -Property @{Expression = {[version]($_.Name -replace 'app-','')}} -Descending |
                Select-Object -First 1

# Check if a valid app directory was found
if ($latestAppDir) {
    $discordExePath = Join-Path -Path $latestAppDir.FullName -ChildPath "Discord.exe"

    # Assemble the Discord arguments using the proxy variables
    $discordArguments = "--processStart Discord.exe --proxy-server=http://$($proxyHostIP):$($proxyPort)"

    # Assemble the full command that cmd.exe's 'start' command will execute.
    # The executable path ($discordExePath) is enclosed in its own set of double quotes
    # to handle any spaces in the path. The 'start' command's title is also quoted.
    $commandToExecuteByCmd = "start /B `"Discord-Starter`" `"`"$($discordExePath)`"`" $discordArguments"

    Write-Log "Located latest Discord version at: $($latestAppDir.FullName)"
    Write-Log "Proxy Server: http://$($proxyHostIP):$($proxyPort)"
    Write-Log "Attempting to start: `"$discordExePath`" with arguments: `"$discordArguments`""
    Write-Log "Executing via cmd.exe with command: /c $commandToExecuteByCmd"

    # Start the process using cmd.exe's 'start /B' command.
    # 'start /B' runs the application without creating a new window for it and makes it non-blocking.
    # 'Start-Process -WindowStyle Hidden' ensures that the cmd.exe process itself doesn't flash a visible window.
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $commandToExecuteByCmd" -WindowStyle Hidden -ErrorAction Stop
        Write-Log "Discord launch command has been sent."
        Write-Log "Discord should now be running in the background, and no new console window should have been created for its launch."
        Write-Log "Note: Discord's own graphical user interface (GUI) will appear as it normally does."
    } catch {
        Write-Log "ERROR: Failed to start Discord. Error: $($_.Exception.Message)"
    }
} else {
    # This message will show if $basePath was invalid or if no matching app- folders were found
	Write-Log "ERROR: Could not find any Discord app directory matching the pattern 'app-x.x.xxxx' in '$basePath'."
    Write-Log "WARNING: Please ensure Discord is installed correctly and the path '$basePath' is accessible."
}
