<#
.DESCRIPTION
These are some PowerShell examples related to the Windows Terminal app, which
is not installed by default prior to Windows 11.

However, the following steps REQUIRE internet access in order for wt.exe
to actually launch on the machine.  This is a known issue and one which
Microsoft does not seem to care about fixing:
    https://github.com/microsoft/terminal/issues/6010
#>
exit


# Is Windows Terminal already installed?
Get-AppxPackage -Name "Microsoft.WindowsTerminal*" | Select PackageFullName


# Download latest non-preview package from the Assets area at the bottom of the 
# release page for that one package version; the package file name will be
# similar to Microsoft.WindowsTerminal_<versionNumber>.msixbundle:
https://github.com/microsoft/terminal/releases


# Install:
Add-AppxPackage Microsoft.WindowsTerminal_<versionNumber>.msixbundle


# WSUS or Windows Update will not update Terminal.




############################################################################
### The Offline Hackery Kludge
############################################################################

# Download latest non-preview package from the Assets area at the bottom of the 
# release page for that one package version; the package file name will be
# similar to Microsoft.WindowsTerminal_<versionNumber>.msixbundle:
https://github.com/microsoft/terminal/releases

Change the msixbundle extension to zip.

Extract zip contents.

There will be an msix file like CascadiaPackage_1.10.2383.0_x64.msix (notice the x64 part).

Change its msix extension to zip.

Extract that zip's contents to C:\Program Files\Term\  (create the Term folder or choose another name).

Add C:\Program Files\Term\ to your user PATH.

Run C:\Program Files\Term\wt.exe (manually or with a shortcut or Start menu pin).

If fonts are mangled, edit the settings.json file for Terminal and add/edit this line:

     "defaults": {"fontFace": "Consolas"},



