<#
.SYNOPSIS
    This is a script to manage and monitor Hyper-V virtual machines and clusters.
.DESCRIPTION
    This script provides an interactive menu to perform various tasks related to Hyper-V management.
    It includes functions to display a menu, handle user input, and execute selected options.   
.NOTES
    Author: Your Name
    Date: 2024-06-15
    Version: 1.0
    Requires: PowerShell 5.1 or later
#>

# Import the Start-Menu module
. "$PSScriptRoot/modules/Start-Menu.ps1"

$version = "v1.0.0"

Clear-Host

# Banner
$banner = @"
======================================================
       Hyper-V Management Tool
======================================================

Version : $version
Author  : Xander Waeghe
GitHub  : https://github.com/XWippie/HyperV-Tools
Date    : 18/09/2025

======================================================
"@

$goodbye = @"
======================================================
   Thank you for using Hyper-V Tools!
   Hope to see you again soon!
   Goodbye!

   Don't forget to check out the GitHub page:
   https://github.com/XWippie
======================================================
"@

Write-Host $banner -ForegroundColor Cyan

# Define the menu options
$menuOptions = @(
    "1 > View Information"
    "2 > Config"
    "3 > Exit"
)
# Start the menu and capture the selected option
$selectedOption = Start-Menu -Options $menuOptions -Title "Please what you want to do:"

Start-Sleep -Milliseconds 100

Clear-MenuRegion -Top $selectedOption.MenuTop -Height $selectedOption.MenuHeight

# Move cursor under welcome bar
[Console]::SetCursorPosition(0, $selectedOption.MenuTop)


# Handle the selected option
switch ($selectedOption.Option) {
    "1 > View Information" {
        Write-Host "Sorry, vieuwing information is not yet implemented." -ForegroundColor Yellow
        Write-Host "Returning to main menu..." -ForegroundColor Green
        Start-Sleep -Seconds 1.5
        & "$PSScriptRoot\main.ps1"
    }
    "2 > Config" {
        $menuOptions = @(
            "1 > Set basic configuration"
            "2 > Back to main menu"
            "3 > Exit"
        )

        $selectedOption = Start-Menu -Options $menuOptions -Title "Configuration Menu:"
        Clear-MenuRegion -Top $selectedOption.MenuTop -Height $selectedOption.MenuHeight
        [Console]::SetCursorPosition(0, $selectedOption.MenuTop)
        Write-Host "You selected: $($selectedOption.Option)" -ForegroundColor Green
        switch ($selectedOption.Option) {
            "1 > Set basic configuration" {
                Write-Host "Starting basic configuration..." -ForegroundColor Green
                Start-Sleep -Milliseconds 500
                & "$PSScriptRoot\modules\Set-BasicConfig.ps1"
            }
            "2 > Back to main menu" {
                Write-Host "Returning to main menu..." -ForegroundColor Green
                Start-Sleep -Milliseconds 500
                & "$PSScriptRoot\main.ps1"
            }
            "3 > Exit" {
                Clear-Host
                Write-Host $goodbye -ForegroundColor Yellow
                exit
            }
        }
    }
    "3 > Exit" {
        Clear-Host
        Write-Host $goodbye -ForegroundColor Yellow
        exit
    }
}

# animation for momvemtn of 67
# emaplde
# 1 -_<. .>__
# 2 __<. .>_-
# 1 and 2 alternated with sleep of 100ms for 2 seconds