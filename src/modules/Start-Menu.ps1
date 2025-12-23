function Show-Menu {
    param (
        [string[]] $options,
        [int] $currentOption,
        [int] $menuTop
    )

    $width = [Console]::WindowWidth

    for ($i = 0; $i -lt $options.Count; $i++) {
        [Console]::SetCursorPosition(0, $menuTop + $i)

        if ($i -eq $currentOption) {
            [Console]::ForegroundColor = [ConsoleColor]::Yellow
            $text = "> $($options[$i])"
        }
        else {
            [Console]::ForegroundColor = [ConsoleColor]::Gray
            $text = "  $($options[$i])"
        }

        [Console]::Write($text.PadRight($width - 1))
    }

    [Console]::ResetColor()
}

function Clear-MenuRegion {
    param (
        [int] $Top,
        [int] $Height
    )

    $width = [Console]::WindowWidth

    for ($i = 0; $i -lt $Height; $i++) {
        [Console]::SetCursorPosition(0, $Top + $i)
        [Console]::Write(" " * ($width - 1))
    }

    [Console]::SetCursorPosition(0, $Top)
}

function Start-Menu {
    param (
        [string[]] $options,
        [string] $title
    )

    [Console]::CursorVisible = $false

    $currentOption = 0
    $menuTop = [Console]::CursorTop + 2
    $menuHeight = $options.Count
    $exit = $false
    $selected = $null

    # Draw title
    Write-Host $title -ForegroundColor Cyan
    Write-Host ("=" * [Console]::WindowWidth) -ForegroundColor Cyan

    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop

    while (-not $exit) {
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                if ($currentOption -gt 0) {
                    $currentOption--
                    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
                }
            }
            'DownArrow' {
                if ($currentOption -lt $options.Count - 1) {
                    $currentOption++
                    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
                }
            }
            'Enter' {
                $selected = $options[$currentOption]
                $exit = $true
            }
            'Escape' {
                $exit = $true
            }
        }
    }

    [Console]::CursorVisible = $true

    return [pscustomobject]@{
        Option = $selected
        MenuTop        = $menuTop
        MenuHeight     = $menuHeight
    }
}
