$data = Get-Content foundry.atlas #| ConvertFrom-String

$darr = [System.Collections.Generic.List[object]]::new()
$darr.AddRange($data)
$out = [System.Collections.Generic.List[object]]::new()
$item = [PSCustomObject]@{}

if($darr.Contains("foundry.png")){
  $darr.RemoveAt(0);
}

$sizeX = 0
$sizeY = 0
if($darr[0].Contains("size:")) {
  $d = $darr[0] | ConvertFrom-String
  $sizeX = $d.P3
  $sizeY = $d.P4
  $darr.RemoveAt(0);
}
if($darr[0].Contains("repeat:")) {
  $darr.RemoveAt(0);
}

foreach($d in $darr) {
  if($d.Contains("bounds:")) {
    if($null -eq $item.position) {
      $split = $d | ConvertFrom-String
      $str = (($split.P3 - $sizeX)*-1).ToString()
      $str += "px "+(($split.P4 - $sizeY)*-1).ToString()+"px"
      $item | Add-Member position $str
    }
  } elseif($d.Contains("index:")) {
    # $idx = $d.split(":")[1].Trim()
    # $item.id += "-$idx"
  } else {
      # Write-Host "Duplicate entry for $item.name"
      if($null -ne $item.id) {
        $out.Add($item)
      }
      $item = [PSCustomObject]@{}
      $item | Add-Member id $d.ToString().replace(" ","_").replace("-64","").ToLowerInvariant().Trim()
  }
}

$out.Add($item)

$out | ConvertTo-Json -Depth 6 | Set-Content -Force -Path "icons.json"
