test 'simple $false return' {
	assert { 
		$false
	}
}

test '''that'' condition fails' {
	assert { 
		that 1 -eq 2
	}
}

test 'this test will fail, because one of results in assert is $false' {
	assert { 
		that 1 -eq 1
		that 1 -lt 0
		that 1 -lt 2
	}
}

test 'testing expected exception - DivideByZeroException' {
	assert {
		that 1 -istrue
	} -expected System.DivideByZeroException
}

test 'arrange throws exception' {
	arrange { throw 'arrange thrown' }
	act { }
	assert { }
}

test 'act throws exception' {
	arrange { }
	act { throw 'act thrown' }
	assert { }
}

test 'assert throws exception' {
	arrange { }
	act { }
	assert { throw 'assert thrown' }
}