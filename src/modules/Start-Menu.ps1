# ===============================
# Hyper-V Management Tool Menu
# ===============================

function Show-Menu {
    param (
        [string[]] $options,
        [int] $currentOption,
        [int] $menuTop
    )

    $windowWidth = [Console]::WindowWidth

    for ($i = 0; $i -lt $options.Count; $i++) {
        $linePosition = $menuTop + $i
        [Console]::SetCursorPosition(0, $linePosition)
        [Console]::Write(" " * ($windowWidth - 1))
        [Console]::SetCursorPosition(0, $linePosition)

        if ($i -eq $currentOption) {
            Write-Host "> $($options[$i])" -ForegroundColor Yellow
        }
        else {
            Write-Host "  $($options[$i])" -ForegroundColor Gray
        }
    }
}

function Start-Menu {
    param (
        [string[]] $options,
        [string] $title = "Please select an option:",
        [int] $DefaultIndex = 0
    )

    if (-not $options -or $options.Count -eq 0) {
        throw "Start-Menu: You must provide at least one option."
    }

    # listen to key presses
    $currentOption = $DefaultIndex
    $menuTop = [Console]::CursorTop + 2
    $exitMenu = $false
    $selectedOption = $null
    $windowWidth = [Console]::WindowWidth
    $windowHeight = [Console]::WindowHeight
    $menuHeight = $options.Count + 2
    $menuBottom = $menuTop + $menuHeight - 1
    $titleLines = $title -split "`n"
    $titleHeight = $titleLines.Count + 1
    $totalMenuHeight = $titleHeight + $menuHeight
    $titleTop = $menuTop - $titleHeight
    $titleBottom = $menuTop - 1
    $initialCursorTop = [Console]::CursorTop
    $initialCursorLeft = [Console]::CursorLeft
    $initialBufferHeight = [Console]::BufferHeight
    $initialBufferWidth = [Console]::BufferWidth
    $initialWindowHeight = [Console]::WindowHeight
    $initialWindowWidth = [Console]::WindowWidth
    $needToRedraw = $true
    $keyInfo = $null
    $originalTitle = [Console]::Title
    [Console]::Title = $title

    # Adjust buffer size if necessary
    if ($initialBufferHeight -lt $initialWindowHeight + $totalMenuHeight) {
        [Console]::BufferHeight = $initialWindowHeight + $totalMenuHeight
    }
    if ($initialBufferWidth -lt $initialWindowWidth) {
        [Console]::BufferWidth = $initialWindowWidth
    }
    # Adjust window size if necessary
    if ($initialWindowHeight -lt $totalMenuHeight + 2) {
        [Console]::WindowHeight = [Math]::Min($initialBufferHeight, $totalMenuHeight + 2)
    }
    if ($initialWindowWidth -lt 50) {
        [Console]::WindowWidth = [Math]::Min($initialBufferWidth, 50)
    }
    # Main loop
    while (-not $exitMenu) {
        if ($needToRedraw) {
            # Draw title
            for ($i = 0; $i -lt $titleLines.Count; $i++) {
                $linePosition = $titleTop + $i
                [Console]::SetCursorPosition(0, $linePosition)
                [Console]::Write(" " * ($windowWidth - 1))
                [Console]::SetCursorPosition(0, $linePosition)
                Write-Host $titleLines[$i] -ForegroundColor Cyan
            }
            [Console]::SetCursorPosition(0, $titleBottom)
            [Console]::Write(" " * ($windowWidth - 1))
            [Console]::SetCursorPosition(0, $titleBottom)
            Write-Host ("=" * ($windowWidth - 1)) -ForegroundColor Cyan

            # Draw menu
            Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
            $needToRedraw = $false
        }

        # Read key input
        $keyInfo = [Console]::ReadKey($true)

        switch ($keyInfo.Key) {
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
                $selectedOption = $options[$currentOption]
                $exitMenu = $true
            }
            'D1'.'D9' {
                $index = [int]$keyInfo.KeyChar - 1
                if ($index -ge 0 -and $index -lt $options.Count) {
                    $currentOption = $index
                    Show-Menu -options $options -currentOption $currentOption -menuTop $menuTop
                    $selectedOption = $options[$currentOption]
                    $exitMenu = $true
                }
            }
            'Escape' {
                $selectedOption = $null
                $exitMenu = $true
            }
        }
    }
    # Cleanup
    [Console]::SetCursorPosition(0, $menuBottom + 1)
    [Console]::Write(" " * ($windowWidth - 1))
    [Console]::SetCursorPosition(0, $menuBottom + 1)
    [Console]::Title = $originalTitle
    [Console]::SetCursorPosition($initialCursorLeft, $initialCursorTop)
    [Console]::BufferHeight = $initialBufferHeight
    [Console]::BufferWidth = $initialBufferWidth
    [Console]::WindowHeight = $initialWindowHeight
    [Console]::WindowWidth = $initialWindowWidth
    return $selectedOption
}
