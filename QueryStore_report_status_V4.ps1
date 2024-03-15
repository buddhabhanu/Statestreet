########################################################################################################################################################


            ######### Autohor: Bhanu Buddha ( Senior SQL Server DBA) ############################
            # This PS Script can execute on all versions of SQL server But the Expected results can be viewed ONly from SQL server 2016 or Above
            # This Powershell Automation validate the Query Store Enabled or not
            # It will List out only the Databases which are Disabled.
            # It will Notifiy the Databases and Last running time of Query Store under the Same Instance.
            # But it will list Only if Not running from last 24 hours or above.

###########Ex: If the Query Store not running from last 12 hours will not be published here#############
######If the Query Store not running from last 24 hours will be published here #########################
########################################################################################################################################################

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
$results2 = @{}

# Validate SQL Server version, QS worked only onwards SQL Server 2016 or above

$query2 = "
If object_id(N'tempdb..#version') Is NOT NULL begin
Drop table tempdb..#version end
create table tempdb..#version (version_details varchar (max))
insert into tempdb..#version select @@VERSION
declare @version int;
select @version=count(*) from tempdb. #version where version_details like '%SQL Server 2016%' or version_details like '%SQL Server 2017%' or version_details like '%SQL Server 2019%' or version_details like '%SQL Server 2022%'
select @version "

$results2.Version = Invoke-SqlQuery -connectionString $connectionString -query $query2
#$results2.Version. Column1
# This Query will list the databases and display in concadination where the query story is disbaled.
$query = "
Create table #server (ServerName varchar (100), Database_Name varchar (max), QS_Status varchar(100))
insert into #server
SELECT top 1 @@servername, STUFF((select', ' + name 
FROM sys. databases where database_id>4 and name not in ('dba', 'TEST', 'ssb_securitydb', 'ssb_inventorydb', 'ssga_security', 'ups_connector_owner', 'MDW', 'SECURITY', 'dba','Dbe', 'SPerfDW', 'SSgADBA')
and is_query_store_on=0
FOR XML PATH('')), 1,2, ''), case when (is_query_store_on=0) then 'Disabled' else 'Enabled' end
FROM sys. databases
WHERE database_id>4 and name not in ('dba', 'ssb_securitydb'
, 'ssga_security',
'ups_connector_owner', 'MDW', 'SECURITY'
, ' SSgADBA')
and is_query_store_on=0
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
Create table tempdb..#serverlist (DBName varchar(100),Last_Running_time varchar(max));

--Create table tempdb..#serverlist (DBName varchar(100), actual_state_desc varchar(100),desired_state_desc varchar(100),current_storage_size_mb int,max_storage_size_mb int,interval_length_minutes smallint,
--stale_query_threshold_days smallint, size_based_cleanup_mode_desc Varchar(10), query_capture_mode_desc varchar(10))

Declare @stmt varchar(max);


DECLARE @gmtTime nvarchar(max) --= '2024-03-09 12:00:00 +00:00'; -- GMT time
declare @out DATETIMEOFFSET



--DECLARE @gmtTime DATETIMEOFFSET;
DECLARE @sql NVARCHAR(MAX);

SET @sql = 'SELECT TOP 1 @gmtTime = last_execution_time FROM ' + QUOTENAME(@Dbname) + '.sys.query_store_runtime_stats ORDER BY last_execution_time DESC';
EXEC sp_executesql @sql, N'@gmtTime DATETIMEOFFSET OUTPUT', @gmtTime OUTPUT;
select @out=@gmtTime



DECLARE @currentOffset INT = DATEDIFF(MINUTE, GETUTCDATE(), GETDATE());

Declare @time_diff datetime

SELECT @time_diff=DATEADD(MINUTE, @currentOffset, @out);
--select @time_diff;

insert into tempdb..#serverlist
select QUOTENAME(@Dbname),@time_diff
--select QUOTENAME(@Dbname),CAST(((DATEDIFF(s,@time_diff,GetDate()))/3600) as varchar) + ' hour(s), ' 
--        + CAST((DATEDIFF(s,@time_diff,GetDate())%3600)/60 as varchar) + 'min, ' 
--        + CAST((DATEDIFF(s,@time_diff,GetDate())%60) as varchar) + ' sec' as RUNNING_TIME

--select CAST((DATEDIFF(s,@time_diff,GetDate())%3600)/60 as varchar) 

--set @stmt='insert into tempdb..#serverlist select '''+@Dbname+''',CAST(((DATEDIFF(s,@time_diff,GetDate()))/3600) as varchar) + '' hour(s), '' 
--        + CAST((DATEDIFF(s,@time_diff,GetDate())%3600)/60 as varchar) + ''min, '' 
--        + CAST((DATEDIFF(s,@time_diff,GetDate())%60) as varchar) + '' sec'' as RUNNING_TIME
--from '+@Dbname+'.sys.query_store_runtime_stats order by last_execution_time desc;'
--print @str1;
--print @stmt;
--exec(@str1);
--exec (@stmt)


FETCH NEXT FROM C1 INTO @DBname
END
CLOSE C1
DEALLOCATE C1

select * from tempdb..#serverlist  --where Last_Running_time < getdate()-1
"
$results1.Version = Invoke-SqlQuery -connectionString $connectionString -query $query1



# Generate HTML report
$html = "<html><body>"
$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server: $servername Query Store Status </bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"


 $html += "<div><img align=center  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#00008B> Query Store Option Disabled Databases List </font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

 # If the SQL server version above 2016 will display the details
 if($results2.Version.Column1 -eq 1)
 {
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
    $html += "</table></body></html>" 


    $html +="<br><br>"

 $html += "<div><img align=center  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#00008B> Database Query Store Enabled and Not Running from last 24 Hours  </font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"




#    $html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server: $servername Query Store Details Report</bold></H2></font></div>                                  
 #<table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>DBName</font></b></td>  
 
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Query_Store_Last_Running_Time</font></b></td>  

  </tr> "

foreach ($row in $results1.Version) {
    $html += "<tr>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.DBName)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Last_Running_time)</td>" 
  
  
    $html += '</tr>'
}

$html += "</table></body></html>"



#$html += "</table>"

$html += "</table></body></html>"






} }

else
{

$html += "<div><img align=right  style=height: 25px; width: 25px/><font face=Verdana size=2 color=#FF0000><H2>$servername : Query Store Is NOT Supported in Current Version </H2></font></div> "

}



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

