function Test-ForParameterSetAmbiguity
{
    param(
    [Parameter(ParameterSetName='TestCommandInfo',Mandatory=$true,ValueFromPipeline=$true)]
    [Management.Automation.CommandInfo]
    $CommandInfo
    )
    
    
    process {    
        if ($CommandInfo.ParameterSets.Count -gt 1 -and 
            -not ($CommandInfo -as [Management.Automation.CommandMetadata]).DefaultParameterSetName) {
            Write-Error "$CommandInfo has more than one parameter set, but no default."
            
        }
        
    }
} 
