# Copia do servidor para a pasta lib as bibliotecas do Primavera de que o projecto precisa.
# Executar no PC de desenvolvimento:  powershell -ExecutionPolicy Bypass -File .\copiar-bibliotecas.ps1 -Origem "\\SERVIDOR\c$\Program Files\PRIMAVERA\SG100\Apl"
param([Parameter(Mandatory=$true)][string]$Origem)
$Destino = Join-Path $PSScriptRoot "lib"
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
$Padrao = '^(Primavera\.Extensibility\..+|I?StdPlatB[ES]100|StdBE100|ErpBS100|I?CctB[ES]100)\.dll$'
$Dlls = Get-ChildItem $Origem -Filter *.dll | Where-Object { $_.Name -match $Padrao }
$Dlls | Copy-Item -Destination $Destino -Force
Write-Host ("Copiadas " + $Dlls.Count + " bibliotecas para " + $Destino) -ForegroundColor Green
