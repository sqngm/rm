# 如果无法执行ps脚本：以管理员身份运行powershell,执行下面的命令就可以了
# Get-ExecutionPolicy -List
# Set-ExecutionPolicy RemoteSigned

# powershell -c "C:\RM_Data\R1\ServerInjectFiles.SQN.0917\右键选择PoserShell自动开服.RightClickRunAsPowerShell.AutoRestartServer.v3.62169.917.ps1"
# 修改编码，保证英文操作系统不乱码
chcp 936

$gameRootPath = Resolve-Path "$PSScriptRoot\..\"

# 创建唯一的 main_log 文件名
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$mainLogFileName = "guardian_rumbleverse_log_${timestamp}.log"

#$gameLogFolderPath = "${gameRootPath}\gameLogFolder" #C:\Users\limin\AppData\Local\Rumbleverse\Saved\Logs

$userProfile = $env:USERPROFILE
$gameLogFolderPath = "$userProfile\AppData\Local\Rumbleverse\Saved\Logs"
#$gameLogFolderPath = "$userProfile\testlogs"

$processName = "RumbleverseClient-Win64-Shipping"
$guardian_rumbleverse_log = "$PSScriptRoot\logs\${mainLogFileName}"
$rumbleverse_log = "$PSScriptRoot\logs\rumbleverse_server_game_log_before_${timestamp}.log"
$controlFilePath = "${PSScriptRoot}\control.txt"

$configFilePath = "$PSScriptRoot\..\Rumbleverse\Binaries\Win64\Config.ini"


#--------------------------端口号配置：目前还不支持修改，后续支持----------------------------#
# 如果不是默认的端口号62169请修改下面的数字
#$gamePort = 62169
#----------------------------------------------------------------#

#--------------------------切模式：----------------------------#
#开哪个模式就把前面的#号去掉，其他的模式前面保持有#号表示不会生效，如果有多个模式生效则以最后一行的为准

#各模式已合并成一个文件，通过配置文件来修改游戏模式，或者通过运行时传递参数的方式(还未实现)？
#目前改模式的方式：双击打开当前目录的服务器设置.bat 来修改
$gameModeFile = ".\Server.dll" 

## 下面的是老的版本，按模式分开的，如果上面那个方式有问题，可以切换回下面老的版本的方式来运行
## 用老的版本需要进配置文件目录删除配置文件，否则 可能会变端口，路径:..\Rumbleverse\Binaries\Win64\Config.ini
#$gameModeFile = ".\v0.old\Solos.dll" #单排
# $gameModeFile = ".\v0.old\Duos.dll" #双排
# $gameModeFile = ".\v0.old\from.ed.git\BR_Trios.dll" #三排
# $gameModeFile = ".\v0.old\from.ed.git\BR_Quads.dll" #四排
# $gameModeFile = ".\v0.old\Playground.dll" #训练场


#--------------------------自动切模式配置：目前还不支持修改，还有问题----------------------------#
$enableAutoSwitchGameMode = $true  #默认未开启，改为$true表示 开启
$global:alreadyChangedConfigGameMode = $false #更新一次记录状态，以避免后续循环更新出问题，重启后会重置此变量为false。#目前这个没用到

# 有效玩家数量，记录起来，用来判断 自动开服人数切模式
$global:effectPyayerCounts = 0
#0到3人时开训练模式，4到9人单排，10到18人双排，19到27人三排，27人以上四排
# 定义自动切换游戏模式的阈值变量

$thresholdTraining = 8   #大于等于这个数改单排,少于这个数一半改训练场
$thresholdSolo = 16      #大于等于这个数改双排
$thresholdDuo = 38       #大于等于这个数改三排
$thresholdTrio = 39      #大于等于这个数改四排

$thresholdTraining = 4
$thresholdSolo = 10
$thresholdDuo = 19
$thresholdTrio = 27
#------------------------------------------------------#

# 获取本机的机器名
$computerName = $env:COMPUTERNAME

# 获取外网IP地址，三个都可以，如果第一个有问题或者慢可以用后面两个，在powershell窗口里面直接输入括号里面的来测试
$externalIP = $realExternalIP = (Invoke-RestMethod -Uri "https://who.nie.netease.com/").ip.Trim()
#$externalIP = $realExternalIP = (Invoke-RestMethod -Uri "https://ipv4.icanhazip.com/").Trim()
#$externalIP = $realExternalIP = (Invoke-RestMethod -Uri "http://ifconfig.me/ip").Trim()

#判断有没有米西IP
$mixiIPObject = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "ZeroTier*" }
$radminIPObject = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "Radmin*" }

$joinPromptTxt = ""
if ($mixiIPObject) {
    $externalIP = $mixiIPObject.IPv4Address
    $joinPromptTxt = "[$timestamp] 当前为米西组网的方式来开服的，服务器名：$computerName ，米西IP: $externalIP (公网IP $realExternalIP)! 要加入此服，请先去mx16.com下载客户端，进入软件后点左边的手柄图标->动作游戏或其他游戏->加入房间。等显示IP和延迟就可以加入了。`r`n " 
    $joinPromptTxt = $joinPromptTxt + "[$timestamp] 需要注意的是：如果一直获取不到IP或不显示延迟，请退出房间，或者 重启软件。`r`n" 
    $joinPromptTxt = $joinPromptTxt + "[$timestamp] 需要注意的是：如果不玩游戏了，先退出游戏，最后再退米西房间，否则会导致游戏服务端异常退出，所有人都会掉线。" 
    Write-Output $joinPromptTxt | Tee-Object -FilePath $guardian_rumbleverse_log -Append
} 
elseif ($radminIPObject) {
    $externalIP = $radminIPObject.IPv4Address
    $joinPromptTxt = "[$timestamp] 当前为RadminVPN组网的方式来开服的(不用这个请卸载RadminVPN软件，因为这个装上就有，无论有没有连接到VPN服务端，会出现误判)，服务器名：$computerName ，Radmin IP: $externalIP  (公网IP $realExternalIP)!"
    Write-Output $joinPromptTxt  | Tee-Object -FilePath $guardian_rumbleverse_log -Append
}

else {
    $joinPromptTxt = "[$timestamp] 当前为直连服，服务器名：$computerName ，公网IP: $externalIP  (公网IP $realExternalIP) !"
    Write-Output $joinPromptTxt | Tee-Object -FilePath $guardian_rumbleverse_log -Append
}

$connectCMD = "open ${externalIP}:62169"

$gameServerDashboardAPI = "http://20.2.29.37/api"


Write-Output "##### $timestamp #####" | Tee-Object -FilePath $guardian_rumbleverse_log

Write-Output "gameRootPath: $gameRootPath" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
Write-Output "gameLogFolderPath: $gameLogFolderPath" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
Write-Output "[$timestamp]【有问题发这个日志文件出来】 自动开服和自动切模式完整日志文件guardian_rumbleverse_log路径：: $guardian_rumbleverse_log" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
Write-Output "controlFilePath: $controlFilePath,$configFilePath" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

#Write-Output "当前模式 gameModeFile: $gameModeFile  | 包含Solos为单排,Duos双排， Trios为三排，Quads为四排，Playground为训练场" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
$configContent = Get-Content -Path $configFilePath
$currentGameMode = $configContent -match 'GameMode=(\d)'

Write-Output "[$timestamp] 当前游戏模式为：$currentGameMode,完整的配置文件为：$configContent `r`n 【游戏模式说明】 训练场 0，单排  1，双排 2，三排 3，四排 4" | Tee-Object -FilePath $guardian_rumbleverse_log -Append


function CreateFileOrDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$IsDirectory
    )

    $parentPath = Split-Path -Path $Path -Parent

    if (-not (Test-Path -Path $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath | Out-Null
        Write-Output "Created directory: $parentPath" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    }

    if (-not (Test-Path -Path $Path)) {
        if ($IsDirectory) {
            New-Item -ItemType Directory -Path $Path | Out-Null
            Write-Output "Created directory: $Path" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        }
        else {
            $null = New-Item -ItemType File -Path $Path
            Write-Output "Created file: $Path" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        }
    }
    else {
        Write-Output "Exists: $Path" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    }
}

function CheckLogFile {
    $latestLogFile = Get-ChildItem -Path $GameLogFolderPath | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    $outputString = ""
    if ($latestLogFile -and (Test-Path -Path $latestLogFile.FullName)) {
        $outputString = "Log file found $latestLogFile."
        Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        Write-Host $outputString
        $logContent = Get-Content -Path $latestLogFile.FullName

        $userJoinedLogStrs = $logContent | Select-String -Pattern "LogNet: NotifyAcceptingChannel"
        $userJoinedCount = $userJoinedLogStrs.Count
        $UserExitLog = $logContent | Select-String -Pattern "LogNet: UChannel::Close"
        $UserExitCount = $UserExitLog.Count
        $ConnecteUserCount = $userJoinedCount - $UserExitCount
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $outputString = "[$timestamp] 当前玩家数量：  $ConnecteUserCount "

        $configContent = Get-Content -Path $configFilePath
        $currentGameMode = $configContent -match 'GameMode=(\d)'
        #  Write-Host $currentGameMode


        if ($currentGameMode -eq "GameMode=0") {
            $global:effectPyayerCounts = $global:PreviousConnecteUserCount
            Write-Host "[$timestamp] 上一次监测的玩家数量： $global:effectPyayerCounts "
            $global:PreviousConnecteUserCount = $ConnecteUserCount #保存上一次监测的玩家数量
        }
        if ($enableAutoSwitchGameMode) {
            $outputString = "$outputString， 当前已经开启自动切换游戏模式，当0到$($thresholdTraining / 2)人时开训练模式，${thresholdTraining}到${thresholdSolo}人单排，${thresholdSolo}到${thresholdDuo}人双排，${thresholdDuo}到${thresholdTrio}人三排，${thresholdTrio}人以上四排"
            
            if(($ConnecteUserCount -ge $thresholdTraining) -and ($currentGameMode -eq "GameMode=0")) {
                $global:effectPyayerCounts = $global:PreviousConnecteUserCount
                 Write-Host "[$timestamp] 上一次监测的玩家数量： $global:effectPyayerCounts "
                 $global:PreviousConnecteUserCount = $ConnecteUserCount #保存上一次监测的玩家数量
                 $newContent = $configContent -replace 'GameMode=\d', 'GameMode=1'
                 Set-Content -Path $configFilePath -Value $newContent
                 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                 $outputString = $outputString + "`n`r" + "[$timestamp] 玩家人数已达到单排设定人数 $thresholdTraining，下一局将自动切换到单排模式。" 
                 Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                 Write-Host $outputString
                 return "够人单排了"
            }
        }
            
        #取已发射后的人数作为准确 人数,保证只设置一次人数值
        if ($global:effectPyayerCounts -eq 0 -and $logContent -match "Display: Entering new game flow state: 3") {
            $global:effectPyayerCounts = $ConnecteUserCount
            $outputString = "[$timestamp] 发射玩家数量：  $ConnecteUserCount "
        }

        Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        Write-Host $outputString
        if ($logContent -match "SheikErrorLog: Error: Source Client, System Login, CallCode Logout, ErrorCode -1") {
            #$linesWithRemoteAddr = $logContent | Where-Object { $_ -match "RemoteAddr:" } | Select-Object -Last 1 
            $linesWithRemoteAddr = $logContent | Where-Object { $_ -match "Warning: UNetConnection::Tick: Connection TIMED OUT." } | Select-Object -Last 1  
            $pattern = "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
            $pattern1 = "Sheik:"
            $result = ($linesWithRemoteAddr -split $pattern1)[-1].Split("`n")[0]
            $match = [regex]::Match($linesWithRemoteAddr, $pattern)
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output "[$timestamp] 炸服了，服务器异常退出了，如果是米西服，可能是有人在没有退出米西房前直接关闭游戏导致的，引起掉线的IP地址：$match 游戏昵称ID：$result" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            Write-Host "[$timestamp] 炸服了，服务器异常退出了，如果是米西服，可能是有人在没有退出米西房前直接关闭游戏导致的，引起掉线的IP地址：$match 游戏昵称ID：$result"
            return "ServerUnliving_SheikErrorLog"
        }
        elseif ($logContent -match "Error: Task_CreateParty::CozmoWorkCompleted - Cozmo work failed: Failed to create party for user") {
            #$linesWithRemoteAddr = $logContent | Where-Object { $_ -match "RemoteAddr:" } | Select-Object -Last 1 
            $linesWithRemoteAddr = $logContent | Where-Object { $_ -match "Warning: UNetConnection::Tick: Connection TIMED OUT." } | Select-Object -Last 1 
            $pattern = "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
            $pattern1 = "Sheik:"
            $result = ($linesWithRemoteAddr -split $pattern1)[-1].Split("`n")[0]
            $match = [regex]::Match($linesWithRemoteAddr, $pattern)
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output "[$timestamp]服务端异常退出, 可能是有人加入失败导致,引起掉线的IP地址：$match 游戏昵称ID：$result" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            Write-Host "[$timestamp]服务端异常退出, 可能是有人加入失败导致,引起掉线的IP地址：$match 游戏昵称ID：$result"
            return "CreatePartyFailed"
        }
        elseif ($logContent -match "WBP_Sheik_ScreenEoM.WBP_Sheik_ScreenEOM_C:OnRoundFinished_cb" -or $logContent -match "SheikAILog: Disabling RingNavInvoker") {

            if ($enableAutoSwitchGameMode) {
            
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                #定义指定队伍数量的日志文本 #这个内容目前无法获取数量，一直为0，不要用这个了
                #$searchContent = "Warning: Total Teams: $autoSwitchGameModeThreshold"
               
                # 读取配置文件内容
                #    $configContent = Get-Content -Path $configFilePath
    
                # 获取当前游戏模式
                #   $currentGameMode = $configContent -match 'GameMode=(\d)'
    
                $outputString = "[$timestamp]  `r`n 【已进入自动切换模式判断,仅当一局结束时才自动检测。】 当前游戏配置文件里面设置的最新模式为：$currentGameMode , 玩家人数为： $ConnecteUserCount  `r`n " 
                Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                Write-Host $outputString 
               
                $needSwitchGameMode = $false
                if (($global:effectPyayerCounts -ge $thresholdTrio) -and ($currentGameMode -notmatch "GameMode=4")) { 
                    $needSwitchGameMode = $true
                    $outputString = "[$timestamp] 玩家人数已达到四排设定人数 $thresholdTrio，下一局将自动切换到四排模式。" 
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString # 注入后上一行无法输出 到控制台窗口，所以需要再用这种方式输出 一次
                    $newContent = $configContent -replace 'GameMode=\d', 'GameMode=4'
                }
                elseif (($global:effectPyayerCounts -ge $thresholdDuo -and $global:effectPyayerCounts -lt $thresholdTrio) -and ($currentGameMode -notmatch "GameMode=3")) {
                    $needSwitchGameMode = $true
                    $outputString = "[$timestamp] 玩家人数已达到三排设定人数 $thresholdDuo，下一局将自动切换到三排模式。"
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString
                    $newContent = $configContent -replace 'GameMode=\d', 'GameMode=3'
                }
                elseif (($global:effectPyayerCounts -ge $thresholdSolo -and $global:effectPyayerCounts -lt $thresholdDuo) -and ($currentGameMode -notmatch "GameMode=2")) {
                    $needSwitchGameMode = $true
                    $outputString = "[$timestamp] 玩家人数已达到双排设定人数 $thresholdSolo，下一局将自动切换到双排模式。" 
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString
                    $newContent = $configContent -replace 'GameMode=\d', 'GameMode=2'
                }
                elseif (($global:effectPyayerCounts -ge $thresholdTraining -and $global:effectPyayerCounts -lt $thresholdSolo) -and ($currentGameMode -notmatch "GameMode=1")) {
                    $needSwitchGameMode = $true
                    $outputString = "[$timestamp] 玩家人数已达到单排设定人数 $thresholdTraining，下一局将自动切换到单排模式。" 
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString
                    $newContent = $configContent -replace 'GameMode=\d', 'GameMode=1'
                }
                elseif (($global:effectPyayerCounts -lt ($thresholdTraining / 2)) -and ($currentGameMode -notmatch "GameMode=0")) {
                    $needSwitchGameMode = $true
                    $outputString = "[$timestamp] 玩家人数少于 $($thresholdTraining / 2)，下一局将自动切换到训练模式。" 
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString
                    $newContent = $configContent -replace 'GameMode=\d', 'GameMode=0'
                }
                else {
                    $outputString = "[$timestamp] 当前模式不在预期设计的模式里面了，请联系牛子修改开服脚本。" 
                    #return $false
                }
    
                $global:alreadyChangedConfigGameMode = $needSwitchGameMode 
                #Write-Host "$needSwitchGameMode : needSwitchGameMode  $global:alreadyChangedConfigGameMode : alreadyChangedConfigGameMode"
                if ($needSwitchGameMode) {                 
                    # 将修改后的内容写回配置文件
                    Set-Content -Path $configFilePath -Value $newContent
                    $configContent = Get-Content -Path $configFilePath
                    $outputString = "[$timestamp] 配置文件 $configFilePath 已更新，内容：$newContent ." 
                    Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Write-Host $outputString
                    if ($currentGameMode -contains "GameMode=0") {                          
                    
                        $outputString = "[$timestamp] 当前模式为训练模式，一局50分钟后才会自动结束.但现在人数已经超过${thresholdTraining}人，将直接重启并开启多排模式。" 
                        Write-Output $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                        Write-Host $outputString
                        
                        return "restartNow"
                    }
                    else {
                        #Start-Sleep -Seconds 10                        
                    }
                } 
                else {  
                }
            }   
            return "RoundFinished"                
        }
        else {  
            return $false
        }
    }
    else {
        Write-Output "Log file not found in $GameLogFolderPath." | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        return $false
    }
}

function CheckProcessRunning {
    # $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($gameRootPath) } | Sort-Object StartTime -Descending | Select-Object -First 1
    return $process -ne $null
}

function RestartGameServer {  
    $global:alreadyChangedConfigGameMode = $false
    $global:effectPyayerCounts = 0
    $timestamp2 = Get-Date -Format "yyyyMMddHHmmss"

    $latestLogFile = Get-ChildItem -Path $GameLogFolderPath | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    #Copy-Item -Path $latestLogFile -Destination $rumbleverse_log
    $logContent = Get-Content -Path $latestLogFile.FullName
    $rumbleverse_log = "$PSScriptRoot\logs\rumbleverse_server_game_log_before_${timestamp2}.log"
    $logContent | Tee-Object -FilePath $rumbleverse_log -OutVariable logOutput | Out-Null

    Write-Output "[$timestamp2] 原始服务端游戏日志($GameLogFolderPath\$latestLogFile)已经保存到 $rumbleverse_log " | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    
    #Write-Output "当前模式为 gameModeFile: $gameModeFile  | 包含Solos为单排,Duos双排， Trios为三排，Quads为四排，Playground为训练场" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

    Start-Process -FilePath "${gameRootPath}\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe" -ArgumentList "-log", "-nullrhi", "-notexturestreaming", "-threads 200", "-high", "-noaudio" -WindowStyle hidden # -PassThru
   
    # cd ${gameRootPath}
    # ##.\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe "-log" "-nullrhi" "-notexturestreaming" "-threads 200" "-high" "-noaudio" > ".\gameLogFolder\game_log_${timestamp2}.txt" 2>&1
    # .\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe "-log" "-nullrhi" "-windowed"

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "`r`n[$timestamp] RestartGameServer:done!" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

        
    #Write-Output "当前模式 gameModeFile: $gameModeFile  | 包含Solos为单排,Duos双排， Trios为三排，Quads为四排，Playground为训练场" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    $configContent = Get-Content -Path $configFilePath
    $currentGameMode = $configContent -match 'GameMode=(\d)'
    Write-Output "[$timestamp] 当前游戏模式为：$currentGameMode,完整的配置文件为：$configContent  `r`n " | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    if ($currentGameMode -eq "GameMode=0") {
        $gameModeFile = ".\v0.old\Playground.dll"
       
    }


    Start-Sleep -Seconds 20

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] Setting process priority to High" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    #$process = Get-Process -Name "RumbleverseClient-Win64-Shipping" -ErrorAction SilentlyContinue
    $process = Get-ListeningPortsByProcessName -processName $processName -externalJoinIP $externalIP -isGetProcessId $true
    if ($process) {
        $process.PriorityClass = "High"
    }

    #Start-Sleep -Seconds 20
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    #Write-Output "[$timestamp] Injecting DLL" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    #$arguments = '--process-name RumbleverseClient-Win64-Shipping.exe --inject ".\Rumbleverse\Binaries\Win64\Server.dll"'
    #$arguments = '--process-name RumbleverseClient-Win64-Shipping.exe --inject "..\ServerInjectFiles\Solos.dll"'
    #$arguments = "--process-name RumbleverseClient-Win64-Shipping.exe --inject `"$gameModeFile`""
    #Write-Output "[$timestamp] Injecting arguments: $arguments" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

    #Start-Process -FilePath "${PSScriptRoot}\Injector2.exe" -ArgumentList $arguments
    # cd ${PSScriptRoot}
    # Write-Output "[$timestamp] .\Injector2.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject $gameModeFile" | Tee-Object -FilePath $guardian_rumbleverse_log -Append 
    # #.\Injector2.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject $gameModeFile > $injectResult
    # $command = ".\Injector2.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject $gameModeFile"
    # $injectResult = cmd.exe /c $command

    # Write-Output "[$timestamp] injectResult： $injectResult" | Tee-Object -FilePath $guardian_rumbleverse_log -Append 
    
    $foundPort = $false
    Start-Sleep -Seconds 12
    $findCount = 0
    
    while (-not $foundPort) {  
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # 这个不准确 ，有时候并不是62169
        #$filteredOutput = netstat -ano | Select-String "62169" #如果修改过默认端口请把脚本里面的62169改成对应的端口，否则 会检测不到已启来。
        
        #根据进程名去找监听端口，非常准确 
        $result = Get-ListeningPortsByProcessName -processName $processName -externalJoinIP $externalIP -isGetProcessId $false
        if (!(CheckProcessRunning)) {
            $foundPort = $true
            Write-Output " `r`n[$timestamp] RestartGameServer: Server Crash, Now auto Start Now(服务端崩溃了，重启中。。)!! " | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        }
        elseif ($result.JoinCommand) {
            $foundPort = $true
            Write-Output "`r`n[$timestamp] RestartGameServer: Server is living,You can connect now[服务端已启动，可以开始连接了！]【连接命令：$($result.JoinCommand))!!】" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            if ($result.WarningMessage) {
                Write-Output $result.WarningMessage | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            }
        }

        
        else {
            Write-Output " `r`n[$timestamp] RestartGameServer: Waiting Server Ready! [$filteredOutput]" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            
            Start-Sleep -Seconds 2
        }
        $findCount = $findCount + 1

        if ($findCount -ge 30) {
            Write-Output "`r`n[$timestamp] 【貌似 服务端挺久都没有启动成功，有可能是注入失败，请检查脚本开服日志。或者关闭这个窗口，重新打开试试。】`r`n" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

        }
    }
}

function Stop-ProcessInDirectory {
    param (
        [string]$directory,
        [string]$processName
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"   
    #    Stop-Process -Name $processName
    #   return 
    ##下面的还有问题
    
    # 获取特定目录下的进程
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($directory) } | Sort-Object StartTime -Descending | Select-Object -First 1

    # 停止该进程
    if ($process) {
        Stop-Process -Id $process.Id -Force
        Write-Output "[$timestamp] Process in $directory stopped successfully." | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    }
    else {
        Write-Output "[$timestamp] No matching process found in $directory. Start Force stop all $processName" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        Stop-Process -Name $processName -Force 
    }
}

function Get-ListeningPortsByProcessName {
    param (
        [string]$processName,
        [string]$externalJoinIP,
        [bool]$isGetProcessId = $false
    )

<#    
    $listeningPorts = Get-NetUDPEndpoint -LocalAddress "0.0.0.0"
    $procId = 0
    $joinCommand = ""
    # 遍历这些连接
    foreach ($conn in $listeningPorts) {
        $procId = $conn.OwningProcess
        $localPort = $conn.LocalPort
        $process = Get-Process -Id $procId -ErrorAction SilentlyContinue

        # 检查进程名是否匹配        
        if ($process -and $process.Name -eq $processName) { 
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $joinCommand = "open $externalJoinIP`:$localPort"          
            #Write-Output "[$timestamp] 加入命令： $joinCommand. " 
            if ($joinCommand -notmatch "62169") {
                $outputString = "`r`n[$timestamp] 游戏服务端已经启动，但检测端口发现不是默认的62169，如果你也没有修改过端口配置，【那可能是配置文件出问题了，去这个目录(..\Rumbleverse\Binaries\Win64\Config.ini)删除配置文件,关了当前窗口再开脚本试一次，还不行就运行 [服务器设置(改模式和等待时间).请先运行这个再开服.bat] 这个后再重新运行开服脚本.】 `r`n"
                Write-Host $outputString | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            }
            break
        }
    }
#>
    #通过路径获取服务器端进程并且获取端口
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($gameRootPath) } | Sort-Object StartTime -Descending | Select-Object -First 1

    if ($process) {
        $listeningPorts = Get-NetUDPEndpoint -LocalAddress "0.0.0.0" | Where-Object { $_.OwningProcess -eq $process.Id }
        $listeningPort = $listeningPorts | Select-Object -ExpandProperty LocalPort
        
        if($listeningPort -ne $null) {
            $joinCommand = "open $externalJoinIP`:$listeningPort"
            Write-Output "[$timestamp] Process $processName is listening on port $listeningPort.1" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            Write-Host "[$timestamp] Process $processName is listening on port $listeningPort.2" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
            if ($joinCommand -notmatch "62169") {
                $warningMessage = "`r`n[$timestamp] 游戏服务端已经启动，但检测端口发现不是默认的62169，如果你也没有修改过端口配置，【那可能是配置文件出问题了，去这个目录(..\Rumbleverse\Binaries\Win64\Config.ini)删除配置文件,关了当前窗口再开脚本试一次，还不行就运行 [服务器设置(改模式和等待时间).请先运行这个再开服.bat] 这个后再重新运行开服脚本.】 `r`n"

            }
        }
        else {   
            Write-Output "[$timestamp] process not listening any udp port." | Tee-Object -FilePath $guardian_rumbleverse_log -Append         
        }
        #获取服务端进程id,用来后面重开结束
        if ($isGetProcessId) {
            return $process
        }
        else {
            return @{
                JoinCommand = $joinCommand
                WarningMessage = $warningMessage
            }
        }
    } 
    else {
        Write-Output "[$timestamp] No matching process found." | Tee-Object -FilePath $guardian_rumbleverse_log -Append

    }      
    # 获取进程信息 调用示例
    #Get-ListeningPortsByProcessName -processName "YourProcessName" -externalJoinIP $externalIP -isGetProcessId $true
}




while ($true) {
    $isRoundEnd = $false

    # 检查进程是否闪退
    if (!(CheckProcessRunning)) {    
        # 写入闪退日志
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $crashLog = "[$timestamp] Program not run or crash exit."       
        Write-Output $crashLog | Tee-Object -FilePath $guardian_rumbleverse_log -Append
   
        RestartGameServer        
        continue
    }
   
    $logCheckresult = CheckLogFile
    if ($logCheckresult -eq "ServerUnliving_SheikErrorLog") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$timestamp] ServerUnliving_SheikErrorLog" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
   
        #Stop-Process -Name $processName -Force 
        Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
        Start-Sleep -Seconds 8
        RestartGameServer
        continue
    } 
    elseif ($logCheckresult -eq "CreatePartyFailed") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$timestamp] CreatePartyFailed" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
   
        Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
        Start-Sleep -Seconds 8
        RestartGameServer        
        continue
    } 
    elseif ($logCheckresult -eq "RoundFinished") {
        $isRoundEnd = $true 
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$timestamp] 这一局已经正常结束,接下如果没有开启延迟10分钟重开则会自动结束服务端游戏进程重新开始,预计2分钟后可以起来(请先在控制台输入命令open Island_P_2进入单机模式以保留衣服，等起来后再加入.否则掉出来需要重启游戏客户端重新穿衣服). RoundFinished." | Tee-Object -FilePath $guardian_rumbleverse_log -Append
    }   
    elseif ($logCheckresult -eq "够人单排了") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$timestamp] 够人单排了" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
        Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
        Start-Sleep -Seconds 5
        RestartGameServer        
        continue
    }     
    elseif ($logCheckresult -eq "restartNow") {
        Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
        Start-Sleep -Seconds 8
        RestartGameServer        
        continue
    }
    else {
        Start-Sleep -Seconds 20
    }
   
    # 检查控制文件
    if (Test-Path $controlFilePath) {
        # 读取控制文件的值
        $controlValue = Get-Content -Path $controlFilePath
   
        # 判断控制值是否满足退出条件
        if ($controlValue -like "*exit*") {
            # 写入退出日志
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $exitLog = "[$timestamp] Program exited by user."
            Write-Output $exitLog | Tee-Object -FilePath $guardian_rumbleverse_log -Append
   
            # 退出脚本
            break
        }
        elseif ($controlValue -like "*sleep*") {
            Start-Sleep -Seconds 180
            continue
        }
        elseif ($controlValue -like "*stop auto start*") {
            # 写入退出日志
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $exitLog = "[$timestamp] stop auto start new round by user."
            Write-Output $exitLog | Tee-Object -FilePath $guardian_rumbleverse_log -Append
   
            Start-Sleep -Seconds 180
            continue
        }
        elseif ($controlValue -like "*delay auto start*") {
            if ($isRoundEnd) {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Output "[$timestamp] 已经开启延迟10分钟重开，目前是自由模式（要关闭请修改control.txt里面的内容改为：delay# auto start）。 delay 10 min auto start" | Tee-Object -FilePath $guardian_rumbleverse_log -Append

                $isRerunging = $false
                $startTime = Get-Date
                while ((Get-Date) - $startTime -lt (New-TimeSpan -Minutes 10)) {                   
                    Start-Sleep -Seconds 40
                    if (!(CheckProcessRunning)) {    
                        # 写入闪退日志
                        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        $crashLog = "[$timestamp] Program not run or crash exit during delay term."       
                        Write-Output $crashLog | Tee-Object -FilePath $guardian_rumbleverse_log -Append

                        RestartGameServer    
                        $isReRunging = $true    
                        break
                    }
                    else {
                        Start-Sleep -Seconds 30
                    }
                }
                if (!$isReRunging -and (CheckProcessRunning)) {    
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Write-Output "[$timestamp] now begin auto start in delay term" | Tee-Object -FilePath $guardian_rumbleverse_log -Append
                    Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
                    Start-Sleep -Seconds 3
                    RestartGameServer        
                }
                continue
            }
        }
        else {
            if ($isRoundEnd) {                
                Stop-ProcessInDirectory -directory $gameRootPath -processName $processName
                Start-Sleep -Seconds 8
                RestartGameServer        
                continue
            }
            else {
                # 默认处理逻辑
            }
        }
    }  
}