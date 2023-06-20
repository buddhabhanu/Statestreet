FOREACH($server in GC "D:\Powershell\SQL_Report_auto\ServerList.txt")
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
$connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True"




# Output HTML file path
$htmlFilePath = "\\VBOXSVR\ORACLE_Share\PS_SQL_Health_report\reports\"+$servername+"_SQLHealthCheck.html"

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
$query = "Declare @servername2 varchar(100)
set @servername2 = @@SERVERNAME

DECLARE @test varchar(200), @key varchar(100)
if charindex('\',@@servername,0) <>0
begin
set @key = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'
+@@servicename+'\MSSQLServer\Supersocketnetlib\TCP'
end
else
begin
set @key = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\TCP'
end

Declare @port varchar(100)
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',
@key=@key,@value_name='Tcpport',@value=@test OUTPUT
SELECT @port=+convert(varchar(10),@test) 

Create table #server (ServerName varchar(100), port_number int)
insert into #server
select @@SERVERNAME as [ServerName], @port as [Port_number]
select * from #server

drop table #server"
$results.Version = Invoke-SqlQuery -connectionString $connectionString -query $query

# SQL Server Details like version , Edition, Collation, Clustered

$query="    
DECLARE @TableHTML  VARCHAR(MAX),                                    
  @StrSubject VARCHAR(100),                                    
  @Oriserver VARCHAR(100),                                
  @Version VARCHAR(500),                                
  @Edition VARCHAR(100),                                
  @ISClustered VARCHAR(100),                                
  @SP VARCHAR(100),                                
  @ServerCollation VARCHAR(100),                                                                
  @LicenseType VARCHAR(100),                                
  @Cnt int,           
  @URL varchar(1000),                                
  @Str varchar(1000),                                
  @NoofCriErrors varchar(300)       
  
-- Variable Assignment   


  
SELECT @Version = CONVERT(VARCHAR(500), @@version)                                   
SELECT @Edition = CONVERT(VARCHAR(100), serverproperty('Edition'))                            

    
SET @Cnt = 0                                
IF serverproperty('IsClustered') = 0                                 
BEGIN                                
 SELECT @ISClustered = 'No'                                
END                                
ELSE        
BEGIN                                
 SELECT @ISClustered = 'YES'                                
END                                
SELECT @SP = CONVERT(VARCHAR(100), SERVERPROPERTY ('productlevel'))                           

     
SELECT @ServerCollation = CONVERT(VARCHAR(100), SERVERPROPERTY ('Collation'))                 

                
SELECT @LicenseType = CONVERT(VARCHAR(100), SERVERPROPERTY ('LicenseType'))                   

              
                             
SELECT @OriServer = CONVERT(VARCHAR(50), SERVERPROPERTY('servername'))                        

Declare @compatable nvarchar(100)
Declare @compatable1 nvarchar(100)
select @compatable= convert(nvarchar(100),SERVERPROPERTY('ProductVersion'))
select @compatable1=SUBSTRING(@compatable,1,2)


Create table [#SQLDetails] ([SQLVersion] varchar(500),Edition varchar(50),SP varchar(100),SQLCollation varchar(200),Is_Clustered varchar(10))

insert into [#SQLDetails]
select @Version as [SQLVersion],@Edition as [Edition],@SP as [SP],@ServerCollation as [SQLCollation],@ISClustered as [Clustered]

select * from #SQLDetails

Drop Table #SQLDetails

"
$results.SQLDetails = Invoke-SqlQuery -connectionString $connectionString -query $query

### SQL Server Services Script

$query = "CREATE TABLE #Serviceaccount                                
( 
Name Varchar(100),
 Status_count int                     
)                        
Insert into #Serviceaccount          
select 'SQL SERVER Status',count(Status) as Status from sys.dm_server_services where status_desc ='Running' 

Select name ,  Status_count from #Serviceaccount



drop table #Serviceaccount"

$results.Services = Invoke-SqlQuery -connectionString $connectionString -query $query

## SQL Server Connectivity Check

$query = "CREATE TABLE #SQLconnectivity
(   

Name varchar(100),
 table_count int                              
                       
)                        
Insert into #SQLconnectivity 
select 'SQL Server Connectivity Check',count(*) from master.sys.tables

select * from #SQLconnectivity

drop table #SQLconnectivity"

$results.SQLconnectivity = Invoke-SqlQuery -connectionString $connectionString -query $query


## SQL Database health Check

$query = "CREATE TABLE #SQLDatabases
(                                

 Name varchar(100),                               
 DB_Count int
)   
Insert into #SQLDatabases
select  'SQL Databases Health Check',count(database_id) from sys.databases  where database_id not in(1,2,3,4) and user_access_desc <>'MULTI_USER' or is_read_only=1 or state_desc<>'ONLINE'

Select * from #SQLDatabases

drop table #SQLDatabases"

$results.SQLDatabases = Invoke-SqlQuery -connectionString $connectionString -query $query


## SQL ErrorLog Check for 4 Hours


$query = "CREATE TABLE #ErrorLogInfo_all                                
(                                
 LogDate  datetime,  
 processinfo varchar(200),                                
 LogInfo  varchar(1000)                                 
)

CREATE TABLE #ErrorLog_count                               
(                                
Name Varchar(100),
Error_count int
)


INSERT INTO #ErrorLogInfo_all
EXEC XP_READERRORLOG 0, 1,N'Login', N'Failed' --, @A,@B,'DESC';

INSERT INTO #ErrorLogInfo_all
EXEC XP_READERRORLOG 0, 1,N'Error';

INSERT INTO #ErrorLogInfo_all
EXEC XP_READERRORLOG 0, 1,N'severity: 16';


Insert INTO #ErrorLog_count
select 'SQL Error Log Checks in Last 4 Hrs ',count(loginfo) from #ErrorLogInfo_all where LogInfo not like '%ERRORLOG%' and LogDate > DATEADD(HOUR, -4, GETDATE())


select * from #ErrorLog_count

drop table #ErrorLogInfo_all

drop table #ErrorLog_count"

$results.SQLERRORLOG = Invoke-SqlQuery -connectionString $connectionString -query $query


## SQL Server Orphaned USers Check


$query = "DECLARE @DBName NVARCHAR(128)
DECLARE @SQL NVARCHAR(MAX)

DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases WHERE state_desc = 'ONLINE'

CREATE TABLE #OrphanedUsers (
    DBName NVARCHAR(128),
    UserName NVARCHAR(128),
    SID VARBINARY(85)
)

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @DBName

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
    USE [' + @DBName + ']
    INSERT INTO #OrphanedUsers
    SELECT ''' + @DBName + ''', u.name, u.sid
    FROM sys.database_principals u
    LEFT JOIN sys.server_principals s ON u.sid = s.sid
    WHERE u.sid IS NOT NULL AND s.sid IS NULL AND u.type_desc = ''SQL_USER''
    '

    EXEC sp_executesql @SQL

    FETCH NEXT FROM db_cursor INTO @DBName
END

CLOSE db_cursor
DEALLOCATE db_cursor

Create Table #Orphan_count
(Name Varchar(100),
Orphaned_count int)


INSERT INTO #Orphan_count
SELECT 'SQL OrphanedUsers Check on All DBs',count(*) as Orphaned_Count FROM #OrphanedUsers where UserName not in('guest','MS_DataCollectorInternalUser')

select * from #Orphan_count

drop table #OrphanedUsers
Drop table #Orphan_count "

$results.SQLOrphaned = Invoke-SqlQuery -connectionString $connectionString -query $query


# Get database size
$query = "SELECT DB_NAME(database_id) AS [DatabaseName], 
                 CAST(SUM(size * 8.0 / 1024) AS DECIMAL(10, 2)) AS [SizeMB]
          FROM sys.master_files 
          WHERE Database_id>4 and type = 0
          GROUP BY database_id"
$results.DatabaseSize = Invoke-SqlQuery -connectionString $connectionString -query $query


# Generate HTML report
$html = "<html><body>"
$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>MSSQL Server Pre & Post Check Report</bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Server Name</font></b></td>  
 
  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Port Number</font></b></td>   
 </tr> "

foreach ($row in $results.Version) {
    $html += "<tr>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.ServerName)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Port_number)</td>"
    $html += "</tr>"
}

$html += "</table></body></html>"






# SQl Server Details Gathering

$html += "<div><img align=right  style=height: 50px; width: 90px/><font face=Verdana size=4 color=#3399ff><H2><bold>SQL Server Details </bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=49% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>SQLVersion</font></b></td>  
 
  <td width=29% height=10 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Edition</font></b></td>   

  <td width=15% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>SP</font></b></td>  
 
  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>SQL_Collation</font></b></td>   
 
  <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=2 color=#FFFFFF>Is_Clustered</font></b></td>   
 </tr> "

foreach ($row in $results.SQLDetails) {
    $html += "<tr>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.SQLVersion)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Edition)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.SP)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.SQLCollation)</td>"
    $html += "<td style='border: 1px solid black; padding: 5px;'>$($row.Is_Clustered)</td>"
    $html += "</tr>"
}

$html += "</table></body></html>"


# Summary Report

$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=5 color=#3399ff><H2><bold>Summary Report for SQL Server </bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"


 # Get SQL SERVER Services Status 



foreach ($row in $results.Services) {

 $html += "<tr>"
   $html += "<td align='Left'><font face='Verdana' size='5' color='#9933FF'> $($row.Name)</td>"
    if ($row.Status_count -eq 3) {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> GREEN </td>"}
  if ($row.Status_count -lt 3) {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> RED </td>"
  
  }        
        
 $html += "</tr>" 

}

#$html += "</table></body></html>"


# Get SQL SERVER Connectivity Check



foreach ($row in $results.SQLconnectivity) {

 $html += "<tr>"
   $html += "<td align='Left'><font face='Verdana' size='5' color='#9933FF'> $($row.Name)</td>"
    if ($row.table_count -gt 0) {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> GREEN </td>"}
  if ($row.table_count -eq 0) {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> RED </td>"
  
  }        
        
 $html += "</tr>" 

}

# Get SQL SERVER Databases CHeck



foreach ($row in $results.SQLDatabases) {

 $html += "<tr>"
   $html += "<td align='Left'><font face='Verdana' size='5' color='#9933FF'> $($row.Name)</td>"
    if ($row.DB_count -eq 0) {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> GREEN </td>"}
  if ($row.db_count -gt 0) {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> RED </td>"
  
  }        
        
 $html += "</tr>" 

}

# Get SQL SERVER ErrorLog CHeck



foreach ($row in $results.SQLERRORLOG) {

 $html += "<tr>"
   $html += "<td align='Left'><font face='Verdana' size='5' color='#9933FF'> $($row.Name)</td>"
    if ($row.Error_count -eq 0) {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> GREEN </td>"}
  if ($row.Error_count -gt 0) {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> RED </td>"
  
  }        
        
 $html += "</tr>" 

}

#$html += "</table></body></html>"

# Get SQL SERVER Orphansed Users  CHeck



foreach ($row in $results.SQLOrphaned) {

 $html += "<tr>"
   $html += "<td align='Left'><font face='Verdana' size='5' color='#9933FF'> $($row.Name)</td>"
    if ($row.orphaned_count -eq 0) {
  $html += "<td align='Left'><font face='Verdana' size='5' color='#40C211'> GREEN </td>"}
  if ($row.orphaned_count -gt 0) {
  
  $html += "<td align='Left'><font face='Verdana' size='5' color='#FF0000'> RED </td>"
  
  }        
        
 $html += "</tr>" 

}

$html += "</table></body></html>"




# Database size section

$html += "<div><img align=right  style=height: 50px; width: 50px/><font face=Verdana size=4 color=#3399ff><H2><bold>User Databases in SQL Server </bold></H2></font></div>                                  
 <table border=1 cellpadding=0 cellspacing=0 style=border-collapse: collapse bordercolor=#111111 width=47% id=AutoNumber1 height=50"

$html += "<table><tr>                                  
 <td width=39% height=22 bgcolor=#000080><b>                           
 <font face=Verdana size=4 color=#FFFFFF>DATABSE NAME</font></b></td>  
 
  <td width=20% height=10 bgcolor=#000080><b>                           
 <font face=Verdana size=4 color=#FFFFFF>DB SIZE</font></b></td>   
 
 </tr> "


#$html += "<h2>Database Size</h2>"
#$html += "<table><tr><th>Database Name</th><th>Size (MB)</th></tr>"


foreach ($row in $results.DatabaseSize) {
$html += "<tr>"
    $html += "<td align='Left'><font face='Verdana' size='4' color='#9933FF'> $($row.DatabaseName)</td>"
    $html += "<td align='Left'><font face='Verdana' size='4' color='#9933FF'> $($row.SizeMB)</td>"
   
   ## $databaseName = $row.DatabaseName
   # $sizeMB = $row.SizeMB
    
   # $html += "<tr><td>$databaseName</td><td>$sizeMB</td></tr>"
   $html += "</tr>"
}
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
}


  else
    {
        $ServersNotReachable += $_ 
        Write-Host "The server(s) below is/are not reachable..." -ForegroundColor Red
        $ServersNotReachable
        
    }
}
}
