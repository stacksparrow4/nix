{ pkgs, ... }:

{
  home.packages = [(
    pkgs.writeShellApplication {
      name = "mkburpscript";
      text = ''
        if [[ -f main.py ]]; then
          echo "main.py already exists! Please remove before using this script"
          exit 1
        fi

        cat <<EOF > main.py
        from requests import Session
        import json
        import base64
        import time
        import urllib3
        from urllib3.exceptions import InsecureRequestWarning
        urllib3.disable_warnings(category=InsecureRequestWarning)

        s = Session()
        s.verify = False
        s.proxies = {"http": "http://localhost:8080", "https": "http://localhost:8080"}
        EOF
      '';
    }
  )];
}
