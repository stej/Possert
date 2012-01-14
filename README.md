Possert
=============

Possert is simple PowerShell module for testing of PowerShell code. The module is inspired by [@Jaykul's PSaint](http://huddledmasses.org/arrange-act-assert-intuitive-testing/) module, but I wanted to keep it simpler and more readable.

Where to start
-------

Just download the Possert directory, open PowerShell console and run `possert.test.ps1`. This is tests the module itself.

How to test your code?
-------

You may take inspiration from `possert.test.ps1`. Or ...
Import module possert.psm1.
Create file that contains something like 

    test 'name of test' {
			arrange {  # code to arrange the test }
			act { # do something }
			assert { # and check the results; return [bool] value indicating the result }
    }
    
and run the file. That's it.

You may also run more test files like this (I assume the module is imported)

    gci c:\directory test*.ps1 | Invoke-TestFile
    
For more inspiration looke at the `sample*.ps` files.