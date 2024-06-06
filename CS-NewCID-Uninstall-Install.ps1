# Defina variáveis
$InstallerPath = "C:\temp\WindowsSensor.exe"
$FullCorrectCID = "newCID-E2"
$CorrectCID = $FullCorrectCID -replace "-E2", ""
$MaintenanceToken1 = "token1"
$MaintenanceToken2 = "token2"
$MaintenanceToken3 = "token3"

$TempDir = "C:\temp"
$UninstallToolPath = "$TempDir\CsUninstallTool.exe"

# Criar diretório temporário, se não existir
if (-not (Test-Path -Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir
}

# Baixar a ferramenta de desinstalação
#Invoke-WebRequest -Uri "https://github.com/djobera/readme/blob/main/CsUninstallTool.exe" -OutFile $UninstallToolPath

# Função para verificar se o Falcon Sensor está instalado
function Get-FalconSensorInstallation {
    $sensorPath = "C:\Program Files\CrowdStrike"
    return Test-Path -Path $sensorPath
}

# Função para desinstalar o Falcon Sensor usando tokens
function Uninstall-FalconSensor {
    param (
        [string]$UninstallToolPath,
        [string[]]$Tokens
    )
    foreach ($token in $Tokens) {
        Start-Process -FilePath $UninstallToolPath -ArgumentList "MAINTENANCE_TOKEN=$token /quiet" -Wait -NoNewWindow
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Desinstalacao bem-sucedida com o token: $token"
            return $true
        } else {
            Write-Output "Falha na desinstalacao com o token: $token"
        }
    }
    return $false
}

# Instala o Falcon Sensor
function Install-FalconSensor {
    param (
        [string]$InstallerPath,
        [string]$FullCorrectCID
    )
    Start-Process -FilePath $InstallerPath -ArgumentList "/install /quiet /norestart CID=$FullCorrectCID GROUPING_TAGS=TAG-NAME" -Wait -NoNewWindow
    Write-Output "Falcon Sensor instalado com o CID correto."
}

# Converte binário para string legível
function Convert-BinaryToHexString {
    param (
        [byte[]]$BinaryData
    )
    return [BitConverter]::ToString($BinaryData) -replace '-', ''
}

# Obter a CID atual do registro
function Get-CurrentCID {
    $regPath = "HKLM:\System\CurrentControlSet\services\CSAgent\Sim"
    $regName = "CU"
    if (Test-Path -Path $regPath) {
        $binaryCID = (Get-ItemProperty -Path $regPath -Name $regName).$regName
        $hexCID = Convert-BinaryToHexString -BinaryData $binaryCID
        return $hexCID
    } else {
        return $null
    }
}

# Verificar se o Falcon Sensor está instalado
$installedSensor = Get-FalconSensorInstallation

if ($installedSensor) {
    Write-Output "Falcon Sensor esta instalado."
    # Verificar a CID atual no registro
    $currentCID = Get-CurrentCID
    if ($currentCID) {
        Write-Output "CID atual: $currentCID"
        if ($currentCID -eq $CorrectCID) {
            Write-Output "Falcon Sensor ja esta instalado com o CID correto."
            exit
        } else {
            Write-Output "CID incorreta. Desinstalando Falcon Sensor..."
            $tokens = @($MaintenanceToken1, $MaintenanceToken2, $MaintenanceToken3)
            $uninstallSuccess = Uninstall-FalconSensor -UninstallToolPath $UninstallToolPath -Tokens $tokens
            if ($uninstallSuccess) {
                Write-Output "Instalando Falcon Sensor com a CID correta..."
                Install-FalconSensor -InstallerPath $InstallerPath -FullCorrectCID $FullCorrectCID
                # Verificar se a instalação foi bem-sucedida
                $newCID = Get-CurrentCID
                if ($newCID -eq $CorrectCID) {
                    Write-Output "Falcon Sensor instalado com sucesso com a CID correta."
                    New-Item -ItemType Directory -Path "C:\Program Files\CrowdStrike\Crowd\install"
                } else {
                    Write-Output "Falha ao instalar o Falcon Sensor com a CID correta. CID atual: $newCID"
                }
            } else {
                Write-Output "Falha ao desinstalar o Falcon Sensor."
                exit
            }
        }
    } else {
        Write-Output "CID nao encontrada no registro. Prosseguindo com a instalacao..."
        Install-FalconSensor -InstallerPath $InstallerPath -FullCorrectCID $FullCorrectCID
    }
} else {
    Write-Output "Falcon Sensor não esta instalado. Instalando..."
    Install-FalconSensor -InstallerPath $InstallerPath -FullCorrectCID $FullCorrectCID
}

Write-Output "Processo concluido."
exit
