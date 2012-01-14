$root = split-path $myinvocation.MyCommand.Path

ipmo $root\possert.psm1 -force -verbose

filter withoutTotal {
	if ($_.Test -ne '--total--') { $_ }
}
filter onlyTotal {
	if ($_.Test -eq '--total--') { $_ }
}
filter testsWithCategory($category1, $category2) {
	if ($_.Categories -contains $category1) { return $_ }
	if ($category2 -and $_.Categories -contains $category2) { return $_ }
	#$_
}
filter testsWithoutCategory($category1, $category2) {
	if ($_.Categories -notcontains $category1) { return $_ }
	if ($category2 -and $_.Categories -notcontains $category2) { return $_ }
}

test 'there are 7 failed tests in sample.fail.ps1' {
	category general
	act { 
		$results = Invoke-TestFile $root\sample.fail.ps1 | withoutTotal
	}
	assert {
		#Write-Debug "Results: $($results | out-string)"
		that $results.Count -eq 7
		that ($results | Select -expand Result) -notcontains $true
	}
}

test 'if no category is specified as Include or Exclude, all tests are run' {
	category categories-test
	act { $results = Invoke-TestFile $root\sample.categories.ps1 | withoutTotal }
	assert { that $results.Count -eq 5 }
}

test 'if one category is specified as Include, only tests with this category are ran' {
	category categories-test
	act { $results = Invoke-TestFile $root\sample.categories.ps1 -Include with-assert | withoutTotal }
	assert { 
		that $results.Count -eq 4 
		that ($results | testsWithCategory with-assert).Count -eq 4
	}
}

test 'if more categories are specified as Include, tests with any such category is ran' {
	category categories-test
	act { $results = Invoke-TestFile $root\sample.categories.ps1 -Include no-assert, last | withoutTotal }
	assert { 
		that $results.Count -eq 2 
		that ($results | testsWithCategory no-assert last).Count -eq 2
	}
}

test 'if category is specified for Include and other for exclude, tests are properly excluded' {
	category categories-test
	act { $results = Invoke-TestFile $root\sample.categories.ps1 -Include with-assert -Exclude last | withoutTotal }
	assert { 
		that $results.Count -eq 3 
		that ($results | testsWithoutCategory last).Count -eq 3
	}
}

test 'if category is specified for Include and more for exclude, tests are properly excluded' {
	category categories-test
	act { $results = Invoke-TestFile $root\sample.categories.ps1 -Include with-assert -Exclude last, long-running | withoutTotal }
	assert { 
		that $results.Count -eq 2 
		that ($results | testsWithoutCategory last, long-running).Count -eq 2
	}
}

test 'passing tests by pipeline to Invoke-TestFile works' {
	category invoking
	act {  $results = gci $root sample*.ps1 | Invoke-TestFile | withoutTotal }
	assert { 
		that $results.Count -eq 20
	}
}

test 'passing tests as parameters to Invoke-TestFile works' {
	category invoking
	arrange {
		$files = "$root\sample.basic.ps1", 
						 "$root\sample.categories.ps1", 
						 "$root\sample.fail.ps1", 
						 "$root\sample.testthat.ps1"
	}
	act {  $results = Invoke-TestFile $files | withoutTotal }
	assert { 
		that $results.Count -eq 20
	}
}

test 'total time is equal to sum of times of all tests' {
	category report
	arrange { 
		$results = gci $root sample*.ps1 | Invoke-TestFile
		$resultsNoTotal = $results | withoutTotal
		$resultsOnlyTotal = $results | onlyTotal
	}
	act { 
		$timeSumNoTotal = $resultsNoTotal  | Select -exp Time | % { $t=[timespan]::zero }{$t += $_}{$t}
	}
	assert { 
		that $resultsOnlyTotal.Time -eq $timeSumNoTotal
	}
}