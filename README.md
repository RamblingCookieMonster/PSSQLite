[![Build status](https://ci.appveyor.com/api/projects/status/sfynxcm7rfetdhjn/branch/master?svg=true)](https://ci.appveyor.com/project/RamblingCookieMonster/invoke-sqlitequery)

Invoke-SQLiteQuery PowerShell Module
=============

This is a PowerShell module for working with SQLite.  It uses similar syntax to the [Invoke-Sqlcmd2](https://github.com/RamblingCookieMonster/PowerShell/blob/master/Invoke-Sqlcmd2.ps1) function from Chad Miller et al.

This covers limited functionality; contributions to this function or additional functions would be welcome!

Caveats:
* Minimal testing.
* Today was my first time working with SQLite

#Functionality

Create a SQLite database and table:
  * ![Create a SQLite database and table](/Media/Create.png)

Query a SQLite database, using parameters:
  * ![Query a SQLite database](/Media/Query.png)

Create a SQLite connection, use it for subsequent queries:
  * ![Create a SQLite connection, use it](/Media/Connection.png)

#Instructions

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the Invoke-SQLiteQuery folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

# Import the module.
    Import-Module Invoke-SQLiteQuery    #Alternatively, Import-Module \\Path\To\Invoke-SQLiteQuery

# Get commands in the module
    Get-Command -Module Invoke-SQLiteQuery

# Get help for a command
    Get-Help Invoke-SQLiteQuery -Full

# Create a database and a table
    $Query = "CREATE TABLE NAMES (fullname VARCHAR(20) PRIMARY KEY, surname TEXT, givenname TEXT, BirthDate DATETIME)"
    $DataSource = "C:\Names.SQLite"

    Invoke-SqliteQuery -Query $Query -DataSource $DataSource

# View table info
    Invoke-SqliteQuery -DataSource $DataSource -Query "PRAGMA table_info(NAMES)"

# Insert some data, use parameters for the fullname and birthdate
    $query = "INSERT INTO NAMES (fullname, surname, givenname, birthdate) VALUES (@full, 'Cookie', 'Monster', @BD)"

    Invoke-SqliteQuery -DataSource $DataSource -Query $query -SqlParameters @{
        full = "Cookie Monster"
        BD   = (get-date).addyears(-3)
    }

# View the data
    Invoke-SqliteQuery -DataSource $DataSource -Query "SELECT * FROM NAMES"

```

#Notes

This isn't a fully featured module or function.

I'm planning to write about using SQL from a systems administrator or engineer standpoint.  I personally stick to [MSSQL and Invoke-Sqlcmd2](https://ramblingcookiemonster.wordpress.com/2014/03/12/sql-for-powershell-for-sql-newbies/), but want to provide an abstracted means to perform this without the prerequisite of an accessible MSSQL instance.

Check out Jim Christopher's [SQLite PowerShell Provider](https://psqlite.codeplex.com/).  It offers more functionality and flexibility than this repository.

Credit to Chad Miller, Justin Dearing, Paul Bryson, Joel Bennett, and Dave Wyatt for the code carried over from Invoke-Sqlcmd2.