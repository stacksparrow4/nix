$scripts = @(
	{
		Remove-Item -LiteralPath "${env:USERPROFILE}\Desktop\Microsoft Edge.lnk" -ErrorAction 'SilentlyContinue' -Verbose;
	};
	{
		Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Type 'DWord' -Value 0;
	};
	{
		Set-ItemProperty -LiteralPath 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type 'DWord' -Value 2 -Force;
	};
	{
		Get-Process -Name 'explorer' -ErrorAction 'SilentlyContinue' | Where-Object -FilterScript {
			$_.SessionId -eq ( Get-Process -Id $PID ).SessionId;
		} | Stop-Process -Force;
	};
);

& {
  [float] $complete = 0;
  [float] $increment = 100 / $scripts.Count;
  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Running scripts to configure this user account. Do not close this window.' -PercentComplete $complete;
    '*** Will now execute command «{0}».' -f $(
      $script.ToString().Trim() -replace '\s+', ' ' -replace '^(.{99})(.+)$', '$1…';
    );
    $start = [datetime]::Now;
    & $script;
    '*** Finished executing command after {0:0} ms.' -f [datetime]::Now.Subtract( $start ).TotalMilliseconds;
    "`r`n" * 3;
    $complete += $increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "$env:TEMP\UserOnce.log";
