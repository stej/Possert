test test1 {
  category no-assert
}

test test2 {
  category with-assert
  assert { that 1 -eq 1 }
}
test test3 {
  category random, with-assert
  assert { that (get-random -min 0 -max 10) -lt 5 }
}
test 'long running test' {
  category with-assert, long-running
	act {
		Start-Sleep -Seconds 1
	}
	assert {
		$true
	}
}