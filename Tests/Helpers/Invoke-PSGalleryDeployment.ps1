$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

# Deploy!

if($ENV:APPVEYOR_REPO_COMMIT_MESSAGE -notmatch '\[ReleaseMe\]')
{
    Write-Verbose 'Skipping deployment, include [ReleaseMe] in your commit message to deploy.'
}
elseif($env:APPVEYOR_REPO_BRANCH -notlike 'master')
{
    Write-Verbose 'Skipping deployment, not master!'
}
else
{

    $PublishParams = @{
        Path = Join-Path $ENV:APPVEYOR_BUILD_FOLDER $ENV:ModuleName
        NuGetApiKey = $ENV:NugetApiKey
    }
    if($ENV:ReleaseNotes) { $PublishParams.ReleaseNotes = $ENV:ReleaseNotes }
    if($ENV:LicenseUri) { $PublishParams.LicenseUri = $ENV:LicenseUri }
    if($ENV:ProjectUri) { $PublishParams.ProjectUri = $ENV:ProjectUri }
    if($ENV:Tags)
    {
        # split it up, remove whitespace
        $PublishParams.Tags = $ENV:Tags -split ',' | where { $_ } | foreach {$_.trim()}
    }

    #Publish!
    Publish-Module @PublishParams
}
 