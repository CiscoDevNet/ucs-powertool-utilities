FROM mcr.microsoft.com/powershell

WORKDIR /app

ADD . /app

RUN pwsh -Command "Install-Module Cisco.UcsManager -AcceptLicense -force"
RUN pwsh -Command "Install-Module Cisco.Ucs.Common -AcceptLicense -force"
RUN pwsh -Command "Install-Module Cisco.Imc -AcceptLicense -force"
RUN pwsh -Command "Install-Module Cisco.UcsCentral -AcceptLicense -force"

