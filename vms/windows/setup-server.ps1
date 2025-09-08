# python3 -m http.server
# Open admin powershell
# IEX (IWR http://192.168.122.1:8000/setup-server.ps1)

$viosvc = (Get-Service | ? {$_.DisplayName -match "virtio"})
if ($viosvc.Length -eq 0) {
  IWR -OutFile virtio.exe "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-guest-tools.exe"
  .\virtio.exe

  Write-Host -NoNewLine 'Press any key once Virtio is installed';
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

echo "Done!"
