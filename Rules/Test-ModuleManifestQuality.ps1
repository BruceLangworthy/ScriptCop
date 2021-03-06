param(
[Parameter(ParameterSetName='TestModuleInfo',Mandatory=$true,ValueFromPipeline=$true)]
[Management.Automation.PSModuleInfo]
$ModuleInfo
)
    
process {
    $moduleRoot = $ModuleInfo | 
            Split-Path
    $ModuleManifest =
        $ModuleInfo | 
            Split-Path | 
            Get-ChildItem -Filter "$($ModuleInfo.Name).psd1"
            
    
    if (-not $moduleManifest) {        
        Write-Error "$ModuleInfo does not have a manifest" -ErrorId "TestModuleManifestQuality.NoManifest"
        return
    }
    
    $manifestContent = ([PowerShell]::Create().AddScript("
        `$executionContext.SessionState.LanguageMode = 'RestrictedLanguage'
        $([IO.File]::ReadAllText($moduleManifest.Fullname))        
    ").Invoke())[0]
    
    $ht = @{} + $manifestContent
    $manifestContent  = New-Object PSObject -Property $ht 
    
    
    if (-not $manifestContent.FileList) {
        Write-Error -Message "Module Manifest does not contain a file list" -ErrorId "TestModuleManifestQuality.MissingFileList"
    }
    
    if (-not $manifestContent.Guid) {
        Write-Error "Module Manifest does not have a GUID" -ErrorId "TestModuleManifestQuality.MissingGUID"
    }
    
    if (-not $manifestContent.Description) {
        Write-Error "Module Manifest does not have a Description" -ErrorId "TestModuleManifestQuality.MissingDescription"
    }
    
    if (-not $manifestContent.Copyright) {
        Write-Error "Module Manifest does not have a Copyright Notice" -ErrorId "TestModuleManifestQuality.MissingCopyrightNotice"
    }
        
    if (-not $manifestContent.Author) {
        Write-Error "Module Manifest does not have an Author" -ErrorId "TestModuleManifestQuality.MissingAuthor"
    }
    
    if ($manifestContent.ModuleToProcess -like "*.psm1") {
        $psm1Path = "$moduleRoot\$($manifestContent.ModuleToProcess)"
    }
}

 
 
 
