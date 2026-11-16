<#
Pruebas E para la instancia local nutrianimales-e en Docker Desktop.
No arranca servicios, cambia contrasenas ni elimina volumenes.
Los SQL se ejecutan como postgres para consultar catalogos y hacer SET LOCAL ROLE.
Autenticacion abre conexiones reales como las tres cuentas, con TLS verify-full.
#>
[CmdletBinding()]
param(
    [ValidateSet('Diagnostico','Permisos','Pruebas','Autenticacion','Todos')]
    [string]$Paso = 'Pruebas'
)

# Detener errores de PowerShell; los codigos nativos se comprueban explicitamente.
$ErrorActionPreference = 'Stop'
$repoE = Split-Path -Parent $PSScriptRoot
$composeE = @('compose','-p','nutrianimales-e','-f','compose.yaml','-f','compose.parte-e.windows.yaml')
foreach ($necesarioE in @('compose.yaml','compose.parte-e.windows.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoE $necesarioE))) {
        throw ('Falta el archivo requerido: ' + $necesarioE)
    }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker no esta disponible en esta terminal.'
}

# Guardar evidencia real en la carpeta de E, fuera del patron ignorado evidencias/*.
$evidenciasE = Join-Path $PSScriptRoot 'evidencias'
$temporalE = Join-Path $repoE '.runtime/parte-e'
New-Item -ItemType Directory -Force -Path $evidenciasE,$temporalE | Out-Null
$marcaE = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$registroE = Join-Path $evidenciasE ($marcaE + '-' + $Paso + '.txt')
@(
    'PARTE E | Grupo 3 | NutriAnimales S.A.',
    ('Instante local con zona: ' + [DateTimeOffset]::Now.ToString('o')),
    'Instancia Compose: nutrianimales-e; servicio: postgres',
    ('Paso solicitado: ' + $Paso),
    'Alcance: instancia local del integrante E; no certifica el servidor de otro integrante.'
) | Set-Content -LiteralPath $registroE -Encoding UTF8

# Capturar tambien stderr: psql usa ese canal para NOTICE de rechazos esperados.
# Convertir la salida en texto evita que PowerShell 5.1 presente NOTICE como fallo.
function Invoke-DockerE {
    param([string[]]$ArgumentosE)
    $preferenciaE = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $salidaE = @(& docker @composeE @ArgumentosE 2>&1)
        $codigoE = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $preferenciaE
    }
    $salidaE | ForEach-Object { $_.ToString() } |
        Tee-Object -FilePath $registroE -Append
    if ($codigoE -ne 0) {
        throw ('Comando detenido con codigo ' + $codigoE + '. Revisar ' + $registroE)
    }
}

# Lista fija de archivos: ningun valor de credencial entra al comando de PowerShell.
$archivosE = @{
    'Diagnostico' = 'sql/01_diagnostico.sql'
    'Permisos' = 'sql/02_matriz_permisos.sql'
    'Pruebas' = 'sql/03_pruebas_rbac.sql'
    'Autenticacion' = 'scripts/04_autenticacion_tls.sh'
}
$pasosE = @($Paso)
if ($Paso -eq 'Todos') {
    $pasosE = @('Diagnostico','Permisos','Pruebas','Autenticacion')
}

# Fijar el directorio para resolver ambos YAML y .env de la instancia correcta.
Push-Location $repoE
try {
    Invoke-DockerE -ArgumentosE @('exec','-T','postgres','pg_isready','-h','127.0.0.1','-U','postgres','-d','nutrianimales')
    foreach ($actualE in $pasosE) {
        $origenE = Join-Path $PSScriptRoot $archivosE[$actualE]
        $nombreE = Split-Path -Leaf $origenE
        $copiaE = Join-Path $temporalE $nombreE
        # LF hace reproducible la copia incluso si Git convierte el checkout a CRLF.
        $textoE = [IO.File]::ReadAllText($origenE).Replace("`r`n", "`n")
        [IO.File]::WriteAllText($copiaE, $textoE, [Text.UTF8Encoding]::new($false))
        $hashE = (Get-FileHash -LiteralPath $copiaE -Algorithm SHA256).Hash
        ('PASO ' + $actualE + ' | SHA256 del archivo ejecutado: ' + $hashE) |
            Tee-Object -FilePath $registroE -Append
        $destinoE = '/tmp/parte-e-' + $nombreE
        Invoke-DockerE -ArgumentosE @('cp',$copiaE,('postgres:' + $destinoE))
        if ($actualE -eq 'Autenticacion') {
            Invoke-DockerE -ArgumentosE @('exec','-T','postgres','bash',$destinoE)
        } else {
            Invoke-DockerE -ArgumentosE @('exec','-T','postgres','psql','-X','-U','postgres','-d','nutrianimales','-v','ON_ERROR_STOP=1','-f',$destinoE)
        }
    }
    ('FIN: ' + $Paso + ' termino sin error de ejecucion.') |
        Tee-Object -FilePath $registroE -Append
    Write-Host ('Evidencia guardada en: ' + $registroE)
} finally {
    Pop-Location
}
