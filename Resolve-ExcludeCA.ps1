function Resolve-ExcludedCA {
    <#
    .SYNOPSIS
        Resolves Entra ID Conditional Access policy exclusions to human-readable names.

    .DESCRIPTION
        Enumerates all Conditional Access policies and resolves excluded user and group
        GUIDs to display names and UPNs. Optionally expands group membership to show
        the individual users inside excluded groups.

    .PARAMETER ExpandGroups
        If specified, resolves the members of each excluded group. Adds an
        ExcludedGroupMembers property to the output.

    .PARAMETER PolicyState
        Filter output by policy state. Accepts: All, Enabled, Disabled, ReportOnly.
        Defaults to All.

    .EXAMPLE
        Resolve-ExcludedCA

    .EXAMPLE
        Resolve-ExcludedCA -ExpandGroups -PolicyState Enabled

    .EXAMPLE
        Resolve-ExcludedCA | Export-Csv -Path ".\CA-Exclusions.csv" -NoTypeInformation

    .NOTES
        Required Graph Scopes: Policy.Read.All, User.Read.All, Group.Read.All
        Connect first: Connect-MgGraph -Scopes "Policy.Read.All","User.Read.All","Group.Read.All"
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [switch]$ExpandGroups,

        [ValidateSet("All", "Enabled", "Disabled", "ReportOnly")]
        [string]$PolicyState = "All"
    )

    #region --- Internal Helpers ---

    function Resolve-User {
        param ([string]$UserId)
        try {
            $u = Get-MgUser -UserId $UserId -ErrorAction Stop
            return "$($u.DisplayName) ($($u.UserPrincipalName))"
        }
        catch {
            # Fallback: may be a service principal
            try {
                $sp = Get-MgServicePrincipal -ServicePrincipalId $UserId -ErrorAction Stop
                return "[SP] $($sp.DisplayName)"
            }
            catch {
                return "[Unresolvable] $UserId"
            }
        }
    }

    function Resolve-Group {
        param ([string]$GroupId)
        try {
            $g = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
            return $g.DisplayName
        }
        catch {
            return "[Unresolvable] $GroupId"
        }
    }

    function Resolve-GroupMembers {
        param ([string]$GroupId)
        try {
            $members = Get-MgGroupMember -GroupId $GroupId -All -ErrorAction Stop
            return $members | ForEach-Object {
                $upn = $_.AdditionalProperties.userPrincipalName
                $name = $_.AdditionalProperties.displayName
                if ($upn) { "$name ($upn)" } else { $name }
            }
        }
        catch {
            return "[Could not expand group: $GroupId]"
        }
    }

    #endregion

    #region --- Main ---

    Write-Verbose "Fetching Conditional Access policies..."
    $policies = Get-MgIdentityConditionalAccessPolicy

    # Apply state filter
    if ($PolicyState -ne "All") {
        $filterMap = @{
            "Enabled"    = "enabled"
            "Disabled"   = "disabled"
            "ReportOnly" = "enabledForReportingButNotEnforced"
        }
        $policies = $policies | Where-Object { $_.State -eq $filterMap[$PolicyState] }
    }

    foreach ($policy in $policies) {

        Write-Verbose "Processing policy: $($policy.DisplayName)"

        $resolvedUsers = foreach ($userId in $policy.Conditions.Users.ExcludeUsers) {
            Resolve-User -UserId $userId
        }

        $resolvedGroups = foreach ($groupId in $policy.Conditions.Users.ExcludeGroups) {
            Resolve-Group -GroupId $groupId
        }

        $output = [PSCustomObject]@{
            PolicyName     = $policy.DisplayName
            State          = $policy.State
            ExcludedUsers  = ($resolvedUsers  -join " | ")
            ExcludedGroups = ($resolvedGroups -join " | ")
            GrantControls  = ($policy.GrantControls.BuiltInControls -join ", ")
        }

        if ($ExpandGroups) {
            $memberList = foreach ($groupId in $policy.Conditions.Users.ExcludeGroups) {
                Resolve-GroupMembers -GroupId $groupId
            }
            $output | Add-Member -NotePropertyName ExcludedGroupMembers `
                                 -NotePropertyValue ($memberList -join " | ")
        }

        Write-Output $output
    }

    #endregion
}