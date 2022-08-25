$script:version ="0.8.12"
Try  
{  
    docker --version
}  
catch  
{   
    echo "Docker is not detected. Docker Desktop is to be installed"
    $var1 = ""
    while ([string]$var1.ToUpper() -ne "Y")
    {
        $var1 = Read-Host "BIOS-level hardware virtualization support must be enabled in the BIOS settings.`nCheck whether virtualization is enabled, see https://docs.docker.com/desktop/images/virtualization-enabled.png`nEnable the virtualization mode, see https://bce.berkeley.edu/enabling-virtualization-in-your-pc-bios.html`nIf it's already open press Y to continue" 
    }
    echo "Opening Windows-Subsystem-Linux"
    echo "If you are running this script for the first time,please select Restart"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    echo "Opening VirtualMachinePlatform"
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    echo "Downloading wsl-2"
    Invoke-WebRequest -Uri " https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -Outfile "$HOME\wsl_update_x64.msi"
    echo "Installing wsl-2"
    Start-Process "$HOME\wsl_update_x64.msi"  -wait /quiet
    Start-Sleep -s 1 
    wsl --set-default-version 2
    echo "Downloading Docker-Desktop-Installer.exe . This process takes about 20 minutes"
    Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -Outfile "$HOME\Docker-Desktop-Installer.exe"
    echo "Installing Docker-Desktop"
    Start-Process "$HOME\Docker-Desktop-Installer.exe" -wait "install","--quiet","--accept-license"
    ehco "Please restart your computer and re-run the command"
    exit
}

Try  
{  
    & "\Program Files\Docker\Docker\Docker Desktop.exe"
}  
catch  
{  
    $var2 = ""
    while ([string]$var2.ToUpper() -ne "Y")
    {
        $var2 = Read-Host " Failed to run "Docker Desktop.exe" automatically. Please run it manually.`nPress Y to continue" 
    }
}

function checkDockerStatus
{
    $script:checkDockerStatus= Get-Process -Name docke?| Select-String docker

    If($script:checkDockerStatus -match "docker")
    {
         echo "docker is runing"
         break
    }
    else
    {
         echo "docker is starting"
         Start-Sleep -s 1 
    }
}
for($i=0;$i -lt 15; $i++)   
{   
    checkDockerStatus
    Start-Sleep -s 1
    if ($i -eq 14)
        {
            echo "Start docker timeout"
            echo "You may need to log out"
            exit
        }
    
}

$script:checkUbuntu = wsl -l -q|Where {$_.Replace("`0","") -match '^Ubuntu'}
If($script:checkUbuntu -eq "Ubuntu")
{
    echo "Ubuntu exists"
}
else
{
    wsl --install -d Ubuntu
}

Try  
{  
    usbipd --version
}  
catch  
{  
    Invoke-WebRequest -uri https://github.com/dorssel/usbipd-win/releases/download/v2.3.0/usbipd-win_2.3.0.msi  -Outfile "$HOME\usbipd-win_2.3.0.msi"
    Start-Process "$HOME\usbipd-win_2.3.0.msi"  -wait /quiet
}

$script:email = ""
$script:option = Read-Host "Do you have a Vera account? [ Y/N ]"
Switch([string]$script:option.ToUpper())
{
    "Y"{
        $script:username = Read-Host "Please enter your username"
        $script:password = Read-Host "Please enter your password"
        $script:option = "provision"
     }

    "N" {
        $script:username = Read-Host "Let's create an Vera account.`nPlease enter username"
        $script:password = Read-Host "Please enter password"    
        $script:email = Read-Host "Please enter email"  
        $script:email = "-email="+$script:email  
        $script:option = "createAccountAndProvision"                  
     }
    default{
        Write-Host "Incorrect Choice!"
        exit
     }
}

If(($script:username -eq "") -or ($script:password -eq "")){
    echo "Error Input"
    exit
}

$script:username = "-username="+$script:username
$script:password = "-password="+$script:password

function attach ([string]$device){
    $nowTime = wsl exec date +%s
    PassthroughUSB $device
    AssignDeviceName $device
}

function PassthroughUSB ([string]$device){
    $listUSB = usbipd wsl list
    Write-Host  ($listUSB | Out-String)
    $busid = Read-Host "Please enter busid of $device dongle (for example 1-2) or skip if not present"
    If($busid  -eq "") 
    {   
        Write-Host "No $device dongle"
    }  
   else 
    {   
        $attachUSB = usbipd wsl attach --busid $busid -d ubuntu
        Write-Host  ($attachUSB | Out-String)
        Start-Sleep -s 1 
    }    
}

function AssignDeviceName ([string]$device)
{  
    For ($i=0; $i -lt 5; $i=$i+1 ){ 
        $usbCreatTime = wsl exec stat -c "%X" /dev/ttyUSB$i  2> $null
        try {
            $timeVar = [int]$usbCreatTime
        } catch {
            Write-Host "Can not get /dev/ttyUSB$i"
            continue
        }
        If ($usbCreatTime -gt $nowTime) {
            echo "-$device=/dev/ttyUSB$i" 
            Write-Host "-$device=/dev/ttyUSB$i" 
            break
        }  
    }
}

docker stop orchestrator-vhubzz  2> $null
docker rm orchestrator-vhubzz 2> $null
Try{
    ubuntu run -d
}
catch {
    echo "Failed to start ubuntu"
    exit
}

$script:zwaveDevice = attach zwave
$script:zigbeeDevice = attach zigbee
echo "docker run --net host -v /var/run/docker.sock:/var/run/docker.sock --restart=always --name orchestrator-vhubzz us-east4-docker.pkg.dev/softhub-354014/softhub/orchestrator-vhubzz:$script:version /root/orchestrator vhub -start -option $script:option $script:username  $script:password $script:email $script:zigbeeDevice $script:zwaveDevice $script:args"
docker run --net host -v /var/run/docker.sock:/var/run/docker.sock --restart=always --name orchestrator-vhubzz us-east4-docker.pkg.dev/softhub-354014/softhub/orchestrator-vhubzz:$script:version /root/orchestrator vhub -start -option $script:option $script:username  $script:password $script:email $script:zigbeeDevice $script:zwaveDevice $script:args

