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

$SQLiteFile = "$PSScriptRoot\Working.SQLite"
Remove-Item $SQLiteFile  -force -ErrorAction SilentlyContinue
Copy-Item $PSScriptRoot\Names.SQLite $PSScriptRoot\Working.SQLite -force

Describe "New-SQLiteConnection PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a connection' {
            $Script:Connection = New-SQLiteConnection -DataSource :MEMORY:
            $Script:Connection.ConnectionString | Should be "Data Source=:MEMORY:;"
            $Script:Connection.State | Should be "Open"
        }
    }
}

Describe "Invoke-SQLiteQuery PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should take file input' {
            $Out = @( Invoke-SqliteQuery -DataSource $SQLiteFile -InputFile $PSScriptRoot\Test.SQL )
            $Out.count | Should be 2
            $Out[1].OrderID | Should be 500
        }

        It 'should return table info' {
            $Out = @( Invoke-SQLiteQuery -Database $SQLiteFile -Query "PRAGMA table_info(NAMES)" -ErrorAction Stop )
            $Out.count | Should Be 4
            $Out[0].Name | SHould Be "fullname"
        }

        It 'should allow parameterized queries' {
            
            $Out = @( Invoke-SQLiteQuery -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/13/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 1
            $Out[0].fullname | Should Be "Cookie Monster"

            $Out = @( Invoke-SQLiteQuery -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/15/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 0
        }

        It 'should take existing SQLiteConnections' {
            Invoke-SqliteQuery -SQLiteConnection $Script:Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqliteQuery -SQLiteConnection $Script:Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            @( Invoke-SqliteQuery -SQLiteConnection $Script:Connection -Query "PRAGMA STATS" ) |
                Select -first 1 -ExpandProperty table |
                Should be 'OrdersToNames'

            $Script:Connection.close()
        }

    }
}

