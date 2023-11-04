# convert-foundry-recipes.ps1
#
# Need yaml module
# Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
#
# Use a Unity Asset Extractor to dump game assets, recipes come out in Foundry\Assets\Resources\data\craftingrecipes

#(Get-Content '.\EIC1; Electronic Components.asset' | cfy).Values | ConvertTo-Json
mkdir json
[System.Collections.ArrayList]$arr = @()
Foreach($item in Get-ChildItem -Recurse *.asset) {
  $name = (Split-Path $item -leaf).replace(".asset","");
  $obj = (Get-Content $item | ConvertFrom-yaml).Values
  $obj.remove("m_CorrespondingSourceObject")
  $obj.remove("tagHashes")
  $obj.remove("m_EditorHideFlags")
  $obj.remove("m_PrefabInstance")
  $obj.remove("m_EditorClassIdentifier")
  $obj.remove("m_Script")
  $obj.remove("hideInCraftingFrame")
  $obj.remove("modId")
  $obj.remove("m_GameObject")
  $obj.remove("relatedResearchTemplate")
  # $obj.remove("m_CorrespondingSourceObject")
  $arr.Add($obj)
  $obj | ConvertTo-Json -Depth 6| Set-Content -Path "json/$name.json"
}
$arr | ConvertTo-Json -Depth 6 | Set-Content -Path "json/recpies.json"
