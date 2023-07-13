# Copyright (c) 2020 Privatise LTD
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the Privatise LTD nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Privatise LTD BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# The Privatise installer needs a PARTNERID  and a TEAMID (a company
# specified name or description) which is used to affiliate an Agent with a
# specific Organization within the Privatise Partner's Account. These keys can be
# hard coded below or passed in when the script is run.

# Usage:
# powershell -executionpolicy bypass -f ./InstallPrivatise.powershellv1.ps1 [-PARTNERID <PARTNERID>] [-TEAMID <TEAMID>]

# Optional command line params, this has to be the first line in the script.
param (
  [string]$partnerid,
  [string]$teamid,
  [switch]$reregister,
  [switch]$reinstall
)

# The account key should be stored in the DattoRMM account variable Privatise_PARTNERID
$PARTNERID = "__PARTNERID__"
if ($env:Privatise_PARTNERID) {
    $PARTNERID = $env:Privatise_PARTNERID
}

# Use the CS_PROFILE_NAME environment variable as the TEAMID
# This should always be set by the DattoRMM agent. If not, there is likely
# an issue with the agent.
$TEAMID = $env:CS_PROFILE_NAME
if (!$env:CS_PROFILE_NAME) { $TEAMID = 'MISSING_CS_PROFILE_NAME' }

# Set to "Continue" to enable verbose logging.
$DebugPreference = "SilentlyContinue"

##############################################################################
## The following should not need to be adjusted.

# Find poorly written code faster with the most stringent setting.
Set-StrictMode -Version Latest

# Do not modify the following variables.
# These are used by the Privatise support team when troubleshooting.
$ScriptVersion = "2020 October 1; revision 1"
$ScriptType = "DattoRMM"

# Check for an account key specified on the command line.
if ( ! [string]::IsNullOrEmpty($partnerid) ) {
    $PARTNERID = $partnerid
}

# Check for an organization key specified on the command line.
if ( ! [string]::IsNullOrEmpty($teamid) ) {
    $TEAMID = $teamid
}

# Variables used throughout the Privatise Deployment Script.
$X64 = 64
$X86 = 32
$InstallerName = "PrivatiseInstaller.exe"
$InstallerPath = Join-Path $Env:TMP $InstallerName
$DebugLog = Join-Path $Env:TMP PrivatiseInstaller.log
$DownloadURL = "https://privatise-main-storage.s3.us-east-2.amazonaws.com/binaries/RMM/PrivatiseInstaller.exe"
$PrivatiseAgentServiceName = "PrivatiseAgent"
$PrivatiseUpdaterServiceName = "PrivatiseUpdater"

$CertSigner = 'COMODO RSA Extended Validation Code Signing CA'
$CertThumbprint = '351A78EBC1B4BB6DC366728D334231ABA9AE3EA7'
$PowerShellArch = $X86
# 8 byte pointer is 64bit
if ([IntPtr]::size -eq 8) {
   $PowerShellArch = $X64
}

$ScriptFailed = "Script Failed!"
$SupportMessage = "Please send the error message to the Privatise Team for help at support@Privatise.com"

function Get-TimeStamp {
    return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)
}

function LogMessage ($msg) {
    Add-Content $DebugLog "$(Get-TimeStamp) $msg"
    Write-Host "$(Get-TimeStamp) $msg"
}

function Test-Parameters {
    LogMessage "Verifying received parameters..."

    # Ensure mutually exclusive parameters were not both specified.
    if ($reregister -and $reinstall) {
        $err = "Cannot specify both `-reregister` and `-reinstall` parameters, exiting script!"
        LogMessage $err
        exit 1
    }

    # Ensure we have an account key (either hard coded or from the command line params).
    if ($PARTNERID -eq "__PARTNERID__") {
        $err = (
            "PARTNERID not set! Please verify that you have created a " +
            "Privatise_PARTNERID variable on your Account Settings page " +
            "within DattoRMM.")
        LogMessage $err
        throw $ScriptFailed + " " + $err
        exit 1
    } elseif ($PARTNERID.length -ne 5) {
        $len = $PARTNERID.length
        $err = "Invalid PARTNERID specified (incorrect length: expected 5, found $len)!"
        LogMessage $err
        throw $ScriptFailed + " " + $err
        exit 1
    }

    # Ensure we have an organization key (either hard coded or from the command line params).
    if ($TEAMID -eq "__TEAMIDID__") {
        $err = "TEAMID not specified!"
        LogMessage $err
        throw $ScriptFailed + " " + $err
        exit 1
    } elseif ($TEAMID.length -lt 1) {
        $err = "Invalid TEAMID specified (length is 0)!"
        LogMessage $err
        throw $ScriptFailed + " " + $err
        exit 1
    }
}

function Confirm-ServiceExists ($service) {
    if (Get-Service $service -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Confirm-ServiceRunning ($service) {
    $arrService = Get-Service $service
    $status = $arrService.Status.ToString()
    if ($status.ToLower() -eq 'running') {
        return $true
    }
    return $false
}

function Get-WindowsArchitecture {
    if ($env:ProgramW6432) {
        $WindowsArchitecture = $X64
    } else {
        $WindowsArchitecture = $X86
    }

    return $WindowsArchitecture
}

function verifyInstaller ($file) {
    # Ensure the installer was not modified during download by validating the file signature.
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        $err = (
            "ERROR: '$file' did not contain a valid digital certificate. " +
            "Something may have corrupted/modified the file during the download process. " +
            "If the problem persists please file a support ticket.")
        LogMessage $err
        LogMessage $SupportMessage
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    }

    # verify installer certificate
    $varIntermediate=($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$CertSigner"}).Thumbprint

    if ($varIntermediate -ne $CertThumbprint) {
        $err = (
            "ERROR: '$file' did not pass verification checks for its digital signature. " +
            "This could suggest that the certificate used to sign the file " +
            "has changed; it could also suggest tampering in the connection chain.")
        if ($varIntermediate) {
            $err += " received: $varIntermediate; expected: $CertThumbprint"
        }
        LogMessage $err
        LogMessage $SupportMessage
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    } else {
        LogMessage "Digital Signature verification passed..."
    }
}

function Get-Installer {
    $msg = "Downloading installer to '$InstallerPath'..."
    LogMessage $msg

    # Ensure a secure TLS version is used.
    $ProtocolsSupported = [enum]::GetValues('Net.SecurityProtocolType')
    if ( ($ProtocolsSupported -contains 'Tls13') -and ($ProtocolsSupported -contains 'Tls12') ) {
        # Use only TLS 1.3 or 1.2
        LogMessage "Using TLS 1.3 or 1.2..."
        [Net.ServicePointManager]::SecurityProtocol = (
            [Enum]::ToObject([Net.SecurityProtocolType], 12288) -bOR [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        )
    } else {
        LogMessage "Using TLS 1.2..."
        try {
            # In certain .NET 4.0 patch levels, SecurityProtocolType does not have a TLS 1.2 entry.
            # Rather than check for 'Tls12', we force-set TLS 1.2 and catch the error if it's truly unsupported.
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        } catch {
            $msg = $_.Exception.Message
            $err = "ERROR: Unable to use a secure version of TLS. Please verify Hotfix KB3140245 is installed."
            LogMessage $msg
            LogMessage $err
            throw $ScriptFailed + " " + $msg + " " + $err
        }
    }

    $WebClient = New-Object System.Net.WebClient

    try {
        $WebClient.DownloadFile($DownloadURL, $InstallerPath)
    } catch {
        $msg = $_.Exception.Message
        $err = (
            "ERROR: Failed to download the Privatise Installer. Please try accessing $DownloadURL " +
            "from a web browser on the host where the download failed. If the issue persists, please " +
            "send the error message to the Privatise Team for help at support@Privatise.com.")
        LogMessage $msg
        LogMessage $err
        throw $ScriptFailed + " " + $err + " " + $msg
    }

    if ( ! (Test-Path $InstallerPath) ) {
        $err = "ERROR: Failed to download the Privatise Installer from $DownloadURL."
        LogMessage $err
        LogMessage $SupportMessage
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    }

    $msg = "Installer downloaded to '$InstallerPath'..."
    LogMessage $msg
}

function Install-Privatise ($TEAMID) {
    LogMessage "Checking for installer '$InstallerPath'..."
    if ( ! (Test-Path $InstallerPath) ) {
        $err = "ERROR: The installer was unexpectedly removed from $InstallerPath"
        $msg = (
            "A security product may have quarantined the installer. Please check " +
            "your logs. If the issue continues to occur, please send the log to the Privatise " +
            "Team for help at support@PrivatiseLTD.com")
        LogMessage $err
        LogMessage $msg
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    }

    $msg = "Executing installer..."
    LogMessage $msg

    $timeout = 30 # Seconds
    $process = Start-Process $InstallerPath "PARTNERID=`"$PARTNERID`" TEAMID=`"$TEAMID`" /S" -PassThru
    try {
        $process | Wait-Process -Timeout $timeout -ErrorAction Stop
    } catch {
        $process | Stop-Process -Force
        $err = "ERROR: Installer failed to complete in $timeout seconds."
        LogMessage $err
        LogMessage $SupportMessage
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    }
}

function Test-Installation {
    LogMessage "Verifying installation..."

    # Give the agent a few seconds to start and register.
    Start-Sleep -Seconds 8

    # Ensure we resolve the correct Privatise directory regardless of operating system or process architecture.
    $WindowsArchitecture = Get-WindowsArchitecture
    if ($WindowsArchitecture -eq $X86) {
        $PrivatiseDirPath = Join-Path $Env:ProgramFiles "Privatise"
    } elseif ($WindowsArchitecture -eq $X64) {
        $PrivatiseDirPath = Join-Path $Env:ProgramW6432 "Privatise"
    } else {
        $err = "ERROR: Failed to determine the Windows Architecture. Received $WindowsArchitecture."
        LogMessage $err
        LogMessage $SupportMessage
        throw $ScriptFailed + " " + $err + " " + $SupportMessage
    }

    $PrivatiseAgentPath = Join-Path $PrivatiseDirPath "Privatise.exe"
    $PrivatiseUpdaterPath = Join-Path $PrivatiseDirPath "Privatise.exe"
    $WyUpdaterPath = Join-Path $PrivatiseDirPath "Privatise.exe"
    $PrivatiseKeyPath = "HKLM:\SOFTWARE\PrivatiseLTD\Privatise"
    $AgentIdKeyValueName = "AgentId"
    $TEAMIDValueName = "TEAMID"
    $TagsValueName = "Tags"

    # Ensure the critical files were created.
    foreach ( $file in ($PrivatiseAgentPath, $PrivatiseUpdaterPath, $WyUpdaterPath) ) {
        if ( ! (Test-Path $file) ) {
            $err = "ERROR: $file did not exist."
            LogMessage $err
            LogMessage $SupportMessage
            throw $ScriptFailed + " " + $err + " " + $SupportMessage
        }
        LogMessage "'$file' is present."
    }

    LogMessage "Installation verified!"
}

function StopPrivatiseServices {
}

function PrepReregister {
    LogMessage "Preparing to re-register agent..."
}

function main () {
    if ($env:reinstallAgent -eq $true) {
        $reinstall = $true
    }
    if ($env:reregisterAgent -eq $true) {
        $reregister = $true
    }

    LogMessage "Script type: '$ScriptType'"
    LogMessage "Script version: '$ScriptVersion'"
    LogMessage "Host name: '$env:computerName'"
    $os = (get-WMiObject -computername $env:computername -Class win32_operatingSystem).caption.Trim()
    LogMessage "Host OS: '$os'"
    LogMessage "Host Architecture: '$(Get-WindowsArchitecture)'"
    LogMessage "PowerShell Architecture: '$PowerShellArch'"
    if ($reinstall) {
        LogMessage "Re-install agent: '$reinstall'"
    }
    if ($reregister) {
        LogMessage "Re-register agent: '$reregister'"
    }
    LogMessage "Installer location: '$InstallerPath'"
    LogMessage "Installer log: '$DebugLog'"

    # trim keys before use
    $PARTNERID = $PARTNERID.Trim()
    $TEAMID = $TEAMID.Trim()

    Test-Parameters

    LogMessage "PARTNERID: '$PARTNERID'"
    LogMessage "TEAMID: '$TEAMID'"

    if ($reregister) {
        PrepReregister
    } elseif ($reinstall) {
        LogMessage "Re-installing agent..."
        if ( !(Confirm-ServiceExists($PrivatiseAgentServiceName)) ) {
            $err = "The Privatise Agent is NOT installed; nothing to re-install. Exiting."
            LogMessage "$err"
            exit 1
        }
        StopPrivatiseServices
    } else {
        LogMessage "Checking for PrivatiseAgent service..."
        if ( Confirm-ServiceExists($PrivatiseAgentServiceName) ) {
            $err = "The Privatise Agent is already installed. Exiting."
            LogMessage "$err"
            exit 0
        }
    }

    Get-Installer
    Install-Privatise $TEAMID
    Test-Installation
    LogMessage "Privatise Agent successfully installed!"
}

try
{
    main
} catch {
    $ErrorMessage = $_.Exception.Message
    LogMessage $ErrorMessage
    exit 1
}