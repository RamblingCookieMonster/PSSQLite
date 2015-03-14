#handle PS2
if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\Invoke-SQLiteQuery -Force

Describe "Invoke-SQLiteQuery PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should return table info' {
            $Out = @( Invoke-SQLiteQuery -Database $PSScriptRoot\Names.SQLite -Query "PRAGMA table_info(NAMES)" -ErrorAction Stop )
            $Out.count | Should Be 4
            $Out[0].Name | SHould Be "fullname"
        }

        It 'should allow parameterized queries' {
            
            $Out = @( Invoke-SQLiteQuery -Database $PSScriptRoot\Names.SQLite -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/13/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 1
            $Out[0].fullname | SHould Be "Cookie Monster"

            $Out = @( Invoke-SQLiteQuery -Database $PSScriptRoot\Names.SQLite -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/15/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 0
        }

    }
}

