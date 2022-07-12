$script:version ="0.6.4"
Try  
{  
    docker --version
}  
catch  
{  
    winget install "Docker Desktop"
    $var1 = ""
    while ([string]$var1.ToUpper() -ne "Y")
    {
        $var1 = Read-Host "Docker Desktop have been installed, you need open 'Docker Desktop' from Windows Menu to accept terms.`nPress Y to continue" 
    }
}

Try  
{  
    docker --version
}  
catch
{
    echo "Docker is not installed properly"
    exit
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
    winget install --interactive --exact dorssel.usbipd-win
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
echo "docker run --net host -v /var/run/docker.sock:/var/run/docker.sock --restart=always --name orchestrator-vhubzz us-east4-docker.pkg.dev/softhub-354014/softhub/orchestrator-vhubzz:$script:version /root/orchestrator vhub -start -option $script:option $script:username  $script:password $script:email $script:zigbeeDevice $script:zwaveDevice"
docker run --net host -v /var/run/docker.sock:/var/run/docker.sock --restart=always --name orchestrator-vhubzz us-east4-docker.pkg.dev/softhub-354014/softhub/orchestrator-vhubzz:$script:version /root/orchestrator vhub -start -option $script:option $script:username  $script:password $script:email $script:zigbeeDevice $script:zwaveDevice
