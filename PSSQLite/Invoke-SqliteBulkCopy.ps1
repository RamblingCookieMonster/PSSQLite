function Invoke-SQLiteBulkCopy {
<#
.SYNOPSIS
    Use a SQLite transaction to quickly insert data

.DESCRIPTION
    Use a SQLite transaction to quickly insert data.  If we run into any errors, we roll back the transaction.
    
    The data source is not limited to SQL Server; any data source can be used, as long as the data can be loaded to a DataTable instance or read with a IDataReader instance.

.PARAMETER DataSource
    Path to one ore more SQLite data sources to query 

.PARAMETER Force
    If specified, skip the confirm prompt

.PARAMETER  NotifyAfter
	The number of rows to fire the notification event after transferring.  0 means don't notify.  Notifications hit the verbose stream (use -verbose to see them)

.PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

.PARAMETER SQLiteConnection
    An existing SQLiteConnection to use.  We do not close this connection upon completed query.

.EXAMPLE
    #
    #Create a table
        Invoke-SqliteQuery -DataSource "C:\Names.SQLite" -Query "CREATE TABLE NAMES (
            fullname VARCHAR(20) PRIMARY KEY,
            surname TEXT,
            givenname TEXT,
            BirthDate DATETIME)" 

    #Build up some fake data to bulk insert, convert it to a datatable
        $DataTable = 1..10000 | %{
            [pscustomobject]@{
                fullname = "Name $_"
                surname = "Name"
                givenname = "$_"
                BirthDate = (Get-Date).Adddays(-$_)
            }
        } | Out-DataTable

    #Copy the data in within a single transaction (SQLite is faster this way)
        Invoke-SQLiteBulkCopy -DataTable $DataTable -DataSource $Database -Table Names -NotifyAfter 1000 -verbose 
        
.INPUTS
    System.Data.DataTable

.OUTPUTS
    None
        Produces no output

.NOTES
    This function borrows from:
        Chad Miller's Write-Datatable
        jbs534's Invoke-SQLBulkCopy
        Mike Shepard's Invoke-BulkCopy from SQLPSX

.LINK
    https://github.com/RamblingCookieMonster/Invoke-SQLiteQuery

.LINK
    New-SQLiteConnection

.LINK
    Invoke-SQLiteBulkCopy

.LINK
    Out-DataTable

.FUNCTIONALITY
    SQL
#>
    [cmdletBinding( DefaultParameterSetName = 'Datasource',
                    SupportsShouldProcess = $true,
                    ConfirmImpact = 'High' )]
    param(
        [parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $false,
                    ValueFromPipelineByPropertyName= $false)]
        [System.Data.DataTable]
        $DataTable,

        [Parameter( ParameterSetName='Datasource',
                    Position=1,
                    Mandatory=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQLite Data Source required...' )]
        [Alias('Path','File','FullName','Database')]
        [validatescript({
            #This should match memory, or the parent path should exist
            if ( $_ -match ":MEMORY:" -or (Test-Path $_) ) {
                $True
            }
            else {
                Throw "Invalid datasource '$_'.`nThis must match :MEMORY:, or must exist"
            }
        })]
        [string]
        $DataSource,

        [Parameter( ParameterSetName = 'Connection',
                    Position=1,
                    Mandatory=$true,
                    ValueFromPipeline=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Alias( 'Connection', 'Conn' )]
        [System.Data.SQLite.SQLiteConnection]
        $SQLiteConnection,

        [parameter( Position=2,
                    Mandatory = $true)]
        [string]
        $Table,

        [int]
        $NotifyAfter = 0,

        [switch]
        $Force,

        [Int32]
        $QueryTimeout = 600

    )

    Write-Verbose "Running Invoke-SQLiteBulkCopy with ParameterSet '$($PSCmdlet.ParameterSetName)'."

    Function CleanUp
    {
        [cmdletbinding()]
        param($conn, $com, $BoundParams)
        #Only dispose of the connection if we created it
        if($BoundParams.Keys -notcontains 'SQLConnection')
        {
            $conn.Close()
            $conn.Dispose()
            Write-Verbose "Closed connection"
        }
        $com.Dispose()
    }

    #Connections
        if($PSBoundParameters.Keys -notcontains "SQLiteConnection")
        {
            $ConnectionString = "Data Source={0}" -f $DataSource
            $SQLiteConnection = New-Object System.Data.SQLite.SQLiteConnection -ArgumentList $ConnectionString
        }

        Write-Debug "ConnectionString $($SQLiteConnection.ConnectionString)"
        Try
        {
            if($SQLiteConnection.State -notlike "Open")
            {
                $SQLiteConnection.Open()
            }
            $Command = $SQLiteConnection.CreateCommand()
            $CommandTimeout = $QueryTimeout
            $Transaction = $SQLiteConnection.BeginTransaction()
        }
        Catch
        {
            Throw $_
        }
    
    write-verbose "DATATABLE IS $($DataTable.gettype().fullname) with value $($Datatable | out-string)"
    $RowCount = $Datatable.Rows.Count
    Write-Verbose "Processing datatable with $RowCount rows"

    if ($Force -or $PSCmdlet.ShouldProcess("$($DataTable.Rows.Count) rows, with BoundParameters $($PSBoundParameters | Out-String)", "SQL Bulk Copy"))
    {
        #Get column info...
            $Columns = $DataTable.Columns | Select -ExpandProperty ColumnName
            $ColumnTypeHash = @{}
            $Index = 0
            foreach($Col in $DataTable.Columns)
            {
                $Type = Switch -regex ($Col.DataType.FullName)
                {
                    # I figure we create a hashtable, can act upon expected data when doing insert
                    # Might be a better way to handle this...
                    '^(|\ASystem\.)Boolean$' {"BOOLEAN"} #I know they're fake...
                    '^(|\ASystem\.)Byte\[\]' {"BLOB"}
                    '^(|\ASystem\.)Byte$'  {"BLOB"}
                    '^(|\ASystem\.)Datetime$'  {"DATETIME"}
                    '^(|\ASystem\.)Decimal$' {"REAL"}
                    '^(|\ASystem\.)Double$' {"REAL"}
                    '^(|\ASystem\.)Guid$' {"TEXT"}
                    '^(|\ASystem\.)Int16$'  {"INTEGER"}
                    '^(|\ASystem\.)Int32$'  {"INTEGER"}
                    '^(|\ASystem\.)Int64$' {"INTEGER"}
                    '^(|\ASystem\.)UInt16$'  {"INTEGER"}
                    '^(|\ASystem\.)UInt32$'  {"INTEGER"}
                    '^(|\ASystem\.)UInt64$' {"INTEGER"}
                    '^(|\ASystem\.)Single$' {"REAL"}
                    '^(|\ASystem\.)String$' {"TEXT"}
                    Default {"BLOB"} #Let SQLite handle the rest...
                }

                #We ref columns by their index, so add that...
                $ColumnTypeHash.Add($Index,$Type)
                $Index++
            }

        #Build up the query
            $Command.CommandText = "INSERT INTO $Table ($($Columns -join ", ")) VALUES ($( $( foreach($Column in $Columns){ "@$Column" } ) -join ", "  ))"
            foreach ($Column in $Columns)
            {
                $param = New-Object System.Data.SQLite.SqLiteParameter $Column
                [void]$Command.Parameters.Add($param)
            }
            
            for ($RowNumber = 0; $RowNumber -lt $RowCount; $RowNumber++)
            {
                $row = $Datatable.Rows[$RowNumber]
                for($col = 0; $col -lt $Columns.count; $col++)
                {
                    # Depending on the type of thid column, quote it
                    # For dates, convert it to a string SQLite will recognize
                    switch ($ColumnTypeHash[$col])
                    {
                        "BOOLEAN" {
                            $Command.Parameters[$Columns[$col]].Value = [int][boolean]$row[$col]
                        }
                        "DATETIME" {
                            Try
                            {
                                $Command.Parameters[$Columns[$col]].Value = $row[$col].ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            Catch
                            {
                                $Command.Parameters[$Columns[$col]].Value = $row[$col]
                            }
                        }
                        Default {
                            $Command.Parameters[$Columns[$col]].Value = $row[$col]
                        }
                    }
                }

                #We have the query, execute!
                    Try
                    {
                        [void]$Command.ExecuteNonQuery()
                    }
                    Catch
                    {
                        #Minimal testing for this rollback...
                            Write-Verbose "Rolling back due to error:`n$_"
                            $Transaction.Rollback()
                        
                        #Clean up and throw an error
                            CleanUp -conn $SQLiteConnection -com $Command -BoundParams $PSBoundParameters
                            Throw "Rolled back due to error:`n$_"
                    }

                if($NotifyAfter -gt 0 -and $($RowNumber % $NotifyAfter) -eq 0)
                {
                    Write-Verbose "Processed $($RowNumber + 1) records"
                }
            }  
    }
    
    #Commit the transaction and clean up the connection
        $Transaction.Commit()
        CleanUp -conn $SQLiteConnection -com $Command -BoundParams $PSBoundParameters
    
}