#If finalize is specified, display errors and fail build if we ran into any

#Show status...
    $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
    $AllFiles = Get-ChildItem -Path $ProjectRoot\PesterResults*.xml | Select -ExpandProperty FullName
    "`n`tSTATUS: Finalizing results"
    "COLLATING FILES:`n$($AllFiles | Out-String)"

#What failed?
    $Results = @( Get-ChildItem -Path "$ProjectRoot\PesterResults_PS*.xml" | Import-Clixml )
    
    $FailedCount = $Results |
        Select -ExpandProperty FailedCount |
        Measure-Object -Sum |
        Select -ExpandProperty Sum

    if ($FailedCount -gt 0) {

        $FailedItems = $Results |
            Select -ExpandProperty TestResult |
            Where {$_.Passed -notlike $True}

        "FAILED TESTS SUMMARY:"
        $FailedItems | ForEach-Object {
            $Item = $_
            [pscustomobject]@{
                Describe = $Item.Describe
                Context = $Item.Context
                Name = "It $($Item.Name)"
                Result = $Item.Result
            }
        } |
            Sort Describe, Context, Name, Result |
            Format-List

        throw "$FailedCount tests failed."
    }
