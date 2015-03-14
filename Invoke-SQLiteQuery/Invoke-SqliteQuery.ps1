function Invoke-SqliteQuery {  
    <# 
    .SYNOPSIS 
        Runs a SQL script against a SQLite database.

    .DESCRIPTION 
        Runs a SQL script against a SQLite database.

        Paramaterized queries are supported. 

        Help details below borrowed from Invoke-Sqlcmd, may be inaccurate here.

    .PARAMETER Database
        Path to one ore more SQLite databases to query 

    .PARAMETER Query
        Specifies a query to be run.

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-MySQLQuery. Specify the full path to the file.

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value 

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER SqlParameters
        Hashtable of parameters for parameterized SQL queries.  http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

        Limited support for conversions to SQLite friendly formats is supported.
            For example, if you pass in a .NET DateTime, we convert it to a string that SQLite will recognize as a datetime

        Example:
            -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
            -SqlParameters @{"ServerName = "c-is-hyperv-1"}

    .PARAMETER AppendDatabase
        If specified, append the SQLite database path to PSObject or DataRow output

    .INPUTS 
        Database 
            You can pipe database paths to Invoke-SQLiteQuery.  The query will execute against each database.

    .OUTPUTS
       As PSObject:     System.Management.Automation.PSCustomObject
       As DataRow:      System.Data.DataRow
       As DataTable:    System.Data.DataTable
       As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
       As SingleValue:  Dependent on data type in first column.

    .EXAMPLE

        #
        # First, we create a database and a table
            $Query = "CREATE TABLE NAMES (fullname VARCHAR(100) PRIMARY KEY, surname VARCHAR(50), givenname VARCHAR(50), BirthDate DATETIME)"
            $Database = "C:\Names.SQLite"
        
            Invoke-SqliteQuery -Query $Query -Database $Database

        # We have a database, and a table, let's view the table info
            Invoke-SqliteQuery -Database $Database -Query "PRAGMA table_info(NAMES)"
                
                cid name      type         notnull dflt_value pk
                --- ----      ----         ------- ---------- --
                  0 fullname  VARCHAR(100)       0             1
                  1 surname   VARCHAR(50)        0             0
                  2 givenname VARCHAR(50)        0             0
                  3 BirthDate DATETIME           0             0

        # Insert some data, use parameters for the fullname and birthdate
            $query = "INSERT INTO NAMES (fullname, surname, givenname, birthdate) VALUES (@full, 'Cookie', 'Monster', @BD)"
            Invoke-SqliteQuery -Database $Database -Query $query -SqlParameters @{
                full = "Cookie Monster"
                BD   = (get-date).addyears(-3)
            }

        # Check to see if we inserted the data:
            Invoke-SqliteQuery -Database $Database -Query "SELECT * FROM NAMES"
                
                fullname       surname givenname BirthDate            
                --------       ------- --------- ---------            
                Cookie Monster Cookie  Monster   3/14/2012 12:27:13 PM

        # Insert another entry with too many characters in the fullname.
        # Illustrate that SQLite data types may be misleading:
            Invoke-SqliteQuery -Database $Database -Query $query -SqlParameters @{
                full = "Cookie Monster$('!' * 100)"
                BD   = (get-date).addyears(-3)
            }

            Invoke-SqliteQuery -Database $Database -Query "SELECT * FROM NAMES"

                fullname                       surname givenname BirthDate            
                --------                       ------- --------- ---------            
                Cookie Monster                 Cookie  Monster   3/14/2012 12:27:13 PM
                Cookie Monster![TRUNCATED...]! Cookie  Monster   3/14/2012 12:29:32 PM

    .EXAMPLE
        Invoke-SqliteQuery -Database $Database -Query "SELECT * FROM NAMES" -AppendDatabase  

            fullname       surname givenname BirthDate             Database       
            --------       ------- --------- ---------             --------       
            Cookie Monster Cookie  Monster   3/14/2012 12:55:55 PM C:\Names.SQLite

        # Append Database column (path) to each result

    .LINK
        https://github.com/RamblingCookieMonster/Invoke-SQLiteQuery

    .LINK
        https://www.sqlite.org/datatype3.html

    .LINK
        http://www.sqlite.org/pragma.html

    .FUNCTIONALITY
        SQL
    #>

    [CmdletBinding( DefaultParameterSetName='Query' )]
    [OutputType([System.Management.Automation.PSCustomObject],[System.Data.DataRow],[System.Data.DataTable],[System.Data.DataTableCollection],[System.Data.DataSet])]
    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQLite Database Path required...' )]
        [Alias( 'Instance', 'Instances', 'ServerInstance', 'Server', 'Servers','cn','Path','File' )]
        [validatescript({
            $Parent = Split-Path $_ -Parent
            Test-Path $Parent -ErrorAction Stop
        })]
        [string[]]
        $Database,
    
        [Parameter( Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName='Query' )]
        [string]
        $Query,
        
        [Parameter( Position=1,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName="File")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $InputFile,

        [Parameter( Position=2,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $QueryTimeout=600,
    
        [Parameter( Position=3,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateSet("DataSet", "DataTable", "DataRow","PSObject","SingleValue")]
        [string]
        $As="DataRow",
    
        [Parameter( Position=4,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Collections.IDictionary]
        $SqlParameters,

        [Parameter( Position=5,
                    Mandatory=$false )]
        [switch]
        $AppendDatabase,

        [Parameter( Position=6,
                    Mandatory=$false )]
        [validatescript({Test-Path $_ })]
        [string]$AssemblyPath = $SQLiteAssembly

    ) 

    Begin
    {
        
        if( -not ($Library = Add-Type -path $AssemblyPath -PassThru -ErrorAction stop) )
        {
            Throw "This function requires the ADO.NET driver for SQLite:`n`thttp://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki"
        }

        if ($InputFile) 
        { 
            $filePath = $(Resolve-Path $InputFile).path 
            $Query =  [System.IO.File]::ReadAllText("$filePath") 
        }

        Write-Verbose "Running Invoke-MySQLQuery with ParameterSet '$($PSCmdlet.ParameterSetName)'.  Performing query '$Query'"

        If($As -eq "PSObject")
        {
            #This code scrubs DBNulls.  Props to Dave Wyatt
            $cSharp = @'
                using System;
                using System.Data;
                using System.Management.Automation;

                public class DBNullScrubber
                {
                    public static PSObject DataRowToPSObject(DataRow row)
                    {
                        PSObject psObject = new PSObject();

                        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
                        {
                            foreach (DataColumn column in row.Table.Columns)
                            {
                                Object value = null;
                                if (!row.IsNull(column))
                                {
                                    value = row[column];
                                }

                                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                            }
                        }

                        return psObject;
                    }
                }
'@

            Try
            {
                Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml' -ErrorAction stop
            }
            Catch
            {
                If(-not $_.ToString() -like "*The type name 'DBNullScrubber' already exists*")
                {
                    Write-Warning "Could not load DBNullScrubber.  Defaulting to DataRow output: $_"
                    $As = "Datarow"
                }
            }
        }

    }
    Process
    {

        foreach($DB in $Database)
        {
            if(Test-Path $DB)
            {
                Write-Verbose "Querying existing database '$DB'"
            }
            else
            {
                Write-Verbose "Creating andn querying database '$DB'"
            }

            $ConnectionString = "Data Source={0}" -f $DB
	    
            $conn = New-Object System.Data.SQLite.SQLiteConnection -ArgumentList $ConnectionString
            Write-Debug "ConnectionString $ConnectionString"
    
            Try
            {
                $conn.Open() 
            }
            Catch
            {
                Write-Error $_
                continue
            }

            $cmd = $Conn.CreateCommand()
            $cmd.CommandText = $Query
            $cmd.CommandTimeout = $QueryTimeout

            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        {
                            if($_.Value -is [datetime]) { $_.Value = $_.Value.ToString("yyyy-MM-dd HH:mm:ss") }
                            $cmd.Parameters.AddWithValue("@$($_.Key)", $_.Value)
                        }
                        Else
                        {
                            $cmd.Parameters.AddWithValue("@$($_.Key)", [DBNull]::Value)
                        }
                    } > $null
            }
    
            $ds = New-Object system.Data.DataSet 
            $da = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
    
            Try
            {
                [void]$da.fill($ds)
                $conn.Close()
            }
            Catch
            { 
                $Err = $_
                $conn.Close()

                switch ($ErrorActionPreference.tostring())
                {
                    {'SilentlyContinue','Ignore' -contains $_} {}
                    'Stop' {     Throw $Err }
                    'Continue' { Write-Error $Err}
                    Default {    Write-Error $Err}
                }              
            }

            if($AppendDatabase)
            {
                #Basics from Chad Miller
                $Column =  New-Object Data.DataColumn
                $Column.ColumnName = "Database"
                $ds.Tables[0].Columns.Add($Column)
                Foreach($row in $ds.Tables[0])
                {
                    $row.Database = $DB
                }
            }

            switch ($As) 
            { 
                'DataSet' 
                {
                    $ds
                } 
                'DataTable'
                {
                    $ds.Tables
                } 
                'DataRow'
                {
                    $ds.Tables[0]
                }
                'PSObject'
                {
                    #Scrub DBNulls - Provides convenient results you can use comparisons with
                    #Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
                    foreach ($row in $ds.Tables[0].Rows)
                    {
                        [DBNullScrubber]::DataRowToPSObject($row)
                    }
                }
                'SingleValue'
                {
                    $ds.Tables[0] | Select-Object -ExpandProperty $ds.Tables[0].Columns[0].ColumnName
                }
            }
        }
    }
}