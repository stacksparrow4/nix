$scripts = @(
	{
		Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
	};
	{
    Start-Process -FilePath 'E:\virtio_win_guest_tools.exe' -ArgumentList '/install', '/quiet', '/norestart' -Wait -Verbose;
  };
  {
    Start-Process -FilePath msiexec.exe -ArgumentList '/i', 'G:\winfsp.msi', '/qn', '/norestart' -Wait -Verbose;

    Get-Service -Name 'VirtioFsSvc' -ErrorAction 'SilentlyContinue' |
      Set-Service -StartupType 'Automatic' -PassThru |
      Start-Service;
	};
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
