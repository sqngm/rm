# Service.ps1
[cmdletbinding()] Param($Port = 62174)
 
$VerbosePreference = "Continue"
# 值或取`SilentlyContinue`，此时需调用脚本时传入`-Verbose`才等效`Continue`。
# `Continue`输出`Write-Verbose`的内容。
 
Write-Verbose("Check port {0} busy/available" -f $Port)
$Connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if($Connection){
    if($Connection.OwningProcess.GetType().Name -eq "UInt32"){
        $Process_ID = $Connection.OwningProcess
    }
    else{
        $Process_ID = $Connection.OwningProcess[1]
        # `$Connection.OwningProcess`为数组对象(System.Object)
    }
    if($Process_ID){
        Write-Error("Port {0} is busy, using by process ID {1}." -f $Port, $Process_ID)
        Exit
    }
    else{
        Write-Verbose("Port {0} is available" -f $Port)
    }
}
else{
    Write-Verbose("Port {0} is available" -f $Port)
}
$Connection = $Null
 
$Listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $Port
try{
    $Listener.Start()
    # 可能的异常：
    # # "通常每个套接字地址(协议/网络地址/端口)只允许使用一次。"
    # # CategoryInfo          : NotSpecified: (:) [], ParentContainsErrorRecordException
    # # FullyQualifiedErrorId : SocketException
    Write-Verbose("Start linsten.")
}
catch {
    Write-Error("Linsten failed.")
    throw
}
 
Write-Verbose "Server started."
 
While ($True) {
    Write-Host("Waiting connection from port {0}" -f $Port)
 
    $Socket_TCP_Client = $Listener.AcceptTcpClient()
    # incoming socket tcp client endpoint.
    
    $Client_Address = $Socket_TCP_Client.client.RemoteEndPoint.ToString()
	Write-Verbose ("New connection from {0}" -f $Client_Address)
 
	# Start-Sleep -Milliseconds 1000
 
	$Stream = $Socket_TCP_Client.GetStream()
    $Stream.ReadTimeout = 1000 # ms
    # [NetworkStream.ReadTimeout Property](https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.networkstream.readtimeout?view=net-8.0)
    $Stream_Reader = [System.IO.StreamReader]::new($Stream)
    $Stream_Writer = New-Object System.IO.StreamWriter($Stream)
 
    $Previous_Communication_Time = Get-Date -UFormat %s
 
    $string = $Null
	While ($Socket_TCP_Client.Connected) {
        Write-Verbose "Try to read line."
        try{
            $string = $Stream_Reader.ReadLine()
        }
        catch{
            # 可能的异常：
            # # 使用“0”个参数调用“ReadLine”时发生异常:“无法从传输连接中读取数据: 由于连接方在一段时间后没有正确答复或连接的主机没有反应，连接尝试失败。。”
            # # 使用“0”个参数调用“ReadLine”时发生异常:“无法从传输连接中读取数据: 你的主机中的软件中止了一个已建立的连接。。”
            Write-Verbose "Timeout, waiting data."
        }
 
        if($string -eq "exit"){
            Write-Verbose "Exit."
 
            $Stream_Reader.Dispose()
            Write-Verbose "Stream_Reader.Dispose done."
            $Stream_Reader.Close()
            Write-Verbose "Stream_Reader.Close done."
 
            $Stream_Writer.Dispose()
            Write-Verbose "Stream_Writer.Dispose done."
            $Stream_Writer.Close()
            Write-Verbose "Stream_Writer.Close done."
 
            $Stream.Dispose()
            Write-Verbose "Stream.Dispose done."
            $Stream.Close()
            Write-Verbose "Stream.Close done."
            
            $Socket_TCP_Client.Dispose()
            Write-Verbose "Socket_TCP_Client.Dispose done."
            $Socket_TCP_Client.Close()
            Write-Verbose "Socket_TCP_Client.Close done."
 
            break
        }
        if ($string) {
            Write-Verbose "Data available, line read."
            Write-Host("Message received from {0}:`n {1}" -f $Client_Address, $string)
 
            $Previous_Communication_Time = Get-Date -UFormat %s
            
            $Path = $string
            $string = $Null
 
            $Is_Path_Exist_Folder = $Null
            try{
                $Is_Path_Exist_Folder = Test-Path -Path $Path -PathType Container
                # 可能的异常：
                # # "Test-Path : 路径中具有非法字符。"
            }catch{}
            if($Is_Path_Exist_Folder){
                Write-Verbose "Path valid - Path is a folder."
            }
            else{
                Write-Verbose "Path invalid - Path is not a folder, skip."
            }
 
            if($Is_Path_Exist_Folder){
                Write-Verbose "Measure size (length) of folder.."
                $Command = 'Get-ChildItem -Path "'+ $Path + '" -Recurse | Measure-Object -Property Length -Sum'
                $GenericMeasureInfo = Invoke-Expression $Command
                $Size = $GenericMeasureInfo.Sum
                Write-Verbose("Folder size (length) is {0}." -f $Size)
			    
                Write-Verbose "Send size to client."
                $Stream_Writer.WriteLine($Size)
                $Stream_Writer.Flush()
            }
            else{
                Write-Verbose "Send error code to client."
			    $Stream_Writer.WriteLine("")
                $Stream_Writer.Flush()
            }
		}
        ElseIf((($Current_Time = (Get-Date -UFormat %s)) - $Previous_Communication_Time) -gt 3){ #等待数据超时，检查断线
            $bytes = 0
            try{ #heart-beat
                Write-Verbose "Heart-beat test."
                # 参见：[(16)Powershell中的转义字符 - yang-leo - 博客园](https://www.cnblogs.com/leoyang63/articles/12060596.html)
                $Stream_Writer.WriteLine("")
                $Stream_Writer.Flush()
                $Previous_Communication_Time = $Current_Time
                Write-Verbose("Connection {0} alive." -f $Client_Address)
            }catch{
                Write-Verbose("Connection {0} failed." -f $Client_Address)
                break
            }
        }
	}
    if($string -eq "exit"){
        break
    }else{
        Write-Host "Client disconnect."
    }
}
 
$Listener.Stop()
Write-Verbose "Listener.Stop done."
Write-Verbose "Server stopped."
 
Write-Host "Exit."
Exit