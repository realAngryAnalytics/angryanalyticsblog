
Set-ExecutionPolicy RemoteSigned

#This is better for scheduled jobs
$User = "<<enter o365 admin user email here>>"
$PWord = ConvertTo-SecureString -String "<<enter password here>>" -AsPlainText -Force
$UserCredential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord

#This will prompt the user for credential
#$UserCredential = Get-Credential


$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session



$startDate=(get-date).AddDays(-1)
$endDate=(get-date)
$scriptStart=(get-date)

$sessionName = (get-date -Format 'u')+'pbiauditlog'
# Reset user audit accumulator
$aggregateResults = @()
$i = 0 # Loop counter
Do { 
	$currentResults = Search-UnifiedAuditLog -StartDate $startDate -EndDate $enddate `
								-SessionId $sessionName -SessionCommand ReturnLargeSet -ResultSize 1000 -RecordType PowerBI
	if ($currentResults.Count -gt 0) {
		Write-Host ("  Finished {3} search #{1}, {2} records: {0} min" -f [math]::Round((New-TimeSpan -Start $scriptStart).TotalMinutes,4), $i, $currentResults.Count, $user.UserPrincipalName )
		# Accumulate the data
		$aggregateResults += $currentResults
		# No need to do another query if the # recs returned <1k - should save around 5-10 sec per user
		if ($currentResults.Count -lt 1000) {
			$currentResults = @()
		} else {
			$i++
		}
	}
} Until ($currentResults.Count -eq 0) # --- End of Session Search Loop --- #

$data=@()
foreach ($auditlogitem in $aggregateResults) {
    $datum = New-Object –TypeName PSObject
    $d=convertfrom-json $auditlogitem.AuditData
    $datum | Add-Member –MemberType NoteProperty –Name Id –Value $d.Id
    $datum | Add-Member –MemberType NoteProperty –Name CreationTime –Value $auditlogitem.CreationDate
    $datum | Add-Member –MemberType NoteProperty –Name CreationTimeUTC –Value $d.CreationTime
    $datum | Add-Member –MemberType NoteProperty –Name RecordType –Value $d.RecordType
    $datum | Add-Member –MemberType NoteProperty –Name Operation –Value $d.Operation
    $datum | Add-Member –MemberType NoteProperty –Name OrganizationId –Value $d.OrganizationId
    $datum | Add-Member –MemberType NoteProperty –Name UserType –Value $d.UserType
    $datum | Add-Member –MemberType NoteProperty –Name UserKey –Value $d.UserKey
    $datum | Add-Member –MemberType NoteProperty –Name Workload –Value $d.Workload
    $datum | Add-Member –MemberType NoteProperty –Name UserId –Value $d.UserId
    $datum | Add-Member –MemberType NoteProperty –Name ClientIP –Value $d.ClientIP
    $datum | Add-Member –MemberType NoteProperty –Name UserAgent –Value $d.UserAgent
    $datum | Add-Member –MemberType NoteProperty –Name Activity –Value $d.Activity
    $datum | Add-Member –MemberType NoteProperty –Name ItemName –Value $d.ItemName
    $datum | Add-Member –MemberType NoteProperty –Name WorkSpaceName –Value $d.WorkSpaceName
    $datum | Add-Member –MemberType NoteProperty –Name DashboardName –Value $d.DashboardName
    $datum | Add-Member –MemberType NoteProperty –Name DatasetName –Value $d.DatasetName
    $datum | Add-Member –MemberType NoteProperty –Name ReportName –Value $d.ReportName
    $datum | Add-Member –MemberType NoteProperty –Name WorkspaceId –Value $d.WorkspaceId
    $datum | Add-Member –MemberType NoteProperty –Name ObjectId –Value $d.ObjectId
    $datum | Add-Member –MemberType NoteProperty –Name DashboardId –Value $d.DashboardId
    $datum | Add-Member –MemberType NoteProperty –Name DatasetId –Value $d.DatasetId
    $datum | Add-Member –MemberType NoteProperty –Name ReportId –Value $d.ReportId
    $datum | Add-Member –MemberType NoteProperty –Name OrgAppPermission –Value $d.OrgAppPermission

    #option to include the below JSON column however for large amounts of data it may be difficult for PBI to parse
    #$datum | Add-Member –MemberType NoteProperty –Name Datasets –Value (ConvertTo-Json $d.Datasets)

    #below is a poorly constructed PowerShell statemnt to grab one of the entries and place in the DatasetName if any exist
    foreach ($dataset in $d.datasets) {
        $datum.DatasetName = $dataset.DatasetName
        $datum.DatasetId = $dataset.DatasetId
    }
    $data+=$datum
}




$datestring = $startDate.ToString("yyyyMMdd")
$fileName = ("c:\PBIAuditLogs\" + $datestring + ".csv")
Write-Host (" writing to file {0}" -f $fileName)
$data | Export-csv $fileName

Remove-PSSession -Id $Session.Id
