function Repair-ModuleManifest
{
    param(
    # The Rule that flagged the problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        if ($_ -isnot [Management.Automation.CommandInfo] -and
            $_ -isnot [Management.Automation.PSModuleInfo]
        ) {
            throw 'Must be a CommandInfo or a PSModuleInfo'            
        } 
        return $true
    })]
    [Object]$Rule,
    
    # The Problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.ErrorRecord]
    $Problem,
    
    # The Item with the Problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        if ($_ -isnot [Management.Automation.CommandInfo] -and
            $_ -isnot [Management.Automation.PSModuleInfo]
        ) {
            throw 'Must be a CommandInfo or a PSModuleInfo'            
        } 
        return $true
    })]
    [Object]$ItemWithProblem,
    
    [Switch]$NotInteractive
    )
    
    begin {                
function Write-PowerShellHashtable {
    <#
    .Synopsis
        Takes an existing Hashtable and creates the script you would need to embed to recreate the hashtable
    .Description
        Allows you to take a hashtable and create a hashtable you would embed into a script.
        Handles nested hashtables and automatically indents hashtables based off of how many times New-PowerShellHashtable is called
    .Parameter inputObject
        The hashtable to turn into a script
    .Parameter scriptBlock
        Determines if a string or a scriptblock is returned
    .Example
        # Corrects the presentation of a PowerShell hashtable
        @{Foo='Bar';Baz='Bing';Boo=@{Bam='Blang'}} | New-PowerShellHashtable
    .ReturnValue
        [string]
    .ReturnValue
        [ScriptBlock]   
    .Link
        about_hash_tables
    #>    
    param(
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $InputObject,

    # Returns the content as a script block, rather than a string
    [switch]$scriptBlock
    )

    process {
        $callstack = @(Get-PSCallStack | 
            Where-Object { $_.Command -eq "Write-PowerShellHashtable"})
        $depth = $callStack.Count
        if ($inputObject -is [Hashtable]) {
            $scriptString = ""
            $indent = $depth * 4        
            $scriptString+= "@{
"
            foreach ($kv in $inputObject.GetEnumerator()) {
                $indent = ($depth + 1) * 4
                for($i=0;$i -lt $indent; $i++) {
                    $scriptString+=" "
                }
                $keyString = $kv.Key
                if ($keyString -notlike "*.*" -and $keyString -notlike "*-*") {
                    $scriptString+="$($kv.Key)="
                } else {
                    $scriptString+="'$($kv.Key)'="
                }
                
                $value = $kv.Value
                Write-Verbose "$value"
                if ($value -is [string]) {
                    $value = "'$value'"
                } elseif ($value -is [ScriptBlock]) {
                    $value = "{$value}"
                } elseif ($value -is [Object[]]) {
                    $oldOfs = $ofs 
                    $ofs = "',
$(' ' * ($indent + 4))'"
                    $value = "'$value'"
                    $ofs = $oldOfs
                } elseif ($value -is [Hashtable]) {
                    $value = "$(Write-PowerShellHashtable $value)"
                } else {
                    $value = "'$value'"
                }                                
               $scriptString+="$value
"
            }
            $indent = $depth * 4
            for($i=0;$i -lt $indent; $i++) {
                $scriptString+=" "
            }          
            $scriptString+= "}"     
            if ($scriptBlock) {
                [ScriptBlock]::Create($scriptString)
            } else {
                $scriptString
            }
        }           
   }
}       
    }
    
    process {    
        if ($Problem.FullyQualifiedErrorId -notlike "TestModuleManifestQuality.*") {
            return
        }
        
        
        $ModuleRoot = $ItemWithProblem | 
                Split-Path 
                
        $modulePath = $ItemWithProblem | 
                Split-Path -Leaf                
        
        $manifestPath = Join-Path $moduleRoot "$($ItemWithProblem.Name).psd1"
        
        if (Test-Path $ManifestPath) {
            $manifestContent = ([PowerShell]::Create().AddScript("
                `$executionContext.SessionState.LanguageMode = 'RestrictedLanguage'
                $([IO.File]::ReadAllText($ManifestPath))        
            ").Invoke())[0]
        
            $manifestMetaData = @{} + $manifestContent
        }

        $module = $ItemWithProblem

                
        if ($Problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.NoManifest*') {
            # Generate a Module Manifest with version 0.1, pointing to the path of the module                                    
            
            
            
            $newManifest = @"
    @{
        ModuleVersion='0.1'
        Guid='$([GUID]::NewGuid())'
        ModuleToProcess='$modulePath'
    }
"@
            [IO.File]::WriteAllText($ManifestPath, $newManifest)
            return TriedToFixProblem 'TestModuleManifestQuality.NoManifest'                        
        }     
        
        
        if (-not $manifestMetaData) { return }
                        
        if ($Problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.MissingFileList*') {
            # Take what's in the manifest, and add a file list
            
            if (-not $manifestMetaData) { 
                return CouldNotFixProblem 'TestModuleManifestQuality.MissingFileList'            
            } else {
                $manifestMetaData.FileList = $ModuleRoot | 
                    Get-ChildItem -Recurse |
                    Where-Object { -not $_.PSIsContainer } |
                    Select-Object -ExpandProperty FullName | 
                    ForEach-Object { $_.Replace("$ModuleRoot\", "") } 
                                
                Write-PowerShellHashtable -InputObject $manifestMetaData |
                    Set-Content $ManifestPath
                            
                return TriedToFixProblem 'TestModuleManifestQuality.MissingFileList' -FixRequiresRescan
            }
        }
        
        if ($Problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.MissingGuid*') {
            # Take what's in the manifest, and add a GUID
            
            $manifestMetaData.GUID = [GUID]::NewGuid()
                                
            Write-PowerShellHashtable -InputObject $manifestMetaData |
                Set-Content $ManifestPath
                        
            return TriedToFixProblem 'TestModuleManifestQuality.MissingGuid' -FixRequiresRescan               
        }
        
        if ($Problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.MissingCopyrightNotice*') {
            # Take what's in the manifest, and add a GUID
            
            $manifestMetaData.Copyright = "Copyright $((Get-Date).Year)"
                                
            Write-PowerShellHashtable -InputObject $manifestMetaData |
                Set-Content $ManifestPath
                        
            return TriedToFixProblem 'TestModuleManifestQuality.MissingCopyrightNotice' -FixRequiresRescan                 
        }
        
        if ($problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.MissingDescription*') {
            if ($NonInteractive) {
                # Could Fix, but can't because I can't ask
                return CouldNotFixProblem 'TestModuleManifestQuality.MissingDescription'                      
            } else {
                $description = Read-Host -Prompt "What Does the Module $($ItemWithProblem) do?"
                $manifestMetaData.Description = $description                     
                    
                Write-PowerShellHashtable -InputObject $manifestMetaData |
                    Set-Content $ManifestPath

                                                                       
                return TriedToFixProblem 'TestModuleManifestQuality.MissingDescription' -FixRequiresRescan
            }
            
        }
        
        if ($problem.FullyQualifiedErrorId -like 'TestModuleManifestQuality.MissingAuthor*') {
            if ($NonInteractive) {
                # Assume current user
                $manifestMetaData.Author = $env:UserName
            } else {
                $author = Read-Host -Prompt "Who wrote the module $module ?"
                $manifestMetaData.Author = $author                                         
            }

            Write-PowerShellHashtable -InputObject $manifestMetaData |
                Set-Content $ManifestPath

                                                                   
            return TriedToFixProblem 'TestModuleManifestQuality.MissingAuthor' -FixRequiresRescan
            
        }
    }
} 
