$scripts = @(
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d 1 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSuperHidden" /t REG_DWORD /d 1 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 10 /f;
	};
	{
		reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "UnattendedSetup" /t REG_SZ /d "powershell.exe -WindowStyle \""Normal\"" -ExecutionPolicy \""Unrestricted\"" -NoProfile -File \""C:\Windows\Setup\Scripts\UserOnce.ps1\""" /f;
	};
);

& {
  [float] $complete = 0;
  [float] $increment = 100 / $scripts.Count;
  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Running scripts to modify the default user’’s registry hive. Do not close this window.' -PercentComplete $complete;
    '*** Will now execute command «{0}».' -f $(
      $script.ToString().Trim() -replace '\s+', ' ' -replace '^(.{99})(.+)$', '$1…';
    );
    $start = [datetime]::Now;
    & $script;
    '*** Finished executing command after {0:0} ms.' -f [datetime]::Now.Subtract( $start ).TotalMilliseconds;
    "`r`n" * 3;
    $complete += $increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "C:\Windows\Setup\Scripts\DefaultUser.log";
