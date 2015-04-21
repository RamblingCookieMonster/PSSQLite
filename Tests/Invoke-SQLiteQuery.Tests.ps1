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
Import-Module $PSScriptRoot\..\PSSQLite -Force

$SQLiteFile = "$PSScriptRoot\Working.SQLite"
Remove-Item $SQLiteFile  -force -ErrorAction SilentlyContinue
Copy-Item $PSScriptRoot\Names.SQLite $PSScriptRoot\Working.SQLite -force

Describe "New-SQLiteConnection PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a connection' {
            $Script:Connection = New-SQLiteConnection @Verbose -DataSource :MEMORY:
            $Script:Connection.ConnectionString | Should be "Data Source=:MEMORY:;"
            $Script:Connection.State | Should be "Open"
        }
    }
}

Describe "Invoke-SQLiteQuery PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should take file input' {
            $Out = @( Invoke-SqliteQuery @Verbose -DataSource $SQLiteFile -InputFile $PSScriptRoot\Test.SQL )
            $Out.count | Should be 2
            $Out[1].OrderID | Should be 500
        }

        It 'should take query input' {
            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "PRAGMA table_info(NAMES)" -ErrorAction Stop )
            $Out.count | Should Be 4
            $Out[0].Name | SHould Be "fullname"
        }

        It 'should support parameterized queries' {
            
            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/13/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 1
            $Out[0].fullname | Should Be "Cookie Monster"

            $Out = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT * FROM NAMES WHERE BirthDate >= @Date" -SqlParameters @{
                Date = (Get-Date 3/15/2012)
            } -ErrorAction Stop )
            $Out.count | Should Be 0
        }

        It 'should use existing SQLiteConnections' {
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Script:Connection -Query "PRAGMA STATS" ) |
                Select -first 1 -ExpandProperty table |
                Should be 'OrdersToNames'

            $Script:COnnection.State | Should Be Open

            $Script:Connection.close()
        }

        It 'should respect PowerShell expectations for null' {
            
            #The SQL folks out there might be annoyed by this, but we want to treat DBNulls as null to allow expected PowerShell operator behavior.

            $Connection = New-SQLiteConnection -DataSource :MEMORY: 
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);"
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');"
            Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "INSERT INTO OrdersToNames (OrderID) VALUES (2);"

            @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "SELECT * FROM OrdersToNames" -As DataRow | Where{$_.fullname}).count |
                Should Be 2

            @( Invoke-SqliteQuery @Verbose -SQLiteConnection $Connection -Query "SELECT * FROM OrdersToNames" | Where{$_.fullname} ).count |
                Should Be 1
        }
    }
}

Describe "Out-DataTable PS$PSVersion" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a DataTable' {
            
            $Script:DataTable = 1..1000 | %{
                New-Object -TypeName PSObject -property @{
                    fullname = "Name $_"
                    surname = "Name"
                    givenname = "$_"
                    BirthDate = (Get-Date).Adddays(-$_)
                } | Select fullname, surname, givenname, birthdate
            } | Out-DataTable @Verbose

            $Script:DataTable.GetType().Fullname | Should Be 'System.Data.DataTable'
            @($Script:DataTable.Rows).Count | Should Be 1000
            $Columns = $Script:DataTable.Columns | Select -ExpandProperty ColumnName
            $Columns[0] | Should Be 'fullname'
            $Columns[3] | Should Be 'BirthDate'
            $Script:DataTable.columns[3].datatype.fullname | Should Be 'System.DateTime'
            
        }
    }
}

Describe "Invoke-SQLiteBulkCopy PS$PSVersion" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should insert data' {
            Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force
            
            @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT fullname FROM NAMES WHERE surname = 'Name'" ).count | Should Be 1000
        }
        It "should adhere to ConflictCause" {
            
            #Basic set of tests, need more...

            #Try adding same data
            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force } | Should Throw
            
            #Change a known row's prop we can test to ensure it does or does not change
            $Script:DataTable.Rows[0].surname = "Name 1"
            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -force } | Should Throw

            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'

            { Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Rollback -Force } | Should Throw
            
            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name'

            Invoke-SQLiteBulkCopy @Verbose -DataTable $Script:DataTable -DataSource $SQLiteFile -Table Names -NotifyAfter 100 -ConflictClause Replace -Force

            $Result = @( Invoke-SQLiteQuery @Verbose -Database $SQLiteFile -Query "SELECT surname FROM NAMES WHERE fullname = 'Name 1'")
            $Result[0].surname | Should Be 'Name 1'


        }
    }
}

Remove-Item $SQLiteFile -force -ErrorAction SilentlyContinue
