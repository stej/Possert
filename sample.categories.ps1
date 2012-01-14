test test1 {
	category no-assert
}

test test2 {
	category with-assert
	assert { that 1 -eq 1 }
}
test test3-mightFail {
	category random, with-assert
	assert { that (get-random -min 0 -max 1000) -lt 999 }
}
test 'long running test' {
	category with-assert, long-running
	act {
		Start-Sleep -mil 500
	}
	assert {
		$true
	}
}
test test5 {
	category with-assert, last
	assert { $true }
}