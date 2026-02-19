# python3 -m http.server
# Open admin powershell
# IEX (IWR http://192.168.122.1:8000/setup-client.ps1)

$viosvc = (Get-Service | ? {$_.DisplayName -match "virtio"})
if ($viosvc.Length -eq 0) {
  echo "Installing virtio"

  IWR -OutFile C:\virtio.exe "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-guest-tools.exe"
  C:\virtio.exe

  Write-Host -NoNewLine 'Press any key once Virtio is installed';
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
  echo

  rm C:\virtio.exe

  echo "Installed virtio"
}

if ((Get-Command "choco.exe" -ErrorAction SilentlyContinue) -eq $null) {
  echo "Installing choco"
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  
  $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
  Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  refreshenv

  echo "Installed choco"
}

choco feature enable -n allowGlobalConfirmation
choco install -y Firefox dnspyex processhacker procexp x64dbg.portable visualstudio2022community nmap

$confirmation = Read-Host "Do you wish to install OpenSSH Server? (y/n)"
if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
  echo "Installing OpenSSH Server..."
  Add-WindowsCapability -Online -Name OpenSSH.Server
  echo "Done"
} else {
  echo "Not installing OpenSSH Server"
}

$confirmation = Read-Host "Do you wish to set MTU? (y/n)"
if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
  netsh interface ipv4 set interface "Ethernet" mtu=1280
} else {
  echo "Not setting MTU."
}

echo "Done!"
