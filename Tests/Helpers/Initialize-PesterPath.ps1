# When performing both PS2 and PS5 tests, use this from PS5 to save the path to the Pester module
# We then use that path in PS2
# cinst seems to fail, presumably pester is found, in a path PS2 doesn't like

$PesterPath = @( (Get-Module Pester -ListAvailable).Path )[0]
[Environment]::SetEnvironmentVariable("PesterPath", $PesterPath, "Machine")
