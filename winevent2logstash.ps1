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

# Send events from the last $REPORT_FREQUENCY minutes
$starttime = (get-date).addminutes(-$REPORT_FREQUENCY)
$data = Get-WinEvent -FilterHashtable @{logname="*"; starttime=$starttime}

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
