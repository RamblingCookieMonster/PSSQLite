#Initialize some variables, move to the project root
    $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"

    $Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    Set-Location $ProjectRoot

    $Verbose = @{}
    if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
    {
        $Verbose.add("Verbose",$True)
    }

# Load up Pester
    # PS less than 4? Load from the path we found
    if($PSVersionTable.PSVersion.Major -lt 4)
    {
        $PesterPath = [Environment]::GetEnvironmentVariable("PesterPath","Machine")
        if(Test-Path $PesterPath)
        {
            Import-Module $PesterPath
        }
        else
        {
            Throw "Where is pester! '$PesterPath' not found"
        }
    }
    # cinst didn't seem to work, install a new flavor and import it.
    elseif(-not (Get-Module Pester -ListAvailable))
    {
        $null = Install-Module Pester -Force -Confirm:$False
        Import-Module Pester -force
    }
    # Module is there, import it
    else
    {
        Import-Module Pester -force
    }

#Run a test with the current version of PowerShell, upload results    
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    Invoke-Pester @Verbose -Path "$ProjectRoot\Tests" -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -PassThru |
        Export-Clixml -Path "$ProjectRoot\PesterResults_PS$PSVersion`_$Timestamp.xml"

    If($env:APPVEYOR_JOB_ID)
    {
        (New-Object 'System.Net.WebClient').UploadFile( $Address, "$ProjectRoot\$TestFile" )
    }

    