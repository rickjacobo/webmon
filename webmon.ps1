while ($true) {
    
cd $PSScriptRoot

Function Invoke-SQLQuery {
    param (
    $Config,
    $Query
    )

    $Config = Get-Content $Config | ConvertFrom-Json

    $Hostname = $Config.hostname
    $Username = $Config.username
    $Password = $Config.password
    $Database = $Config.database

    mysql --host=$Hostname --user=$Username --password=$Password --database=$Database --execute=$Query  2>/dev/null | ConvertFrom-csv -delimiter `t
}

function Invoke-PagerDutyAlert {

    param (
        $Config,
        $Event_Action = "trigger",
        $Payload_Summary = "message",
        $Payload_Source = "hostname",
        $Dedup,
        $Payload_Severity = "critical"

    )

    $Config = Get-Content $Config | ConvertFrom-Json
    $PagerDutyEndpoint = $Config.pagerduty_endpoint
    $Routing_Key = $Config.pagerduty_routing_key

$Payload = @"
{
    "payload": {
        "summary":"$Payload_Summary",
        "source":"$Payload_Source",
        "severity":"$Payload_Severity"
    },
        "routing_key" : "$Routing_Key",
        "dedup_key":"$Dedup",
        "event_action" : "$Event_Action"
}
"@

Invoke-WebRequest -Method 'Post' -Uri $PagerDutyEndpoint -Body $Payload -ContentType "application/json"
}


$Config = ".config"
$Table = (Get-Content $Config | ConvertFrom-Json).table
#$Table = $Configuration.table
$NotificationEndpoint = (Get-Content $Config | ConvertFrom-Json).notification_endpoint
#$Notification = $Configuration.notification_endpoint
$Query = @"
SELECT * FROM [TABLE]
"@
$Query = $Query.Replace("[TABLE]","$Table")

# Test-Connections
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query
$Hosts | foreach {
    $ID = $_.id
    $Type = $_.type
    $Url = $_.url
    $Keyword = $_.keyword
    $Status = $_.status
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

    if ($Type -eq "keyword") {

$StatusUpdate = @"
UPDATE [TABLE]
SET status = '[STATUS]', lastupdate_utc='[LASTUPDATE]'
WHERE id='[ID]'
"@

	$Wildcard = "*"
	if ((Invoke-RestMethod -Uri $Url) -like "$Wildcard$Keyword$Wildcard" ){
            $StatusUpdate = $StatusUpdate.Replace("[TABLE]","$Table")
            $StatusUpdate = $StatusUpdate.Replace("[STATUS]","Available")
            $StatusUpdate = $StatusUpdate.Replace("[ID]","$Id")
            $StatusUpdate = $StatusUpdate.Replace("[LASTUPDATE]","$Date")
            Invoke-SQLQuery -Config $Config -Query $StatusUpdate
        }
        else {
            $StatusUpdate = $StatusUpdate.Replace("[TABLE]","$Table")
            $StatusUpdate = $StatusUpdate.Replace("[STATUS]","Unavailable")
            $StatusUpdate = $StatusUpdate.Replace("[ID]","$Id")
            $StatusUpdate = $StatusUpdate.Replace("[LASTUPDATE]","$Date")
            Invoke-SQLQuery -Config $Config -Query $StatusUpdate
        }
    }

}


### Alert Notification
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query | where {$_.status -ne "Available" -and $_.alert -ne "Alerted"}
$Hosts | Foreach {

    $ID = $_.id
    $Type = $_.type
    $Port = $_.url
    $Keyword = $_.keyword
    $Status = $_.status
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

$AlertUpdate = @"
UPDATE [TABLE]
SET alert ='[ALERT]', lastupdate_utc='[LASTUPDATE]', pagerduty_dedup='[DEDUPKEY]'
WHERE id='[ID]'
"@
    $Seperator = "::"
    $Alert_message = "$Url$Seperator$Keyword [$Date UTC]"
    Write-Host $Alert_message
    #$AlertEndpoint = "$NotificationEndpoint$Alert_message"
    #Invoke-WebRequest $AlertEndpoint
    $PagerDutyAlert = ((Invoke-PagerDutyAlert -Config $Config -Payload_Summary $Alert_message).content  | ConvertFrom-Json).dedup_key

    $AlertUpdate = $AlertUpdate.Replace("[TABLE]","$Table")
    $AlertUpdate = $AlertUpdate.Replace("[ALERT]","Alerted")
    $AlertUpdate = $AlertUpdate.Replace("[ID]","$Id")
    $AlertUpdate = $AlertUpdate.Replace("[LASTUPDATE]","$Date")
    $AlertUpdate = $AlertUpdate.Replace("[DEDUPKEY]","$PagerDutyAlert")
    Invoke-SQLQuery -Config $Config -Query $AlertUpdate
}


### Resolved Alert Notification
$Hosts = Invoke-SQLQuery -Config $Config -Query $Query | where {$_.status -eq "Available" -and $_.alert -eq "Alerted"}
$Hosts | Foreach {
#Send Resolved Message
    $ID = $_.id
    $Type = $_.type
    $Url = $_.url
    $Keyword = $_.keyword
    $Status = $_.status
    $Dedup = $_.pagerduty_dedup
    $Date = ((Get-Date).ToUniversalTime()).ToString("yyyy-MMdd-HHmm")

$AlertUpdate = @"
UPDATE [TABLE]
SET alert ='[ALERT]', lastupdate_utc='[LASTUPDATE]', pagerduty_dedup='[DEDUPKEY]'
WHERE id='[ID]'
"@
    $Seperator = "::"
    $Resolve_message = "Resolved: $Url$Seperator$Keyword [$Date UTC]"
    Write-Host $Resolve_message
    #$ResolveEndpoint = "$NotificationEndpoint$Resolve_message"
    #Invoke-WebRequest $ResolveEndpoint
    Invoke-PagerDutyAlert -Config $Config -Payload_Summary $Resolve_message -Dedup $Dedup -Event_Action "resolve"

    $AlertUpdate = $AlertUpdate.Replace("[TABLE]","$Table")
    $AlertUpdate = $AlertUpdate.Replace("[ALERT]","")
    $AlertUpdate = $AlertUpdate.Replace("[ID]","$Id")
    $AlertUpdate = $AlertUpdate.Replace("[LASTUPDATE]","$Date")
    $AlertUpdate = $AlertUpdate.Replace("[DEDUPKEY]","")
    Invoke-SQLQuery -Config $Config -Query $AlertUpdate
}
Start-Sleep -S $env:ENV_POLL_FREQUENCY_SECONDS
}
