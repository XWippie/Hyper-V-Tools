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

function animation {
    param (
        [int] $durationMs = 2000,
        [int] $intervalMs = 250
    )

    $personA = @"
 67    67 
    67    67
      O _
    _/|/
     / \
"@

    $personB = @"
     67    67
  67    67
    _ O
     \|\_
     / \
"@


    $endTime = (Get-Date).AddMilliseconds($durationMs)
    $frame = 0

    while ((Get-Date) -lt $endTime) {
        clear-host
        if ($frame % 2 -eq 0) {
            Write-Host $personA -NoNewline
        }
        else {
            Write-Host $personB -NoNewline
        }

        Start-Sleep -Milliseconds $intervalMs
        $frame++
    }

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
    Write-Host ("======================================================") -ForegroundColor Cyan

    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
    
    $lastKey = $null
    $lastTime = Get-Date
    while (-not $exit) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -in @('D6','NumPad6','D7','NumPad7')) {
            $now = Get-Date
            $delta = ($now - $lastTime).TotalMilliseconds
            if ($delta -le 300) {
                if (
                    ($lastKey -in @('D6','NumPad6') -and $key.Key -in @('D7','NumPad7')) -or
                    ($lastKey -in @('D7','NumPad7') -and $key.Key -in @('D6','NumPad6'))
                ) {
                    animation
                    & "$PSScriptRoot\..\main.ps1"
                }
            }

            $lastKey = $key.Key
            $lastTime = $now
        }
        else {
            $lastKey = $null
        }

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

            default {
                $index = $null

                switch ($key.Key) {
                    'D1'      { $index = 0 }
                    'D2'      { $index = 1 }
                    'D3'      { $index = 2 }
                    'D4'      { $index = 3 }
                    'D5'      { $index = 4 }
                    'D6'      { $index = 5 }
                    'D7'      { $index = 6 }
                    'D8'      { $index = 7 }
                    'D9'      { $index = 8 }

                    'NumPad1' { $index = 0 }
                    'NumPad2' { $index = 1 }
                    'NumPad3' { $index = 2 }
                    'NumPad4' { $index = 3 }
                    'NumPad5' { $index = 4 }
                    'NumPad6' { $index = 5 }
                    'NumPad7' { $index = 6 }
                    'NumPad8' { $index = 7 }
                    'NumPad9' { $index = 8 }
                }

                if ($index -ne $null -and $index -lt $options.Count) {
                    $currentOption = $index
                    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
                    $selected = $options[$currentOption]
                    $exit = $true
                }
            }
        }
    }


    [Console]::CursorVisible = $true

    return [pscustomobject]@{
        Option     = $selected
        MenuTop    = $menuTop
        MenuHeight = $menuHeight
    }
}


