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
$results1 = @{}

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


$query1 = "

IF OBJECT_ID('tempdb..#server','U') IS NOT NULL BEGIN
    DROP TABLE #server
END
IF OBJECT_ID('tempdb..#server') IS NULL
Create table tempdb..#server (ServerName varchar(100), Database_Name varchar(100),QS_Status varchar(100))
insert into tempdb..#server
SELECT @@servername,name, case when (is_query_store_on=0) then 'Disabled' else 'Enabled' end 
FROM sys.databases
WHERE database_id>4
--select * from tempdb..#server

IF OBJECT_ID('tempdb..#serverlist','U') IS NOT NULL BEGIN
    DROP TABLE #serverlist
END

IF OBJECT_ID('tempdb..#QSDB','U') IS NOT NULL BEGIN
    DROP TABLE #QSDB
END

IF OBJECT_ID('tempdb..#QSDB') IS NULL
create table tempdb..#QSDB(id int identity(1,1),DBname varchar(100))
insert into tempdb..#QSDB (DBname)
select Database_Name from tempdb..#server where QS_Status='Enabled'
--select * from tempdb..#QSDB


DECLARE @DBname VARCHAR(MAX),
		@str1 VARCHAR(MAX)

DECLARE C1 CURSOR FOR

SELECT DBname from tempdb..#QSDB

OPEN C1
FETCH NEXT FROM C1 INTO @Dbname

WHILE @@FETCH_STATUS = 0
BEGIN

--set @str1= 'USE ' +@dbname

IF OBJECT_ID('tempdb..#serverlist') IS NULL
Create table tempdb..#serverlist (DBName varchar(100), actual_state_desc varchar(100),desired_state_desc varchar(100),current_storage_size_mb int,max_storage_size_mb int,interval_length_minutes smallint,
stale_query_threshold_days smallint, size_based_cleanup_mode_desc Varchar(10), query_capture_mode_desc varchar(10))





Declare @stmt varchar(max);

set @stmt='insert into tempdb..#serverlist select '''+@Dbname+''',actual_state_desc,desired_state_desc,current_storage_size_mb, max_storage_size_mb, interval_length_minutes,
stale_query_threshold_days,size_based_cleanup_mode_desc,query_capture_mode_desc
from '+@Dbname+'.sys.database_query_store_options;'
print @str1;
print @stmt;
exec(@str1);
exec (@stmt)


FETCH NEXT FROM C1 INTO @DBname
END
CLOSE C1
DEALLOCATE C1

select * from tempdb..#serverlist;

"
$results1.Version = Invoke-SqlQuery -connectionString $connectionString -query $query1



# Generate HTML report
$html = "<html><body>"
$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server: $servername Query Store Status </bold></H2></font></div>                                  
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
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> Disabled </td>"}
  if ($row.Qs_Status -eq 'Enabled') {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> Enabled </td>" }
  
  
    $html += '</tr>'
}

$html += "</table></body></html>"


$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server: $servername Query Store Details Report</bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>DBName</font></b></td>  
 
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Actual_state_desc</font></b></td>  

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Desired_state_desc</font></b></td>   

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Current_storage_size_mb</font></b></td> 

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Max_storage_size_mb</font></b></td> 

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Interval_length_minutes</font></b></td> 

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Stale_query_threshold_days</font></b></td> 

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Size_based_cleanup_mode_desc</font></b></td> 

  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Query_capture_mode_desc</font></b></td> 
 </tr> "

foreach ($row in $results1.Version) {
    $html += "<tr>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.DBName)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.actual_state_desc)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Desired_state_desc)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Current_storage_size_mb)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Max_storage_size_mb)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Interval_length_minutes)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Stale_query_threshold_days)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Size_based_cleanup_mode_desc)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Query_capture_mode_desc)</td>"
    
  
  
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

