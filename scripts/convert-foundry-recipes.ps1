# convert-foundry-recipes.ps1
#
# Need yaml module
# Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
#
# Use a Unity Asset Extractor to dump game assets, recipes come out in Foundry\Assets\Resources\data\craftingrecipes

#(Get-Content '.\EIC1; Electronic Components.asset' | cfy).Values | ConvertTo-Json
mkdir -force json

$parsedata = Get-ChildItem -Recurse *.asset
$rawarr = [System.Collections.Generic.List[object]]::new()
$namesarr = [System.Collections.Generic.List[object]]::new()
$catarr = [System.Collections.Generic.List[object]]::new()
$macharr = [System.Collections.Generic.List[object]]::new()
$recarr = [System.Collections.Generic.List[object]]::new()
$rowarr = [System.Collections.Generic.List[object]]::new()

function ConvertSingleObjectToArrayIfNeeded {
  param (
    $inObj
  )
  $temp = [System.Collections.Generic.List[object]]::new()
  if($null -eq $inObj) {
    return $temp
  } else {
    if($inObj.GetType().Name -eq "Hashtable") {
      $temp.Add((,$inObj))
    } else {
      $temp.AddRange($inObj)
    }
    return $temp
  }
}

$i = 0
$max = $parsedata.Count
Foreach($pd in $parsedata) {
  $obj = [PSCustomObject]@{}
  $val = (Get-Content $pd | ConvertFrom-yaml).Values
  $val.Keys | ForEach-Object {
    $obj | Add-Member $_ $val.item($_)
  }
  $rawarr.Add($obj)

  $namesarr.Add($obj.name)
  if(-Not $catarr.Contains($obj.category_identifier)) {
    $catarr.Add($obj.category_identifier)
  }
  if(-Not $rowarr.Contains($obj.rowGroup_identifier)) {
    $rowarr.Add($obj.rowGroup_identifier)
  }
  if($obj.category_identifier -eq "_base_buildings") {
    $macharr.Add($obj.name)
  }

  $rec = [PSCustomObject]@{}
  $rec | Add-Member id $obj.identifier
  $rec | Add-Member name $obj.name
  $rec | Add-Member time ($obj.timeMS / 1000)
  $rec | Add-Member producers $obj.tags
  $rec | Add-Member category $obj.category_identifier
  $rec | Add-Member rowID $obj.rowGroup_identifier

  #Need to combine input solids and input liquids
  $inarr = [System.Collections.Generic.List[object]]::new()
  if($null -ne $obj.input_data) {$inarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.input_data))}
  if($null -ne $obj.inputElemental_data) {$inarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.inputElemental_data))}
  $iput = [PSCustomObject]@{}
  Foreach($inn in $inarr) {
    if($null -eq $inn.amount) {
      $inn | Add-Member amount $inn.amount_str
    }
    $iput | Add-Member $inn.identifier $inn.amount
  }

  $outarr = [System.Collections.Generic.List[object]]::new()
  if($null -ne $obj.output_data) {$outarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.output_data))}
  if($null -ne $obj.outputElemental_data) {$outarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.outputElemental_data))}
  $output = [PSCustomObject]@{}
  Foreach($outt in $outarr) {
    if($null -eq $outt.amount) {
      $outt | Add-Member amount 1
    }
    $output | Add-Member $outt.identifier $outt.amount
  }
  $rec | Add-Member "in" $iput
  $rec | Add-Member "out" $output
  $recarr.Add($rec)

  # $name = (Split-Path $pd -leaf).replace(".asset","")
  # $obj | ConvertTo-Json -Depth 6| Set-Content -Path "json/$name.json"
  $i+=1
  Write-Host "$i/$max"
}
$rawarr | ConvertTo-Json -Depth 6 | Set-Content -Path "json/raw.json"

$catobjs = [System.Collections.Generic.List[object]]::new()
Foreach($c in $catarr) {
  $o = [PSCustomObject]@{}
  $o | Add-Member id $c
  $o | Add-Member name (Get-Culture).TextInfo.ToTitleCase($c.replace("_base_","").replace("_"," "))
  $catobjs.Add($o)
}

Foreach($rec in $recarr) {
  $rec | Add-Member row $rowarr.IndexOf($rec.rowID)
  $rec.PSObject.Properties.Remove("rowID")
}

$data = [PSCustomObject]@{}
$version = [PSCustomObject]@{"Foundry" = "0.4.3.4462"}
$data | Add-Member "version" $version
$data | Add-Member "categories" $catobjs
$data | Add-Member "recipes" $recarr
# $data | Add-Member
$data | ConvertTo-Json -Depth 6 | Set-Content -Path "json/data.json"
