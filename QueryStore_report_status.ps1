FOREACH($server in GC "C:\Powershell\ServerList.txt")
 {
	#invoke-expression -Command "&'D:\Powershell\Health_check_updating.ps1' -ComputerName $server"  
$ComputerName=$server
 
<# param
(
    [parameter(Mandatory = $true)]
    [Alias("HostName", "SeverName")]
    [string[]] $ComputerName 
    
)
#>
$ServersNotReachable = @()

$ComputerName | ForEach-Object {

$count =Test-Connection $_ -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($true -eq $count)

    {

# SQL Server Connection Details
$serverName = $server
$databaseName = "master"
$connectionString = "Server=$serverName,1433;Database=$databaseName;Integrated Security=True"




# Output HTML file path
$htmlFilePath = "\\VBOXSVR\ORACLE_Share\PS_SQL_Health_report\reports\"+$servername+"_SQLQueryStore_Status.html"

# Function to execute SQL queries and return results
function Invoke-SqlQuery {
    param (
        [string]$connectionString,
        [string]$query
    )
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $command = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
    
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
    $dataset = New-Object System.Data.DataSet
    
    $connection.Open()
   $adapter.Fill($dataset) | Out-Null
    $connection.Close()
    
    return $dataset.Tables[0]
}

# Perform SQL Server health check

$results = @{}

# Get SQL Server version
$query = "

Create table #server (ServerName varchar(100), Database_Name varchar(100),QS_Status varchar(100))
insert into #server
SELECT @@servername,name, case when (is_query_store_on=0) then 'Disabled' else 'Enabled' end 
FROM sys.databases
WHERE database_id>4
select * from #server

drop table #server"
$results.Version = Invoke-SqlQuery -connectionString $connectionString -query $query



# Generate HTML report
$html = "<html><body>"
$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server Pre & Post Check Report</bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Server Name</font></b></td>  
 
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Database Name</font></b></td>  

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Query_Store_Status</font></b></td>   
 </tr> "

foreach ($row in $results.Version) {
    $html += "<tr>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.ServerName)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Database_Name)</td>"
     #$html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Qs_Status)</td>"
      if ($row.Qs_Status -eq 'Disabled') {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> Disabled </td>"}
  if ($row.Qs_Status -eq 'Enabled') {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> Enabled </td>" }
  
  
    $html += '</tr>'
}

$html += "</table></body></html>"






$html += "</table>"

$html += "</table></body></html>"

#$html += "</body></html>"

$html +='</table>                                  
   <td align="Center">                              
 <font face="Verdana" size="4" color="#008000"><H3><bold>This is Auto Generated Server Report </bold></H3></font> </td>

                                 
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" 

cellSpacing="0" cellPadding="0" width="933" border="2">'

# Save HTML report to file
$html | Out-File -FilePath $htmlFilePath

Write-Host "SQL Server health check completed. HTML report generated at $htmlFilePath."

###################### Send the HTML report Through the SQL DB Mail ########################################

# Define the path to your HTML file


# Read the contents of the HTML file
$htmlContent = Get-Content -Path $htmlFilePath -Raw

# SQL Server connection details
$serverName = "your_server_name"
$databaseName = "msdb"
$smtpServer = "your_smtp_server"
$mailProfile = "your_mail_profile_name"
$recipient = "recipient@example.com"
$subject = "Summary Health Check for the SQL Server "+ $server +" is " + "$results.Summary.name"

# Build the SQL query to send the HTML email
$query = @"
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = '$mailProfile',
    @recipients = '$recipient',
    @subject = '$subject',
    @body = '',
    @body_format = 'HTML',
    @file_attachments = '$htmlFilePath'
"@

# Execute the SQL query
#Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Query $query -QueryTimeout 0 -SmtpServer $smtpServer


}


  else
    {
        $ServersNotReachable += $_ 
        Write-Host "The server(s) below is/are not reachable..." -ForegroundColor Red
        $ServersNotReachable
        
    }
}
}

