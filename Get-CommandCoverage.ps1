function Get-CommandCoverage
{
    <#
    .Synopsis
    
    .Description

    .Example
        Get-CommandCoverage    
    .Link
        Test-Module
    .Link
        Enable-CommandCoverage
    .Link
        Disable-CommandCoverage   
    #>
    param(
    # The name of the module that will be instrumented for command coverage
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
    [Alias('Name')]
    [string]
    $Module
    )


    process {
        $moduleCommands = Get-Command -Module $module -commandType Function
        $commandsCovered = @($moduleCommands | Where-Object { $global:CommandCoverage.Contains("$_") } )
        $missingCommands = @($moduleCommands | Where-Object { -not $global:CommandCoverage.Contains("$_") } )
        $percentageCommandsCovered = 
            $commandsCovered.Count / $moduleCommands.Count

        $totalParameterCount = 
            $moduleCommands | 
                ForEach-Object { ([Management.Automation.CommandMetaData]$_).Parameters.Count} |
                Measure-Object -Sum |
                Select-Object -ExpandProperty Sum

        $coveredParameterTotal = 
            $commandsCovered | 
                ForEach-Object { ([Management.Automation.CommandMetaData]$_).Parameters.Count} |
                Measure-Object -Sum |
                Select-Object -ExpandProperty Sum

        $totalMissedParameters = 0
        $totalCoveredParameters = 0 
        $specificCommandCoverage = $commandsCovered |
            ForEach-Object {
                $params = ([Management.Automation.CommandMetaData]$_).Parameters
                $coverageData = @($global:CommandCoverage["$_"])
                $missedParameters = @($params.Keys | Where-Object { -not ($coverageData -eq $_) })
                $totalMissedParameters += $missedParameters.Count
                $coveredParams = @($coverageData | Group-Object -NoElement |
                        Select-Object Name, @{
                            Expression={$_.Count}
                            Name='TimesHit'
                        })
                $totalCoveredParameters += $coveredParams.Count
                $o = New-Object PSOBject -Property @{
                    Command = $_ 
                    CoveredParameters = $coveredParams
                    MissedParameters = $missedParameters
                    PercentageParameterCoverage = $coveredParams.Count * 100 / ($coveredParams.Count + $missedParameters.Count )
                }

                $o.pstypenames.clear()
                $o.pstypenames.add('ScriptCop.Command.Coverage')
                    

                $o 
            }


         $commandCoverageOutput = New-Object PSObject -Property @{
            CommandsCovered = $commandsCovered
            CoveredParameterTotal = $coveredParameterTotal
            CoverageData = $specificCommandCoverage
            PercentageCommandCoverage = $percentageCommandsCovered * 100
            NumberOfCommandsCovered = $commandsCovered.Count
            TotalNumberOfCommands = $moduleCommands.Count
            NumberOfParametersCovered = $totalCoveredParameters
            OverallParameterCoverage = $totalCoveredParameters * 100 / $totalParameterCount
            ParameterCoverageInCoveredCommands = $totalCoveredParameters * 100 / $coveredParameterTotal
            MissingCommands = $missingCommands
            TotalNumberOfParameters = $totalParameterCount
        }

        $commandCoverageOutput.pstypenames.clear()
        $commandCoverageOutput.pstypenames.add('ScriptCop.Command.Coverage.Report')
        $commandCoverageOutput

    }
} 
