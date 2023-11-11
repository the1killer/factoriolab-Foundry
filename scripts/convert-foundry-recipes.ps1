# convert-foundry-recipes.ps1
#
# Need yaml module
# Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
#
# Use a Unity Asset Extractor to dump game assets, recipes come out in Foundry\Assets\Resources\data\craftingrecipes

#(Get-Content '.\EIC1; Electronic Components.asset' | cfy).Values | ConvertTo-Json
mkdir -force json > $null

$parsedata = Get-ChildItem -Recurse *.asset
$rawarr = [System.Collections.Generic.List[object]]::new()
$idarr = [System.Collections.Generic.List[object]]::new()
$catarr = [System.Collections.Generic.List[object]]::new()
$macharr = [System.Collections.Generic.List[object]]::new()
$recarr = [System.Collections.Generic.List[object]]::new()
$rowarr = [System.Collections.Generic.List[object]]::new()
$itemarr = [System.Collections.Generic.List[object]]::new()

$icons = Get-Content 'json/icons.json' | ConvertFrom-Json | ToArray
$iconNames = $icons | Select-Object id | foreach {$_.id}

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

function ToArray
{
  begin
  {
    $output = @();
  }
  process
  {
    $output += $_;
  }
  end
  {
    return ,$output;
  }
}

function ReplaceTagWithMachines {
  param (
    [object]$inObj,
    [string]$key,
    [object]$replace
  )

  $arr = [System.Collections.Generic.List[object]]::new()
  $arr.AddRange(($inObj.where{$_ -ne $key} | ToArray))
  $arr.AddRange(($replace | ToArray))
  return $arr
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

  $idarr.Add($obj.identifier)
  if(-Not $catarr.Contains($obj.category_identifier)) {
    $catarr.Add($obj.category_identifier)
  }
  if(-Not $rowarr.Contains($obj.rowGroup_identifier)) {
    $rowarr.Add($obj.rowGroup_identifier)
  }
  if($obj.category_identifier -eq "_base_buildings") {
    $macharr.Add($obj.name)
  }

  $item = [PSCustomObject]@{}
  $item | Add-Member id $obj.identifier
  $item | Add-Member name $obj.name
  $item | Add-Member category $obj.category_identifier
  $item | Add-Member rowID $obj.rowGroup_identifier
  if($iconNames.Contains($obj.icon_identifier)) {
    $item | Add-Member icon $obj.icon_identifier
  } else {
    # $rec | Add-Member icon "icon"
    $item | Add-Member icon "icon"
  }
  $machine = [PSCustomObject]@{}
  $machine | Add-Member speed 1
  $item | Add-Member machine $machine

  $itemarr.Add($item)

  #region morph producer tags to actual machines
  #need to automate this based on data if possible
  $producers = [System.Collections.Generic.List[object]]::new()
  $producers.AddRange(($obj.tags.where{$_ -ne "character"} | ToArray))
  if($producers.Contains("assembler")) {
    $producers = ReplaceTagWithMachines $producers "assembler" @("_base_assembler_i","_base_assembler_ii","_base_assembler_iii")
  }
  if($producers.Contains("chemical_processor")) {
    $producers = ReplaceTagWithMachines $producers "chemical_processor" ("_base_chemical_processor_i" | ToArray)
  }
  if($producers.Contains("induction_smelter")) {
    $producers = ReplaceTagWithMachines $producers "induction_smelter" ("_base_induction_smelter_i" | ToArray)
  }
  if($producers.Contains("crusher")) {
    $producers = ReplaceTagWithMachines $producers "crusher" @("_base_crusher_i","_base_crusher_ii")
  }
  if($producers.Contains("casting_machine")) {
    $producers = ReplaceTagWithMachines $producers "casting_machine" ("_base_casting_machine" | ToArray)
  }
  if($producers.Contains("thermal_separator")) {
    $producers = ReplaceTagWithMachines $producers "thermal_separator" ("_base_thermal_separator_i" | ToArray)
  }
  if($producers.Contains("primitive_furnace")) {
    $producers = ReplaceTagWithMachines $producers "primitive_furnace" ("_base_primitive_furnace" | ToArray)
  }
  if($producers.Contains("smelter")) {
    $producers = ReplaceTagWithMachines $producers "smelter" ("_base_smelter_i" | ToArray)
  }
  #endregion


  $rec = [PSCustomObject]@{}
  $rec | Add-Member id $obj.identifier
  $rec | Add-Member name $obj.name
  $rec | Add-Member time ($obj.timeMS / 1000)
  $rec | Add-Member producers ($producers | ToArray)
  $rec | Add-Member category $obj.category_identifier
  $rec | Add-Member rowID $obj.rowGroup_identifier
  $iname = $obj.name.ToLowerInvariant().replace(" ","_")
  if($iconNames.Contains($obj.icon_identifier)) {
    $rec | Add-Member icon $obj.icon_identifier
  } else {
    # $rec | Add-Member icon "icon"
    $rec | Add-Member icon "icon"
  }


  #Need to combine input solids and input liquids
  $inarr = [System.Collections.Generic.List[object]]::new()
  if($null -ne $obj.input_data) {$inarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.input_data))}
  if($null -ne $obj.inputElemental_data) {$inarr.AddRange((ConvertSingleObjectToArrayIfNeeded $obj.inputElemental_data))}
  $iput = [PSCustomObject]@{}
  Foreach($inn in $inarr) {
    if($null -eq $inn.amount) {
      $inn | Add-Member amount $inn.amount_str
    }
    #region errors in game data?
    if($inn.identifier -eq "_base_conveyor_iI") {
      $inn.identifier = "_base_conveyor_ii"
    }
    #endregion
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
    #region errors in game data?
    if($outt.identifier -eq "_base_biomass_burner") {
      $outt.identifier = "_base_biomass_generator"
    }
    if($outt.identifier -eq "_base_chest") {
      $outt.identifier = "_base_crate"
    }
    if($outt.identifier -eq "_base_pipe_loader_i") {
      $outt.identifier = "_base_loader_pipes"
    }
    if($outt.identifier -eq "_base_stairs_straight") {
      $outt.identifier = "_base_stairs"
    }
    if($outt.identifier -eq "_base_tank_i") {
      $outt.identifier = "_base_tank"
    }
    if($outt.identifier -eq "_base_power_line_i") {
      $outt.identifier = "_base_power_line"
    }
    #endregion
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
  $o | Add-Member icon "icon"
  $catobjs.Add($o)
}

#region Add missing base items
$item = [PSCustomObject]@{}
$item | Add-Member id "_base_xenoferrite_plates"
$item | Add-Member name "Xenoferrite Plates"
$item | Add-Member category "_base_metallurgy"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "xf_plate"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_technum_rods"
$item | Add-Member name "Technum Rods"
$item | Add-Member category "_base_metallurgy"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "rods"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_bf_slag"
$item | Add-Member name "Slag"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_components_concrete"
$item | Add-Member icon "slag"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_ore_limestone"
$item | Add-Member name "Limestone Ore"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_components_concrete"
$item | Add-Member producers ("_base_rail_miner_rock" | ToArray)
$item | Add-Member icon "limestone"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_stone"
$item | Add-Member name "Stone"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_components_concrete"
$item | Add-Member producers ("_base_rail_miner_rock" | ToArray)
$item | Add-Member icon "stone"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_olumite"
$item | Add-Member name "Olumite"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_components_liquids"
$item | Add-Member icon "olumite"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_biomass"
$item | Add-Member name "Biomass"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_components_general"
$item | Add-Member icon "biomass"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_rubble_ignium"
$item | Add-Member name "Ignium Rubble"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member producers ("_base_rail_miner_i" | ToArray)
$item | Add-Member icon "ore_rubble_ignium"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_rubble_technum"
$item | Add-Member name "Technum Rubble"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member producers ("_base_rail_miner_ii" | ToArray)
$item | Add-Member icon "ore_rubble_technum"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_rubble_xenoferrite"
$item | Add-Member name "Xenoferrite Rubble"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member producers ("_base_rail_miner_ii" | ToArray)
$item | Add-Member icon "ore_rubble_xenoferrite"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_refined_ore_technum"
$item | Add-Member name "Refined Technum Ore"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "ore_technum_refined"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_refined_ore_xenoferrite"
$item | Add-Member name "Refined Xenoferrite Ore"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "ore_xenoferrite_refined"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_xenoferrite_ingots"
$item | Add-Member name "Xenoferrite Ingots"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "ingots_xenoferrite"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_technum_ingots"
$item | Add-Member name "Technum Ingots"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "ingots_technum"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_molten_xf"
$item | Add-Member name "Molten Xenoferrite"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "molten_xf"
$itemarr.Add($item)
$idarr.Add($item.id)

$item = [PSCustomObject]@{}
$item | Add-Member id "_base_molten_te"
$item | Add-Member name "Molten Technum"
$item | Add-Member category "_base_components"
$item | Add-Member rowID "_base_metallurgy_ores"
$item | Add-Member icon "molten_te"
$itemarr.Add($item)
$idarr.Add($item.id)

#endregion

Foreach($rec in $recarr) {
  $rec | Add-Member row $rowarr.IndexOf($rec.rowID)
  $rec.PSObject.Properties.Remove("rowID")
}

Foreach($it in $itemarr) {
  $it | Add-Member row $rowarr.IndexOf($it.rowID)
  $it.PSObject.Properties.Remove("rowID")
}

$data = [PSCustomObject]@{}
$version = [PSCustomObject]@{"Foundry" = "0.4.3.4462"}
$data | Add-Member "version" $version
$data | Add-Member "categories" $catobjs
$data | Add-Member "recipes" $recarr
$data | Add-Member "items" $itemarr

# $icons = [System.Collections.Generic.List[object]]::new()
# $tempico = [PSCustomObject]@{}
# $tempico | Add-Member "id" "tempicon"
# $tempico | Add-Member "position" "-0px -0px"
# $icons.Add($tempico);
$data | Add-Member "icons" $icons | ToArray

Write-Host "Writing json/data.json..."
$data | ConvertTo-Json -Depth 6 | Set-Content -Path "json/data.json"


$hash = [PSCustomObject]@{}
$hash | Add-member "items" $idarr
$hash | Add-member "machines" $macharr
$hash | Add-member "recipes" $idarr
#need to fetch these from items eventually
$belts = "_base_conveyor_i","_base_conveyor_ii","_base_conveyor_iii"
$hash | Add-member "belts" $belts
$fuels = "_base_ore_ignium","_base_ignium_fuel_rod"
$hash | Add-member "fuels" $fuels
Write-Host "Writing json/hash.json..."
# ($hash | ConvertTo-Json -Depth 6).replace("_base_","") | Set-Content -Path "json/hash.json"
$hash | ConvertTo-Json -Depth 6 | Set-Content -Path "json/hash.json"
