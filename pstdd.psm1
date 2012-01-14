function New-Test {
	param(
		[Parameter(Mandatory=$true)][string]$name,
		[Parameter(Mandatory=$true)][scriptblock]$definition
	)
	Write-Debug "Running test $name"
	
	$test = New-Object PsObject -Property @{
		Categories = @()
		Arrange = $null
		Act = $null
		Assert = $null
		Result = $null
		Skipped = $false
		StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
	}
	& { 
		try {
			& $definition

			if (!$CategoriesToRun) { $CategoriesToRun = @() }
			Write-Debug "Categories to run: $CategoriesToRun (eq `$null: $($CategoriesToRun -eq $null)), test categories: $($test.Categories)"
			Write-Debug "Categories comparison: $(Compare-Object $CategoriesToRun $test.Categories -includeEq | out-string)"
			
			if (!($CategoriesToRun) -or
				(Compare-Object $CategoriesToRun $test.Categories -IncludeEqual |?{$_.SideIndicator -eq '=='})) {        # categories to run (set by Invoke-TestFile
				if ($test.Arrange) {
					. $test.Arrange
				}
				if ($test.Act) {
					. $test.Act
				}
				if ($test.Assert) {
					$test.Result = runAssert $test.Assert
				} else {
					$test.Result = $true
				}
			} else {
				$test.Skipped = $true
			}
		} finally {
			$test.StopWatch.Stop() | Out-Null
		}
	} | Out-Null
	
	if ($test.Skipped) {
		Write-Debug "Test doesn't have categories that were selected to run"
	}
	else {
		Write-Debug "Test was ran. Reporting results."
		newTestResult $name $test.Result ([TimeSpan]::FromMilliseconds($test.Stopwatch.ElapsedMilliseconds)) $test.Categories
		Write-Debug "Reporting results done."
	}		
}
function Add-Category {
	param(
		[Parameter(Mandatory=$true)][string[]]$categories
	)
	$test.Categories += $categories
}
function Set-Arrange {
	param(
		[Parameter(Mandatory=$true)][scriptblock]$definition
	)
	$test.Arrange = $definition
}
function Set-Act {
	param(
		[Parameter(Mandatory=$true)][scriptblock]$definition
	)
	$test.Act = $definition
}
function Set-Assert {
	param(
		[Parameter(Mandatory=$true)][scriptblock]$definition,
		[Parameter()][Type]$expectedException
	)
	$test.Assert = new-Object PsObject -Property @{
		Definition = $definition
		ExpectedException = $expectedException 
	}
}

function Invoke-TestFile {
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
		[Alias('PsPath')]
		[string[]]
		$LiteralPath,
		[Parameter(Mandatory=$false,Position=1)][string[]]$category
	)
	begin {
		clearGlobalErrors
		$CategoriesToRun = $category
		$AllResults = @()
		$AllFiles = @()
	}
	process {
		$LiteralPath | % { $AllFiles += $_ }
	}
	end {
		$AllFiles |
			% { (& $_) |
				Add-Member NoteProperty FileName (gi (Resolve-Path $_).ProviderPath).Name -PassThru |
				Add-Member NoteProperty Path $_ -PassThru
			} |
			Tee-Object -Variable AllResults
						
		$totalTime = $AllResults | Select -ExpandProperty Time | % {$t = [timespan]::Zero } { $t += $_ } { $t }
		$totalResult = $AllResults | Select -ExpandProperty Result | % { $r = $true} { $r = $r -and $_ } { $r }
		$totalFiles = if ($AllFiles.Length -gt 1) { '' } else { $AllFiles[0] }
		newTestResult '--total--' $totalResult $totalTime $category |
			Add-Member NoteProperty File $totalFiles -PassThru
	}
}
function Test-Condition {
	[cmdletbinding(DefaultParameterSetName='istrue')]
	param(
		[Parameter(Mandatory=$true,Position=0,ParameterSetName='istrue')]
		[Parameter(Mandatory=$true,Position=0,ParameterSetName='isfalse')]
		[Object]$value,
		
		[Parameter(Mandatory=$false,Position=1,ParameterSetName='istrue')][switch]$isTrue,
		[Parameter(Mandatory=$false,Position=1,ParameterSetName='isfalse')][switch]$isFalse,
		
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='eq')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='lt')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='le')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='gt')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='ge')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='contains')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='match')]
		[object]$testedValue,
		
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='eq')][switch]$eq,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='lt')][switch]$lt,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='le')][switch]$le,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='gt')][switch]$gt,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='ge')][switch]$ge,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='contains')][switch]$contains,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='match')][switch]$match,
		
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='eq')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='lt')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='le')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='gt')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='ge')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='contains')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='match')]
		[object]$expectedValue
	)
	switch ($PsCmdlet.ParameterSetName) {
		'istrue' { 
			if ($value -is 'scriptblock') { [bool](& $value) }
			else { [bool]$value }
		}
		'isfalse' { 
			if ($value -is 'scriptblock') { !([bool](& $value)) }
			else { !([bool]$value) }
		}
		'eq' { Write-Debug "EQ"; $testedValue -eq $expectedValue }
		'lt' { Write-Debug "LT"; $testedValue -lt $expectedValue }
		'le' { Write-Debug "LE"; $testedValue -le $expectedValue }
		'gt' { Write-Debug "GT"; $testedValue -gt $expectedValue }
		'ge' { Write-Debug "GE"; $testedValue -ge $expectedValue }
		'contains' { Write-Debug "Contains"; $testedValue -contains $expectedValue }
		'match' { Write-Debug "Match"; $testedValue -match $expectedValue }
		default { Write-Debug "Default: $($PsCmdletName.ParameterSetName)" }
	}
}

function newTestResult {
	param(
		$name,
		$result,
		$time,
		[String[]]$categories
	)
	New-Object PsObject |
		Add-Member NoteProperty Test $name -PassThru |
		Add-Member NoteProperty Result $result -PassThru |
		Add-Member NoteProperty Time $time -PassThru |
		Add-Member NoteProperty Categories (($categories | sort)-join ',') -PassThru
}

function runAssert {
	param($assertDefinition)
	try {
		$ErrorActionPreference = 'stop'
		$res = . $assertDefinition.Definition
		Write-Debug "Returned result: $res"
		
		if ($assertDefinition.ExpectedException) {
			Write-Warning "Expected exception $($assertDefinition.ExpectedException). Nothing was thrown."
			return $false
		}
		$toReturn = 
			$res -eq $null -or
			($res -is [bool] -and $res) -or
			($res -is [object[]] -and $res -notcontains $false)
		return $toReturn
		
	} 
	catch {
		Write-Debug "Caught: $_"
		addGlobalError $_
		$e = $_.Exception
		Write-Debug "Exception $e"
		while($e -ne $null -and !($e -is $assertDefinition.ExpectedException)) {
			$e = $e.InnerException
			Write-Debug "Exception $e"
		}
		return $e -is $assertDefinition.ExpectedException
	}
}

function addGlobalError {
	param($Error)
	$v = Get-Variable global:pstdd_globaerrors -EA 0
	if (!$v) { 
		$global:pstdd_globaerrors = @()
	}
	$global:pstdd_globaerrors += $error
}
function clearGlobalErrors {
	$global:pstdd_globaerrors = @()
}

Set-Alias test New-Test
Set-Alias arrange Set-Arrange
Set-Alias act Set-Act
Set-Alias assert Set-Assert
Set-Alias category Add-Category
Set-Alias that Test-Condition

Export-ModuleMember -Alias * -Function New-Test, Set-Arrange, Set-Act, Set-Assert, Add-Category, Invoke-TestFile