<#
.SYNOPSIS
    Gestor y Instalador Automatico para LLM-Eval-Framework con Menu Interactivo.
#>

$ErrorActionPreference = "Stop"
$envName = "llm-eval-framework-env"
$venvDir = ".\$envName"

# FUNCION PRINCIPAL DE INSTALACION
function Install-Framework {
    param([bool]$Reinstall = $false)

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "        INICIANDO PROCESO DE INSTALACION: LLM-EVAL-FRAMEWORK" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    if ($Reinstall) {
        Write-Host "`n[!] MODO REINSTALACION: Borrando entorno virtual anterior..." -ForegroundColor Red
        if (Test-Path $venvDir) {
            Remove-Item -Recurse -Force $venvDir
            Write-Host "✔ Entorno anterior eliminado con exito." -ForegroundColor Green
        }
    }

    # PASO 1: Verificar Python Activo
    Write-Host "`n[1/5] Verificando entorno de Python..." -ForegroundColor Yellow
    $pythonInstalled = $false

    try {
        $pyVersion = python --version 2>$null
        Write-Host "Python detectado en el sistema: $pyVersion" -ForegroundColor Green
        $pythonInstalled = $true
    } catch {
        Write-Host "Python no esta instalado o no se encuentra en el PATH." -ForegroundColor Red
    }

    if (-not $pythonInstalled) {
        Write-Host "Descargando e instalando la ultima version de Python (Winget)..." -ForegroundColor Cyan
        winget install --id Python.Python.3 --exact --silent --accept-source-agreements --accept-package-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        if (Get-Command python -ErrorAction SilentlyContinue) {
            Write-Host "Python instalado con exito." -ForegroundColor Green
        } else {
            Write-Host "Error critico: No se pudo verificar Python en el PATH." -ForegroundColor Red
            Exit 1
        }
    }

    # PASO 2: Gestionar Entorno Virtual Personalizado
    Write-Host "`n[2/5] Gestionando Entorno Virtual Personalizado..." -ForegroundColor Yellow

    if (-not (Test-Path $venvDir)) {
        Write-Host "📦 Creando entorno virtual aislado [$envName]..." -ForegroundColor Cyan
        python -m venv $envName
        Write-Host "✔ Entorno virtual creado con exito." -ForegroundColor Green
    } else {
        Write-Host "✔ El entorno virtual [$envName] ya existe. Saltando creacion..." -ForegroundColor Green
    }

    Write-Host "🔌 Activando el entorno virtual temporalmente para la instalacion..." -ForegroundColor Cyan
    & ".\$envName\Scripts\Activate.ps1"
    Write-Host "✔ Entorno virtual [$envName] ACTIVO." -ForegroundColor Green

    # PASO 3: Configurar Archivo de Entorno (.env)
    Write-Host "`n[3/5] Verificando variables de entorno (.env)..." -ForegroundColor Yellow
    $envFile = ".\.env"

    if (-not (Test-Path $envFile)) {
        Write-Host "Archivo .env no detectado. Creando plantilla inicial..." -ForegroundColor Magenta
        $template = @"
# Configuracion de API Keys para OpenRouter
OPENROUTER_API_KEY_A="TU_API_KEY_A_AQUI"
OPENROUTER_API_KEY_B="TU_API_KEY_B_AQUI"
"@
        Out-File -FilePath $envFile -InputObject $template -Encoding utf8
        Write-Host "Archivo .env generado en la raiz." -ForegroundColor Green
    } else {
        Write-Host "Archivo .env existente detectado." -ForegroundColor Green
    }

    # PASO 4: Instalar Dependencias DENTRO del venv
    Write-Host "`n[4/5] Instalando dependencias en el entorno aislado..." -ForegroundColor Yellow
    if (Test-Path ".\requirements.txt") {
        python -m pip install --upgrade pip
        python -m pip install -r requirements.txt
        Write-Host "Dependencias instaladas/actualizadas dentro de [$envName]." -ForegroundColor Green
    } else {
        Write-Host "Error: No se encontro el archivo requirements.txt." -ForegroundColor Red
        Exit 1
    }

    # PASO 5: Validacion Mediante Smoke Test
    Write-Host "`n[5/5] Ejecutando Smoke Test de validacion..." -ForegroundColor Yellow

    $envContent = Get-Content $envFile -Raw
    if ($envContent -match "TU_API_KEY") {
        Write-Host "Saltando Smoke Test real: Edita el archivo .env con tus llaves reales para probar la conectividad." -ForegroundColor Magenta
        Write-Host "Inicializacion exitosa. El entorno [$envName] quedo listo para usar." -ForegroundColor Green
    } else {
        Write-Host "Ejecutando pruebas de humo de conectividad dentro de [$envName]..." -ForegroundColor Cyan
        pytest tests/test_medical_bot.py -k "smoke" -v -s --tb=short
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n[EXITO] El proyecto quedo 100% operativo dentro de tu venv." -ForegroundColor Green
        } else {
            Write-Host "`nEl framework se configuro, pero el Smoke Test fallo. Revisa tus API Keys." -ForegroundColor Red
        }
    }

    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host "      FIN DEL PROCESO DE INSTALACION" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    
    Write-Host "`nPresiona cualquier tecla para volver al menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# BUCLE DEL MENU PRINCIPAL
$menuActivo = $true

while ($menuActivo) {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "        GESTOR LLM-EVAL-FRAMEWORK" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "1- Instalar todo (Validar Python, venv, y dependencias)"
    Write-Host "2- Activar venv (Abre una terminal interactiva)"
    Write-Host "3- Reinstalar todo (Borra el venv desde cero)"
    Write-Host "4- Ejecutar TODA la Suite de Pruebas"
    Write-Host "5- Ejecutar SOLO el Smoke Test (Prueba Rapida)"
    Write-Host "6- Salir"
    Write-Host "======================================================================" -ForegroundColor Cyan
    
    $opcion = Read-Host "`nElige una opcion (1-6)"

    switch ($opcion) {
        "1" {
            Install-Framework -Reinstall $false
        }
        "2" {
            if (Test-Path $venvDir) {
                Write-Host "`nAbriendo una nueva sesion con el entorno virtual activado..." -ForegroundColor Green
                Write-Host "Para salir del entorno virtual, simplemente escribe 'exit'." -ForegroundColor Yellow
                powershell.exe -NoExit -Command "& '.\$envName\Scripts\Activate.ps1'"
            } else {
                Write-Host "`nEl entorno virtual no existe. Por favor, selecciona la opcion 1 primero." -ForegroundColor Red
                Write-Host "Presiona cualquier tecla para continuar..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        "3" {
            $confirmacion = Read-Host "`n¿Estas seguro de borrar y reinstalar todo el entorno virtual? (S/N)"
            if ($confirmacion -match "^[Ss]$") {
                Install-Framework -Reinstall $true
            }
        }
        "4" {
            if (-not (Test-Path $venvDir)) {
                Write-Host "`n[!] El entorno virtual no existe. Instala el framework primero (Opcion 1)." -ForegroundColor Red
                Start-Sleep -Seconds 2
            } else {
                Write-Host "`nEjecutando TODA la Suite de Pruebas..." -ForegroundColor Cyan
                powershell.exe -Command "& '.\$envName\Scripts\Activate.ps1'; pytest tests/ -v -s --tb=short"
                Write-Host "`nPresiona cualquier tecla para volver al menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        "5" {
            if (-not (Test-Path $venvDir)) {
                Write-Host "`n[!] El entorno virtual no existe. Instala el framework primero (Opcion 1)." -ForegroundColor Red
                Start-Sleep -Seconds 2
            } else {
                Write-Host "`nEjecutando Smoke Test..." -ForegroundColor Cyan
                powershell.exe -Command "& '.\$envName\Scripts\Activate.ps1'; pytest tests/test_medical_bot.py -k 'smoke' -v -s --tb=short"
                Write-Host "`nPresiona cualquier tecla para volver al menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        "6" {
            $menuActivo = $false
            Write-Host "`nSaliendo del gestor..." -ForegroundColor Green
        }
        default {
            Write-Host "`nOpcion invalida. Intenta nuevamente con un numero del 1 al 6." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}