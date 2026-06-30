$scripts = @(
  {
    Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
  };
  {
    # Virtion Guest Tools
    Start-Process -FilePath 'E:\virtio_win_guest_tools.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait -Verbose;
  };
  {
    # VirtioFsSvc
    Start-Process -FilePath msiexec.exe -ArgumentList '/i', 'G:\winfsp.msi', '/qn', '/norestart' -Wait -Verbose;

    Get-Service -Name 'VirtioFsSvc' -ErrorAction 'SilentlyContinue' |
      Set-Service -StartupType 'Automatic' -PassThru |
      Start-Service;
  };
  {
    # Install choco
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));

    choco feature enable -n allowGlobalConfirmation
    choco install -y @CHOCOPKGS@
  };
  {
    # OpenSSH
    Add-WindowsCapability -Online -Name OpenSSH.Server
  };
  {
    # Powershell modules
    Install-Module OleViewDotNet -Force
    Install-Module NtObjectManager -Force
  };
  {
    # Update powershell help
    Update-Help -ErrorAction SilentlyContinue
  };
  {
    # Assign static IP address
    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress @IPADDRESS@ -PrefixLength 24 -DefaultGateway 192.168.122.1
  };
  @ADDITIONALSCRIPTS@
  {
    Remove-Item -LiteralPath @(
      'C:\Windows\Panther\unattend.xml';
      'C:\Windows\Panther\unattend-original.xml';
      'C:\Windows\Setup\Scripts\Wifi.xml';
    ) -Force -ErrorAction 'SilentlyContinue' -Verbose;
  };
);

& {
  [float] $complete = 0;
  [float] $increment = 100 / $scripts.Count;
  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Running scripts to finalize your Windows installation. Do not close this window.' -PercentComplete $complete;
    '*** Will now execute command «{0}».' -f $(
      $script.ToString().Trim() -replace '\s+', ' ' -replace '^(.{99})(.+)$', '$1…';
    );
    $start = [datetime]::Now;
    & $script;
    '*** Finished executing command after {0:0} ms.' -f [datetime]::Now.Subtract( $start ).TotalMilliseconds;
    "`r`n" * 3;
    $complete += $increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "C:\Windows\Setup\Scripts\FirstLogon.log";
