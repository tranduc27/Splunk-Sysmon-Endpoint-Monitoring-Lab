# Splunk-Sysmon-Endpoint-Monitoring-Lab
Dùng Splunk + Splunk Universal Forwarder + Sysmon để giám sát hành vi endpoint trên Windows Server 2022, gồm process creation, PowerShell execution, network connection, file creation và DNS query.
Triển khai SOC Lab sử dụng Splunk Enterprise, Splunk Universal Forwarder và Sysmon nhằm giám sát hành vi endpoint trên máy ảo Windows Server 2022.

---

## Project Overview

Dự án này triển khai một hệ thống giám sát endpoint tập trung sử dụng Splunk Enterprise trong môi trường lab ảo hóa. Mục tiêu chính là thu thập, phân tích Sysmon logs từ Windows Server và phát hiện các hành vi đáng ngờ liên quan đến process creation và PowerShell execution.

Lab tập trung vào 3 use case chính:

- Giám sát process creation bằng Sysmon EventCode 1.
- Phát hiện PowerShell chạy với tham số `-EncodedCommand`.
- Phát hiện `cmd.exe` gọi `powershell.exe`.

---

## Architecture

**SIEM Server:** Ubuntu Server - Splunk Enterprise 10.2.3 - IP: `192.168.122.69`

**Endpoint:** Windows Server 2022 VM - Sysmon + Splunk Universal Forwarder - IP: `192.168.122.114`

**Log Forwarding:** Windows endpoint gửi log về Splunk thông qua TCP port `9997`.

**Data Source:** `Microsoft-Windows-Sysmon/Operational`

---

## Implementation Phases

### Phase 1: Setup & Log Forwarding

Triển khai Splunk Enterprise trên Ubuntu Server và sử dụng lại Splunk Universal Forwarder trên Windows Server.

Cấu hình Universal Forwarder gửi log về Splunk Server:

```ini
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = 192.168.122.69:9997

[tcpout-server://192.168.122.69:9997]
```

Cấu hình Forwarder thu thập Sysmon Operational logs:

```ini
[WinEventLog://Microsoft-Windows-Sysmon/Operational]
disabled = 0
index = wineventlog
sourcetype = WinEventLog:Microsoft-Windows-Sysmon/Operational
```

Kết quả: Splunk đã nhận thành công Sysmon logs từ Windows Server.

---

### Phase 2: Sysmon Installation

Cài đặt Sysmon trên Windows Server 2022 để ghi nhận endpoint telemetry.

Lệnh cài đặt Sysmon:

```powershell
cd C:\Tools\Sysmon
.\Sysmon64.exe -accepteula -i .\sysmon_config.xml
```

Kiểm tra service:

```powershell
Get-Service Sysmon64
```

Kết quả: Sysmon chạy thành công và tạo log trong `Microsoft-Windows-Sysmon/Operational`.

---

### Phase 3: Process Creation Monitoring

Sử dụng Sysmon EventCode `1` để giám sát các process được tạo trên Windows endpoint.

SPL query:

```spl
index=wineventlog sourcetype="WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=1
| table _time host User Image ParentImage CommandLine ProcessId ParentProcessId
| sort - _time
```

Kết quả: Splunk hiển thị được các process như `notepad.exe`, `calc.exe`, `cmd.exe`, `powershell.exe` cùng parent process và command line.

---

### Phase 4: Suspicious PowerShell Encoded Command Detection

Mô phỏng hành vi PowerShell chạy với tham số `-EncodedCommand`.

Safe test command:

```powershell
$command = 'Write-Output "This is a harmless Sysmon detection test"'
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encoded = [Convert]::ToBase64String($bytes)
powershell.exe -NoProfile -EncodedCommand $encoded
```

SPL detection query:

```spl
index=wineventlog sourcetype="WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=1
| search Image="*\\powershell.exe" OR OriginalFileName="PowerShell.EXE"
| search CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"
| table _time host User Image ParentImage CommandLine ProcessId ParentProcessId
| sort - _time
```

Kết quả: Splunk phát hiện thành công PowerShell process có chứa `-EncodedCommand`.

---

### Phase 5: CMD Spawned PowerShell Detection

Mô phỏng trường hợp `cmd.exe` gọi `powershell.exe`.

Safe test command chạy từ Command Prompt:

```cmd
powershell.exe -NoProfile -Command "Write-Output cmd_spawned_powershell_test"
```

SPL detection query:

```spl
index=wineventlog sourcetype="WinEventLog:Microsoft-Windows-Sysmon/Operational" EventCode=1
| search Image="*\\powershell.exe" ParentImage="*\\cmd.exe"
| table _time host User ParentImage Image CommandLine ProcessId ParentProcessId
| sort - _time
```

Kết quả: Splunk phát hiện thành công process chain `cmd.exe -> powershell.exe`.

---

## Detection Result

| Use Case | EventCode | Result |
|---|---|---|
| Process Creation Monitoring | Sysmon EventCode 1 | Thành công |
| PowerShell Encoded Command Detection | Sysmon EventCode 1 | Thành công |
| CMD Spawned PowerShell Detection | Sysmon EventCode 1 | Thành công |

---

## Technical Challenges & Troubleshooting

### Sysmon logs chưa xuất hiện trong Splunk

**Vấn đề:** Sysmon đã cài thành công trên Windows nhưng Splunk chưa nhận được Sysmon logs.

**Phân tích:** Universal Forwarder chưa được cấu hình để thu thập log source `Microsoft-Windows-Sysmon/Operational`.

**Giải quyết:** Thêm stanza Sysmon vào `inputs.conf` và restart Splunk Universal Forwarder.

---

### Field hiển thị chưa rõ trong Splunk

**Vấn đề:** Raw log có nhiều thông tin, khó đọc khi phân tích.

**Giải quyết:** Sử dụng lệnh `table` trong SPL để chỉ hiển thị các field quan trọng như `Image`, `ParentImage`, `CommandLine`, `ProcessId`, `ParentProcessId`.

---

## Evidence & Results

### Sysmon Service Running

<img width="981" height="520" alt="image" src="https://github.com/user-attachments/assets/46755340-a058-4c60-9f66-c0a38d2e91c0" />


Sysmon được cài đặt và chạy thành công trên Windows Server.

---

### Sysmon Logs Ingested into Splunk

<img width="1289" height="808" alt="image" src="https://github.com/user-attachments/assets/ab655963-bdcb-4400-9805-45d85024fb7c" />


Splunk nhận thành công log từ `Microsoft-Windows-Sysmon/Operational`.

---

### Process Creation Monitoring

<img width="1217" height="771" alt="image" src="https://github.com/user-attachments/assets/bf68f2e3-b22e-44f2-a9a5-56af17085052" />


Splunk hiển thị process creation events từ Sysmon EventCode 1.

---

### Suspicious PowerShell Encoded Command Detection

<img width="1210" height="767" alt="image" src="https://github.com/user-attachments/assets/bfe49cee-aa13-4a4e-88fa-a7ab72fcc98a" />


Splunk phát hiện PowerShell chạy với tham số `-EncodedCommand`.

---

### CMD Spawned PowerShell Detection

<img width="1217" height="774" alt="image" src="https://github.com/user-attachments/assets/569a5ecf-d921-43a2-ad65-a07ab65bc55c" />


Splunk phát hiện `cmd.exe` gọi `powershell.exe`.

---

## Key Findings & Lessons Learned

**Endpoint Visibility:** Sysmon cung cấp khả năng quan sát chi tiết process creation, parent process và command line trên Windows endpoint.

**Detection Engineering:** SPL có thể được sử dụng để phát hiện các hành vi đáng ngờ như PowerShell encoded command hoặc parent-child process bất thường.

**SOC Monitoring:** Việc kết hợp Sysmon, Splunk Universal Forwarder và Splunk Enterprise giúp xây dựng quy trình giám sát endpoint tập trung.

**Investigation Context:** Các field như `Image`, `ParentImage` và `CommandLine` rất quan trọng trong quá trình điều tra endpoint.

---





