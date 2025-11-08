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


$toolName = "Hyper-V Management Tool"
$version = "v1.0.0"


# Banner
$banner = @"
==========================================
       Hyper-V Management Tool
==========================================

Version : $version
Author  : Xander Waeghe
GitHub  : https://github.com/XWippie/HyperV-Tools
Date    : 18/09/2025

Instructions:
  - Use UP / DOWN arrow keys to navigate the menu
  - Press Enter to select an option
  - Press 1-9 to quickly select an option

==========================================
"@

Write-Host $banner -ForegroundColor Cyan



# Define the menu options
$menuOptions = @(
    "1 > View Information"
    "2 > Network Settings"
    "3 > Virtual Machines"
    "4 > Cluster Management"
    "5 > Advanced Settings (clone, export, import VMs)"
    "6 > Exit"
)
# Start the menu and capture the selected option
$selectedOption = Start-Menu -Options $menuOptions -Title "Please what you want to do:"

# Handle the selected option
switch ($selectedOption) {
    "1 > View Information" {
        Write-Host "You chose to view information." -ForegroundColor Green
    }
    "2 > Network Settings" {
        Write-Host "You chose to manage network settings." -ForegroundColor Green
    }
    "3 > Virtual Machines" {
        Write-Host "You chose to manage virtual machines." -ForegroundColor Green
    }
    "4 > Cluster Management" {
        Write-Host "You chose to manage clusters." -ForegroundColor Green
    }
    "5 > Advanced Settings (clone, export, import VMs)" {
        Write-Host "You chose advanced settings." -ForegroundColor Green
    }
    "6 > Exit" {
        Write-Host "Thank you for using the Powershell Hyper-V Management Tool." -ForegroundColor Yellow
        Write-Host "Hope to see you again soon!" -ForegroundColor Yellow
        Write-Host "Goodbye!" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        exit
    }
    Default {
        Write-Host "Invalid selection." -ForegroundColor Red
    }
}