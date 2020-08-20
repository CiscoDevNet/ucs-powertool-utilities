FROM mcr.microsoft.com/powershell

RUN pwsh -Command "Install-Module Cisco.UcsManager -AcceptLicense -force"
RUN pwsh -Command "Install-Module Cisco.Ucs.Common -AcceptLicense -force"

WORKDIR /app

ADD . /app

CMD ["pwsh", "imm-compatibility-checker.ps1"]