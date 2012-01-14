test 'first test' {
	arrange {
		$expected = 'aaa'
	}
	act {
		$tested = 'a' * 3
	}
	assert {
		that $expected -eq $tested
	}
}

test 'more asserts are possible' {
	act {
		$rand = Get-Random -Minimum 0 -Maximum 3
		Write-Host "Generated: $rand"
	}
	assert {
		that $rand -ge 0
		that $rand -le 3
		that ($rand -eq 0 -or $rand -eq 1 -or $rand -eq 2 -or $rand -eq 3) -istrue
	}
}

test 'empty assert is possible' {
	assert { Write-Host "empty assert, nothing is returned" }
}

test 'testing expected exception - ItemNotFoundException' {
	assert {
		that (Get-Item d:\doesntexist -EA stop) -eq $null
	} -expected System.Management.Automation.ItemNotFoundException
}

test 'testing expected exception - DivideByZeroException' {
	arrange {
		$div = 0
	}
	assert {
		that (1 / $div) -eq '?'
	} -expected System.DivideByZeroException
}