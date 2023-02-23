enum Visibility : byte {
    Default = 0
    Hide    = 1
    Show    = 2
}

function Convert-CeaserCipher {
    <#
    .SYNOPSIS
        Convert a string to and from a ceaser cipher (ROT-13) encoding.

    .DESCRIPTION
        Convert a string to and from a ceaser cipher (ROT-13) encoding.

    #>

    [CmdletBinding()]
    param (
        # The string to encode or decode.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$String
    )

    process {
        $chars = foreach ($char in $string.ToCharArray()) {
            if ($char -notmatch '[a-z]') {
                $char
                continue
            }

            $decrement = ($char -ge 'A' -and $char -le 'Z' -and $char -gt 'M') -or
                ($char -ge 'a' -and $char -le 'z' -and $char -gt 'm')

            if ($decrement) {
                [int]$char - 13
            } else {
                [int]$char + 13
            }
        }
        [string]::new([char[]]$chars)
    }
}

function Resolve-KnownFolder {
    <#
    .SYNOPSIS
        Resolve GUID known folder values to full paths.

    .DESCRIPTION
        Resolve GUID known folder values to full paths.
    #>

    [CmdletBinding()]
    param (
        # A path containing a GUID to resolve.
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )

    begin {
        if (-not ('KnownFolder' -as [Type])) {
            Add-Type -TypeDefinition '
            using System;
            using System.Runtime.InteropServices;
            
            internal class UnsafeNativeMethods
            {
                [DllImport("shell32.dll")]
                internal static extern int SHGetKnownFolderPath(
                    [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
                    uint dwFlags,
                    IntPtr hToken,
                    out IntPtr ppszPath
                );
            }
            
            public class KnownFolder {
                public static string GetPath(Guid guid)
                {
                    IntPtr ppszPath = IntPtr.Zero;
                    UnsafeNativeMethods.SHGetKnownFolderPath(
                        guid,
                        0,
                        IntPtr.Zero,
                        out ppszPath
                    );
                    string path = Marshal.PtrToStringUni(ppszPath);
                    Marshal.FreeCoTaskMem(ppszPath);
            
                    return path;
                }
            }
            '
        }
    }
    
    process {
        $pathElements = $Path -split '[\\/]'
        if ($guid = $pathElements[0] -as [Guid]) {
            $pathElements[0] = [KnownFolder]::GetPath($guid)
            $Path = [System.IO.Path]::Combine($pathElements)
        }
        $Path
    }
}

function Get-SystemTrayIcon {
    <#
    .SYNOPSIS
        Get system tray icon visibility.
    
    .DESCRIPTION
        Get system tray icon visibility using the IconStreams value in the registry.
    #>

    [CmdletBinding()]
    param (
        # The path for the system tray icon. By default app paths are displayed.
        [string]$Path = '*'
    )

    $registryPath = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
    $iconStreams = Get-ItemPropertyValue -Path $registryPath -Name IconStreams
    # The flag for visibility appears at offset 528
    $systemTrayToggleOffset = 528

    # The iconStreams array has a 20 byte header, followed by 1640 byte records describing each icon.
    for ($i = 20; $i -lt $iconStreams.Count; $i += 1640) {
        # The path is Unicode encoded and null terminated.
        $iconPathBytes = for (($j = 0), ($isChar = $true); $isChar; $j += 2) {
            $left = $iconStreams[$i + $j]
            $right = $iconStreams[$i + $j + 1]

            $isChar = $left -ne 0 -or $right -ne 0
            if ($isChar) {
                $left, $right
            }
        }
        $iconPath = [System.Text.Encoding]::Unicode.GetString([byte[]]$iconPathBytes) | Convert-CeaserCipher

        if ($iconPath -like $Path) {
            [PSCustomObject]@{
                PSTypeName = 'IconStreamsRecord'
                Visibility = [Visibility]$iconStreams[$i + $systemTrayToggleOffset]
                Offset     = $i
                Path       = Resolve-KnownFolder $iconPath
            }
        }
    }
}

function Backup-SystemTrayIcon {
    <#
    .SYNOPSIS
        Create a backup of the System Tray Icon configuration (IconStreams).

    .DESCRIPTION
        Create a backup of the System Tray Icon configuration (IconStreams).

    #>

    [CmdletBinding()]
    param ( )

    $registryPath = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
    $value = Get-ItemPropertyValue $registryPath -Name IconStreams
    New-ItemProperty -Path $registryPath -Name IconStreams_Backup -Value $value -Force
}

function Restore-SystemTrayIcon {
    <#
    .SYNOPSIS
        Restore an existing backup of the System Tray Icon configuration (IconStreams).

    .DESCRIPTION
        Restore an existing backup of the System Tray Icon configuration (IconStreams).

    #>

    [CmdletBinding()]
    param ( )

    $registryPath = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
    $value = Get-ItemPropertyValue $registryPath -Name IconStreams_Backup
    if ($value) {
        Set-ItemProperty -Path $registryPath -Name IconStreams -Value $value
    } else {
        Write-Error 'IconStreams backup does not exist!'
    }
}

function Set-SystemTrayIcon {
    <#
    .SYNOPSIS
        Set system tray icon visibility.
    
    .DESCRIPTION
        Set system tray icon visibility using the IconStreams value in the registry.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [SupportsWildcards()]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'FromPipeline')]
        [PSTypeName('IconStreamsRecord')]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [Visibility]$Visibility
    )

    begin {
        $registryPath = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
        $systemTrayToggleOffset = 528

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Get-SystemTrayIcon -Path $Path | Set-SystemTrayIcon -Visibility $Visibility
            return
        }

        $iconStreams = Get-ItemPropertyValue -Path $registryPath -Name IconStreams
        $shouldUpdate = $false
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            return
        }

        if ($InputObject.Visibility -ne $Visibility) {
            $shouldUpdate = $true
            $iconStreams[$InputObject.Offset + $systemTrayToggleOffset] = $Visibility.value__
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            return
        }
        if ($shouldUpdate) {
            Set-ItemProperty -Path $registryPath -Name IconStreams -Value $iconStreams
        }
    }
}