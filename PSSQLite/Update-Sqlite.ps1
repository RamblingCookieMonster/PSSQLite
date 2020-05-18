function Update-Sqlite {
	[CmdletBinding()]

	param(
		[Parameter()]
		[string]
		$version = '1.0.112',
	
		[Parameter()]
		[ValidateSet('linux-x64','osx-x64','win-x64','win-x86')]
		[string]
		$OS
	)
	
	Process {
	write-verbose "Creating build directory"
	New-Item -ItemType directory build
	Set-Location build
	
	$file = "system.data.sqlite.core.$version"

	write-verbose "downloading files from nuget"
	$dl = @{
		uri = "https://www.nuget.org/api/v2/package/System.Data.SQLite.Core/$version"
		outfile = "$file.nupkg"
	}
	Invoke-WebRequest @dl

	write-verbose "unpacking and copying files to module directory"
	Expand-Archive $dl.outfile

	$InstallPath = (get-module PSSQlite).path.TrimEnd('PSSQLite.psm1')
	copy-item $file/lib/netstandard2.0/System.Data.SQLite.dll $InstallPath/core/$os/
	copy-item $file/runtimes/$os/native/netstandard2.0/SQLite.Interop.dll $InstallPath/core/$os/

	write-verbose "removing build folder"
	Set-location ..
	remove-item ./build -recurse
	write-verbose "complete"

	Write-Warning "Please reimport the module to use the latest files"
	}
}

