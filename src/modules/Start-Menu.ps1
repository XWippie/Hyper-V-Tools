function Show-Menu {
    <#
    .SYNOPSIS
    Displays a menu with options and highlights the current selection.
    .DESCRIPTION
    This function takes an array of options and the index of the currently selected option.
    It displays the options in the console, highlighting the selected option.
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string[]] $options,

        [parameter(Mandatory)]
        [int] $currentOption,

        [int] $Top = [Console]::CursorTop  # where to draw
    )

    # Save the current cursor position
    $cursorLeft = [Console]::CursorLeft
    $cursorTop = [Console]::CursorTop

    # Move cursor back to the menu’s top
    [Console]::SetCursorPosition(0, $Top)

    for ($i = 0; $i -lt $options.Length; $i++) {
        if ($i -eq $currentOption) {
            Write-Host ("> " + $options[$i]).PadRight([Console]::WindowWidth) -ForegroundColor Green
        }
        else {
            Write-Host ("  " + $options[$i]).PadRight([Console]::WindowWidth)
        }
    }

    # Clear any remaining lines from previous longer menu
    [Console]::SetCursorPosition($cursorLeft, $cursorTop)
}

function Start-Menu {
    <#
    .SYNOPSIS
    Starts the interactive menu and handles user input.
    .DESCRIPTION
    This function initializes the menu, captures user input for navigation,
    and returns the selected option when the user presses Enter.
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [parameter(Mandatory)]
        [string[]] $options,

        [string] $title = "Select an option:",


        [int] $DefaultIndex = 0
    )

    if (-not $options -or $options.Count -eq 0) {
        throw "Start-Menu: You must provide at least one option."
    }

    Write-Host "`n===============================" -ForegroundColor Yellow
    Write-Host "Use Up/Down arrows or number keys to navigate, Enter to select." -ForegroundColor Yellow
    Write-Host $title -ForegroundColor Yellow

    $currentOption = [Math]::Min($DefaultIndex, $options.Length - 1)
    $menuTop = [Console]::CursorTop  # remember where to draw menu


    Show-Menu -options $options -CurrentOption $currentOption -Top $menuTop

    while ($true) {
        $key = [Console]::ReadKey($true).Key
        switch ($key) {
            'UpArrow' {
                if ($currentOption -gt 0) {
                    $currentOption--
                }
                else {
                    $currentOption = $options.Length - 1
                }
            }
            'DownArrow' {
                if ($currentOption -lt $options.Length - 1) {
                    $currentOption++
                }
                else {
                    $currentOption = 0
                }
            }
            { $_ -match '^D[0-9]$' } {
                $num = [int]($_.ToString().Substring(1))
                if ($num -gt 0 -and $num -le $options.Length) {
                    $currentOption = $num - 1
                }
            }
            { $_ -match '^NumPad[0-9]$' } {
                $num = [int]($_.ToString().Substring(6))
                if ($num -gt 0 -and $num -le $options.Length) {
                    $currentOption = $num - 1
                }
            }
            'Enter' {
                [Console]::SetCursorPosition(0, $menuTop + $options.Length)
                return $options[$currentOption]
            }
        }
        Show-Menu -options $options -CurrentOption $currentOption -Top $menuTop
    }
}
