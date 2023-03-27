$bodys = @" 
{
  "name": "M3HAD21LB73N4GSHGJIC2MDM115A5GJT",
    "processors": 1,
  "memory": 512,
}
"@


$Body = @{

    'id'= "M3HAD21LB73N4GSHGJIC2MDM115A5GJT";
    'processors' = 4;
    'memory' = 2048

}


function Test-JsonFormat {
  [cmdletbinding()]
  param(
      [ValidateScript(
      {
          if ( $_ | Test-Json -ErrorAction SilentlyContinue) {
            return $true
          }
      }, errormessage = " {1} The input was no valid JSON formatted PSCustomObject ")]
      $body
  )
  return $true
}

#$test = test-jsonformat -Body $RequestText
#$test