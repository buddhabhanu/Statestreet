#CSS codes


param
(
    [parameter(Mandatory = $true)]
    [Alias("Primary", "source")]
    [string] $Source_Server ,
    [parameter(Mandatory = $true)]
    [Alias("Secondary", "DR")]
    [string] $DR_server,
     [parameter(Mandatory = $false)]
    [Alias("Alias_name", "SQLName")]
    [string] $SQLAlias_port

) 
$header = @"
<style>

    h1 {

        font-family: Arial, Helvetica, sans-serif;
        color: #e68a00;
        font-size: 28px;

    }

    
    h2 {

        font-family: Arial, Helvetica, sans-serif;
        color: #000099;
        font-size: 16px;

    }

    
    
   table {
		font-size: 12px;
		border: 0px; 
		font-family: Arial, Helvetica, sans-serif;
	} 
	
    td {
		padding: 4px;
		margin: 0px;
		border: 0;
	}
	
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
	}

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }
    


    #CreationDate {

        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 12px;

    }



    .StopStatus {

        color: #ff0000;
    }
    
  
    .RunningStatus {

        color: #008000;
    }




</style>
"@

#The command below will get the name of the computer



#$Source_Server='WIN-32IAC88N7JB'

#$DR_server='WIN-32IAC88N7JB'

$Heading="<h1>DR Test validation Automation For SQL </h1>"

$ComputerName = "<h2>Source Server name: $Source_server</h2>", "<h2>DR Server name: $DR_server</h2>"

#The command below will get the Operating System information, convert the result to HTML code as table and store it to a variable
$OSinfo = Get-CimInstance -Class Win32_OperatingSystem -ComputerName $Source_Server,$DR_server | ConvertTo-Html -Property @{Label="Server_Name"; Expression={$_.csname }} ,@{Label="ServerPatch_version"; Expression={$_.Version }} , @{Label="OS_Name"; Expression={$_.Caption }} ,LastBootUpTime -Fragment -PreContent "<h3>Operating System Information</h3>"


#The command below will get the Processor information, convert the result to HTML code as table and store it to a variable
$ProcessInfo =Get-CimInstance Win32_ComputerSystem -ComputerName $Source_Server,$DR_server |ConvertTo-Html  @{Label="Server_Name"; Expression={$_.DNSHostname }} ,@{Label="System_Processors_Count"; Expression={$_.NumberOfLogicalProcessors}},@{Label="System_Memory(GB)"; Expression={$_.totalphysicalmemory/1024/1024/1024 -as [int]}} -Fragment -PreContent  "<h2>Hardware Information</h2>"

#$ProcessInfo = Get-CimInstance -ClassName Win32_Processor -ComputerName $Source_Server,$DR_server | ConvertTo-Html  -Property ComputerName,DeviceID,Name,Caption,MaxClockSpeed,SocketDesignation,Manufacturer -Fragment -PreContent "<h2>Processor Information</h2>"

#The command below will get the BIOS information, convert the result to HTML code as table and store it to a variable
$BiosInfo = Get-CimInstance -ClassName Win32_BIOS | ConvertTo-Html -Property SMBIOSBIOSVersion,Manufacturer,Name,SerialNumber -Fragment -PreContent "<h2>BIOS Information</h2>"

#The command below will get the details of Local Admins list, convert the result to HTML code as table and store it to a variable
$localadmin=Get-LocalGroupMember -Group "Administrators" | ConvertTo-Html -Property name,PrincipalSource, Objectclass "<h2>Local Adminstrators Information</h2>"
$localadmin= $localadmin -replace '<td>ActiveDirectory</td>','<td class="RunningStatus">ActiveDirectory</td>'

#The command below will get the details of Disk, convert the result to HTML code as table and store it to a variable
$DiscInfo = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $Source_Server -Filter "DriveType=3" | ConvertTo-Html -As table -Property @{Label="Server_Name"; Expression={$_.PSComputerName }},@{Label="Drive_Name"; Expression={$_.DeviceID }},@{Label="Total_Space(GB)"; Expression={[Math]::Ceiling($_.Size /1024/1024/1024 )}},@{Label="Free_Space(GB)"; Expression={[Math]::Ceiling($_.FreeSpace /1024/1024/1024 )}}  -Fragment -PreContent  "<h2>Disk Information</h2>"

#The command below will get first 10 services information, convert the result to HTML code as table and store it to a variable
$ServicesInfo = Get-CimInstance -ClassName Win32_Service -ComputerName $Source_Server,$DR_server |Where-Object {
    $_.Name -like "*MSSQL*" -or $_.Name -like "*ServerAGENT*"-and $_.Name -notlike "*Launcher*" } | ConvertTo-Html -Property @{Label="Server_Name"; Expression={$_.systemname}},@{Label="SQL_Service_Name"; Expression={$_.name}},@{Label="Service_Details"; Expression={$_.Displayname}} ,@{Label="Service_Status"; Expression={$_.state}}   -Fragment -PreContent "<h2>Services Information</h2>"

$ServicesInfo = $ServicesInfo -replace '<td>Running</td>','<td class="RunningStatus">Running</td>'
$ServicesInfo = $ServicesInfo -replace '<td>Stopped</td>','<td class="StopStatus">Stopped</td>'

#$SQLPatchInfo =Invoke-Sqlcmd -query "select @@servername as 'Server_Name',@@version as 'SQL_Version_Name' ,SERVERPROPERTY('productversion') as 'SQL_Version_ID', SERVERPROPERTY('ProductUpdateLevel') as 'CU_Name' " -ServerInstance $SQLAlias_port | ConvertTo-Html Server_Name,SQL_Version_Name,SQL_version_ID , CU_Name -Fragment -PreContent "<h2>Services Information</h2>"

  
#The command below will combine all the information gathered into a single HTML report
$Report = ConvertTo-HTML -Body "$Heading $ComputerName $OSinfo $ProcessInfo  $localadmin $DiscInfo $ServicesInfo " -Head $header -Title "Computer Information Report" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p>"

#The command below will generate the report to an HTML file

$htmlFilePath = "C:\Temp\Computer_information-Report-"+$Source_Server+"_"+$DR_Server+".html"
$Report | Out-File $htmlFilePath
