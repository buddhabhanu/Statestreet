param
(
    [parameter(Mandatory = $true)]
    [Alias("HostName", "SeverName")]
    [string[]] $ComputerName ,
    [parameter(Mandatory = $false)]
    [Alias("DriveName", "MountName")]
    [string] $DiskName
)
$ServersNotReachable = @()

$ComputerName | ForEach-Object {

$count =Test-Connection $_ -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($true -eq $count)
  {  
     if($null -eq $DiskName)
{
$data=Get-CimInstance -ClassName Win32_Volume -ComputerName $_ | Where-Object {$_.Drivetype -eq 3} | sort-object Freespace -Descending
} 
else
{
$data=Get-CimInstance -ClassName Win32_Volume -ComputerName $_ | Where-Object {$_.Drivetype -eq 3 -and $_.Caption -like "*$DiskName*"} | sort-object Freespace -Descending
}

      foreach($disk in $data)
{
         
    $size= [math]::round($disk.Capacity/1GB,2)
    $FreeSpace= [math]::round($disk.FreeSpace/1GB,2) 
    $FreePercent =[math]::round([double]$Disk.FreeSpace / [double] $Disk.Capacity * 100,2)
    
    
   [PScustomobject]@{
    NodeName= $Disk.SystemName
    SQLInstance=$Disk.PSComputerName
    MountName = $Disk.Caption
    BlockSize = $Disk.BlockSize
    Drivetype = $Disk.Drivetype
    "TotalDisk(GB)" =  $Size
    "FreeSpace(GB)" = $FreeSpace
    "FreePercent(%)" =Write-Output "    $FreePercent %"
     DiskLabel= $Disk.Label
    Filesystem= $disk.FileSystem
   }
        
}

   } 
   
else
    {
        $ServersNotReachable += $_ 
    }
} | format-table

$Statuscount =Test-Connection $ComputerName  -ErrorAction SilentlyContinue | Measure-Object

 if ($Statuscount -eq 0 )
{
Write-Host "The server(s) below is/are not reachable..." -ForegroundColor Red
$ServersNotReachable
}