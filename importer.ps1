# Importe tous les tableaux de la suite « TeslaMate — à ma sauce » dans Grafana (Windows / PowerShell).
#
#   .\importer.ps1 -Url http://IP-DU-GRAFANA:3000 -Utilisateur admin -MotDePasse xxx
#   .\importer.ps1 -Url http://IP-DU-GRAFANA:3000 -Jeton glsa_xxxxxxxx
#   Ajoute -SourceUid MonUID si ta source de données n'a pas l'uid « TeslaMate ».
#
# À lancer depuis le dossier du dépôt (les .json sont dans « dashboards »).
param(
  [Parameter(Mandatory = $true)][string]$Url,
  [string]$Utilisateur, [string]$MotDePasse, [string]$Jeton,
  [string]$SourceUid = "TeslaMate"
)
$Url = $Url.TrimEnd('/')
if ($Jeton) { $headers = @{ Authorization = "Bearer $Jeton" } }
else {
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${Utilisateur}:${MotDePasse}"))
  $headers = @{ Authorization = "Basic $b64" }
}
$folderUid = "teslamate-a-ma-sauce"
try {
  Invoke-RestMethod -Method Post -Uri "$Url/api/folders" -Headers $headers -ContentType "application/json; charset=utf-8" `
    -Body ([Text.Encoding]::UTF8.GetBytes((@{ uid = $folderUid; title = "TeslaMate — à ma sauce" } | ConvertTo-Json))) | Out-Null
} catch { }
$ok = 0; $ko = 0
$dir = if (Test-Path (Join-Path $PSScriptRoot "dashboards")) { Join-Path $PSScriptRoot "dashboards" } else { $PSScriptRoot }
Get-ChildItem -Path $dir -Filter "*.json" | Where-Object { $_.Name -like "tms-*" -or $_.Name -eq "tm-energie-reelle.json" } | ForEach-Object {
  $json = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8).Replace('"uid": "TeslaMate"', "`"uid`": `"$SourceUid`"")
  $body = '{"dashboard":' + $json + ',"folderUid":"' + $folderUid + '","overwrite":true}'
  try {
    Invoke-RestMethod -Method Post -Uri "$Url/api/dashboards/db" -Headers $headers -ContentType "application/json; charset=utf-8" `
      -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    $ok++; Write-Host "  OK  $($_.Name)"
  } catch { $ko++; Write-Host "  ERREUR  $($_.Name) : $($_.Exception.Message)" }
}
Write-Host "Terminé : $ok importé(s), $ko en erreur. Ouvre $Url/d/tms-accueil"
