test operators {
  assert { 
    that 1 -eq 1
    that 1 -lt 2
    that 1 -le 2
    that 1 -gt 0
    that 1 -ge 0
    that 'a' -match \w
    that 1,2 -contains 2
  }
}

test scriptblock {
  assert { 
    that { [bool]1 } -istrue
    that { $false } -isfalse
  }
}

test simplevalue {
  assert { 
    that $true
    that $true -istrue
    that $false -isfalse
  }
}