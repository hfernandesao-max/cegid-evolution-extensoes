# ============================================================
#  Compilação da extensão ADF / PO – Cegid Evolution ERP Primavera V10
#  Grupo Naval Angola – Projectos Digitais. CONFIDENCIAL.
#
#  Usa o compilador C# do .NET Framework do Windows (csc.exe).
#  Executar no servidor do Primavera, com o ERP fechado:
#    powershell -ExecutionPolicy Bypass -File C:\Naval\Extensoes\Compilar.ps1
# ============================================================

$Apl   = "C:\Program Files\PRIMAVERA\SG100\Apl"
$Pasta = "C:\Naval\Extensoes"
$Src   = Join-Path $Pasta "UiEditorPendentes.cs"
$Out   = Join-Path $Pasta "Naval.Extensibility.ContasCorrentes.dll"
$Csc   = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $Src)) { Write-Host "Falta o ficheiro $Src" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Csc)) { Write-Host "Compilador não encontrado: $Csc" -ForegroundColor Red; exit 1 }

$Padrao = '^(Primavera\.Extensibility\..+|I?StdPlatB[ES]100|StdBE100|ErpBS100|I?CctB[ES]100|BasBE100|IBasBS100)\.dll$'
$Dlls = Get-ChildItem $Apl -Filter *.dll | Where-Object { $_.Name -match $Padrao }
$Refs = $Dlls | ForEach-Object { '/r:"' + $_.FullName + '"' }
Write-Host ("Referências encontradas: " + $Dlls.Count) -ForegroundColor Cyan

# Tentativa 1: método de aviso actual (MostraMensagem)
$r1 = & $Csc /nologo /target:library /optimize+ /platform:anycpu /define:NOVA_API /out:"$Out" $Refs "$Src" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Compilado com sucesso (método MostraMensagem): $Out" -ForegroundColor Green
    exit 0
}

# Tentativa 2: método MostraAviso (aviso de obsoleto ocultado)
Write-Host "MostraMensagem não disponível nesta versão do SDK - a usar MostraAviso." -ForegroundColor Yellow
& $Csc /nologo /target:library /optimize+ /platform:anycpu /out:"$Out" $Refs "$Src"
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Compilado com sucesso (método MostraAviso): $Out" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Erros na compilação - ver a lista acima." -ForegroundColor Red
    Write-Host "Erros da tentativa com MostraMensagem (para referência):" -ForegroundColor DarkGray
    $r1 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
}
