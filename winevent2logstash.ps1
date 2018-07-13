#
# winevent2logstash.ps1
#
# Send Windows Event logs to a remote LogStash instance
# Note: Required PowerShell V3
#
# Author: Tim Faircloth <nova20(at)slashback(dot)org>
#
# Feel free to use the code but please share the changes you've made

# Change to match your setup
$LOGSTASH_SERVER = "LOGSTASH_HOST"
$LOGSTASH_PORT = 5001

# The number of minutes between dumps
$REPORT_FREQUENCY = 1

Function Split-Array {
  [CmdletBinding()]
    Param(
        [Parameter(
          Position = 0,
          Mandatory = $True,
          ParameterSetName = "Array"
          )]
        [Object[]]
        $Array,

        [Parameter(
          ValueFromPipeline = $True,
          Mandatory = $True,
          ParameterSetName = "Collect"
          )]
        [Object]
        $InputObject,

        [Int]
        $Size = 250
        )
      Begin {
        If($psCmdlet.ParameterSetName -eq 'Collect'){
          $Array = @()
            Write-Verbose "Collecting objects into an array."
        }
      }
  Process {
    If($psCmdlet.ParameterSetName -eq 'Collect'){
      $Array += $InputObject
    }
  }
  End {
    $length = $Array.Length
      Write-Verbose "Array length: $length."
      $numberOfArrays = [Math]::Ceiling($length / $Size)
      Write-Verbose "To be split into $numberOfArrays arrays."
      $lengthOfArrays = [Math]::Ceiling($length / $numberOfArrays)
      Write-Verbose "The maximum length of each array will be $lengthOfArrays."
      ForEach($i in (1..$numberOfArrays)) {
        $start = ($i - 1) * $lengthOfArrays
          $end = $i * $lengthOfArrays - 1
          If($end -gt ($length - 1)){
            $end = $length - 1
          }
        Write-Verbose ("Returning array $i of $numberOfArrays from " +`
            "original array's index $start to $end")
          ,$Array[$start..$end]
      }
  }
}

# Send events from the last $REPORT_FREQUENCY minutes
$starttime = (get-date).addminutes(-$REPORT_FREQUENCY)

#$data = Get-WinEvent -FilterHashtable @{logname="*"; starttime=$starttime}

#Get log sets
$log_sets = Get-WinEvent -ListLog * | 
  Select-Object -ExpandProperty LogName | 
  Split-Array

$data = @()

foreach($lset in $log_sets) {
    $data += Get-WinEvent -FilterHashtable @{logname=$lset; starttime=$starttime}
}

$total = ($data | measure).count
$curr = 0

  $ip = [System.Net.Dns]::GetHostAddresses($LOGSTASH_SERVER)
  $address = [System.Net.IPAddress]::Parse($ip)
  $socket = New-Object System.Net.Sockets.TCPClient($address, $LOGSTASH_PORT)
  $stream = $socket.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)

  $data | foreach {
    $curr = $curr +1
      "sending " + $curr + "/" + $total

      $event = $_ | ConvertTo-Json
      $event = $event -replace "`n",' ' -replace "`r",''
      $event = $event -replace '"Message"','"message"'

      $writer.writeline($event)
  }
  $writer.Flush()
  $stream.close()
$socket.close()
