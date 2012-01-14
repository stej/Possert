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
			
			if (!$CategoriesBasedDecider -or
				(& $CategoriesBasedDecider $test.Categories)) {        # categories to run (set by Invoke-TestFile
				if ($test.Arrange) {
					. $test.Arrange
				}
				if ($test.Act) {
					. $test.Act
				}
				$test.Result = runAssert $test
			} else {
				$test.Skipped = $true
			}
		}
		catch {
			Write-Warning "Exception thrown: $_"
			addGlobalError $_
			$test.Result = $false
		}
		finally {
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
		[Parameter(Mandatory=$false,Position=1)][string[]]$IncludeCategory,
		[Parameter(Mandatory=$false,Position=2)][string[]]$ExcludeCategory
	)
	begin {
		clearGlobalErrors
		$CategoriesBasedDecider = newCategoriesProcessor $IncludeCategory $ExcludeCategory
		$AllFiles = @()
	}
	process {
		$LiteralPath | % { $AllFiles += $_ }
	}
	end {
		$AllFiles |
			% { & $_ |
				Add-Member NoteProperty FileName (gi (Resolve-Path $_).ProviderPath).Name -PassThru |
				Add-Member NoteProperty Path $_ -PassThru
			} |
			Tee-Object -Variable AllResults
						
		$totalTime = $AllResults | Select -ExpandProperty Time | % {$t = [timespan]::Zero } { $t += $_ } { $t }
		$totalResult = $AllResults | Select -ExpandProperty Result | % { $r = $true} { $r = $r -and $_ } { $r }
		$totalFiles = if ($AllFiles.Length -gt 1) { '' } else { $AllFiles[0] }
		newTestResult '--total--' $totalResult $totalTime @() |
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
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='notcontains')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='match')]
		[Parameter(Mandatory=$true,Position=0, ParameterSetName='notmatch')]
		[object]$testedValue,
		
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='eq')][switch]$eq,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='lt')][switch]$lt,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='le')][switch]$le,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='gt')][switch]$gt,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='ge')][switch]$ge,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='contains')][switch]$contains,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='notcontains')][switch]$notcontains,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='match')][switch]$match,
		[Parameter(Mandatory=$false,Position=1, ParameterSetName='notmatch')][switch]$notmatch,
		
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='eq')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='lt')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='le')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='gt')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='ge')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='contains')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='notcontains')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='match')]
		[Parameter(Mandatory=$true,Position=2, ParameterSetName='notmatch')]
		[object]$expectedValue
	)
	switch ($PsCmdlet.ParameterSetName) {
		'istrue' { 
			Write-Debug "istrue $value"
			$r = if ($value -is 'scriptblock') { [bool](& $value) }
				 else { [bool]$value }
			if (!$r) { Write-Warning "Assertion failed: $value returned `$false!" }
			$r
		}
		'isfalse' { 
			Write-Debug "isfalse $value"
			$r = if ($value -is 'scriptblock') { !([bool](& $value)) }
				 else { !([bool]$value) }
			if (!$r) { Write-Warning "Assertion failed: $value returned `$true!" }
			$r
		}
		'eq' { Write-Debug "$testedValue EQ $expectedValue"
			   $r = $testedValue -eq $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' is not equal to '$expectedValue'!" }
			   $r
		}
		'lt' { Write-Debug "$testedValue LT $expectedValue"
			   $r = $testedValue -lt $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' is not less than '$expectedValue'!" }
			   $r}
		'le' { Write-Debug "$testedValue LE $expectedValue"
			   $r = $testedValue -le $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' is not less or equal than '$expectedValue'!" }
			   $r}
		'gt' { Write-Debug "$testedValue GT $expectedValue"
			   $r = $testedValue -gt $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' is not greater than '$expectedValue'!" }
			   $r}
		'ge' { Write-Debug "$testedValue GE $expectedValue"
			   $r = $testedValue -ge $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' is not greater or equal than '$expectedValue'!" }
			   $r}
		'contains' { Write-Debug "$testedValue Contains $expectedValue"
			   $r = $testedValue -contains $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' does not contain '$expectedValue'!" }
			   $r}
		'notcontains' { Write-Debug "$testedValue NotContains $expectedValue"
			   $r = $testedValue -notcontains $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' contains '$expectedValue'!" }
			   $r}
		'match' { Write-Debug "$testedValue Match $expectedValue"
			   $r = $testedValue -match $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' does not match regex '$expectedValue'!" }
			   $r}
		'notmatch' { Write-Debug "$testedValue NotMatch $expectedValue"
			   $r = $testedValue -notmatch $expectedValue
			   if (!$r) { Write-Warning "Assertion failed: '$testedValue' matches regex '$expectedValue'!" }
			   $r}
		default { Write-Debug "Default: $($PsCmdletName.ParameterSetName)" }
	}
}

function newCategoriesProcessor {
	param(
		[Parameter()][string[]]$IncludeCategory,
		[Parameter()][string[]]$ExcludeCategory
	)
	{
		param($testCategories)
		function HasIntersection($arr1, $arr2) {
			if (!$arr1 -or !$arr2) { return $false }
			Compare-Object $arr1 $arr2 -IncludeEqual |?{$_.SideIndicator -eq '=='}
		}
		Write-Debug "IncludeCategory: $IncludeCategory"
		Write-Debug "ExcludeCategory: $ExcludeCategory"
		Write-Debug "TestCategories: $testCategories"
		
		if (!$IncludeCategory -and !$ExcludeCategory)        { Write-Debug "Run";  return $true }   #include, nor exclude selected -> run all
		if (HasIntersection $testCategories $ExcludeCategory){ Write-Debug "NoRun";return $false }  #if exclude was specified and the test has the category -> don't run
		if (HasIntersection $testCategories $IncludeCategory){ Write-Debug "Run";  return $true }   #if include was specified and the test has the category -> run
		if (!$IncludeCategory)                               { Write-Debug "Run";  return $true }   #include not specified -> run
		Write-Debug "NoRun"
		return $false                                                                               #include specified and test cat dont contain the include -> don't run
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
		Add-Member NoteProperty Categories @($categories) -PassThru
}

function runAssert {
	param($testDefinition)
	if (!$testDefinition.Assert) {
		return $true
	}
				
	try {
		$ErrorActionPreference = 'stop'
		$assertDefinition = $test.Assert
		
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
		
		if (!$assertDefinition.ExpectedException) {
			return $false
		}
		while($e -ne $null -and !($e -is $assertDefinition.ExpectedException)) {
			$e = $e.InnerException
			Write-Debug "Exception $e"
		}
		return $e -is $assertDefinition.ExpectedException
	}
}

function addGlobalError {
	param($Error)
	if (!(Test-Path variable:global:posserts_globaerrors)) { 
		$global:posserts_globaerrors = @()
	}
	$global:posserts_globaerrors += $error
}
function clearGlobalErrors {
	$global:posserts_globaerrors = @()
}

Set-Alias test New-Test
Set-Alias arrange Set-Arrange
Set-Alias act Set-Act
Set-Alias assert Set-Assert
Set-Alias category Add-Category
Set-Alias that Test-Condition

Export-ModuleMember -Alias * -Function New-Test, Set-Arrange, Set-Act, Set-Assert, Add-Category, Test-Condition, Invoke-TestFile