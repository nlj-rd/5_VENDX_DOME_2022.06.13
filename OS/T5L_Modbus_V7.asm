    ;DWIN OS 
    ;T5 MODBUS V7 20190513 19:11	;
    ;R10寄存器以被Modbus程序占用，用户禁止使用
	ORG 1000H
  	GOTO SYS_Init	;代码的第一条指令必须是GOTO指令跳转到初始化或者主程序
  	GOTO T0INT		;中断定时器0服务程序入口，必须用GOTO跳转
	NOP				;中断定时器1服务程序入口，NOP指令表示未使用
  	NOP				;中断定时器2服务程序入口
  	
	ORG 1080H
SYS_Init:
;	CALL MODBUS_SET			;MODBUS参数配置，用于测试（也可用于从OS配置MODBUS）
    CALL UART_Init			;串口初始化
    CALL Constant_Init		;常量初始化（应用程序版本号）
    CALL TIMER0_Init		;中断定时器0初始化
	CALL TIMER0_Enable	;使能中断定时器0
	CALL EA_Enable		;开定时器总中断
	GOTO MAIN
;中断定时器0服务程序	
T0INT:
	;保护现场	
	LDBR R10,7,1			;此为第0页的R10寄存器	
	MOVRD R10,0,1
	;第7页寄存器作为Modbus状态变量空间，其他地方禁用		
	IJNE R19,1,T0INT_NEXT	;MODBUS_RW_STA=1，表示指令已发送
		INC R20,1,1			;MODBUS_Cnt,单位mS 
		;超时检测
		IJNE R34,0,2
		IJNE R35,0,1
			LDWR R34,60
	JS R20,R34,T0INT_NEXT	;当前指令等待时间,最大值为9999mS
		;清零相关参数，进入下一条指令
		LDBR R18,0,4
		LDBR R30,0,16
T0INT_NEXT:     
	;恢复现场
	LDBR R10,0,1		;此为第7页的R10寄存器
	MOVRD R10,0,1
	RETI				;中断返回，必须用RETI指令
;主函数        
MAIN:
	CALL Modbus_Master	;主机Modbus程序
	CALL Modbus_Slave	;从机Modbus程序
        
	CALL MY_MAIN
	

	GOTO MAIN  

MODBUS_SET:
	LDWR R0,Modbus_EN	;MODBUS启用标记
	LDWR R60,5AA5H		;0x5AA5=启用，其他=不启用	
	LDWR R62,0		;主从机标记，0=主机，1=从机
	LDWR R64,1152		;串口波特率，115200bps
	LDWR R66,0		;串口模式，8N1
	LDWR R68,5AH		;从机设备地址
	MOVXR R60,0,5
	;
	LDADR MODBUS_CMD1_TAB	;第一条指令表
	MOVC R60,16
	LDWR R0,Modbus_CMD1
	MOVXR R60,0,8
	;
	LDADR MODBUS_CMD2_TAB
	MOVC R60,16
	LDWR R0,Modbus_CMD1
	INC R0,1,8
	MOVXR R60,0,8
	;
	LDADR MODBUS_CMD3_TAB
	MOVC R60,16
	LDWR R0,Modbus_CMD1
	INC R0,1,16
	MOVXR R60,0,8
	RET
        
UART_Init:
	;UART4配置，详见<基于T5CPU的DWIN OS程序开发指南>
	LDWR R0,Modbus_EN	;Modbus启用标记
        MOVXR R60,1,1
        LDWR R62,5AA5H
        TESTS R60,R62,2
        IJNE R0,0,UART_Init_RET
	;Modbus_EN=0x5AA5,启用Modbus，从0xE002读取串口配置信息
        LDBR R20,40H,1		;串口4
        LDWR R0,Modbus_UART	;0xE002-E003为串口配置参数
        MOVXR R60,1,2
        LDWR R70,4
        JU R62,R70,1		;R63为串口模式设置参数，设置范围0-3
	    LDWR R62,0
        OR R20,R63,1
        LDWR R64,0
        TESTS R60,R64,2
        IJNE R0,0,1
			LDWR R60,1152	;若波特率设定值为0，则恢复默认波特率
        LDBR R70,0,8
        MOV R60,R70,2		;波特率设置值，单位*100bps
        LDWR R72,100
        SMAC R70,R72,R74
        LDBR R70,0,4
        LDBR R80,0,8
        LDWR R84,0189H
        LDWR R86,C000H		;0x0189C000=25804800
        DIV R80,R70,0
        MOV R86,R21,2
        COMSET R20,0
UART_Init_RET:        	
        RET
        
TIMER0_Init:
	;定时参数设置
	LDBR R20,100,1		;100*10uS=1mS
	MOVRD R20,46,1		;DR46=Timer INT0 Set	
        RET
        
        
TIMER0_Enable:
	;开定时器0中断
	MOVDR 45,R20,1		;DR45=Int_Reg
	LDBR R21,40H,1		;Int_Reg.6=Timer INT0 Enable
	OR R20,R21,1
	MOVRD R20,45,1
	RET
	
TIMER0_Disable:
	;关定时器0中断
	MOVDR 45,R20,1
	LDBR R21,BFH,1
	AND R20,R21,1
	MOVRD R20,45,1
	RET
        
EA_Enable:
	;开定时器总中断
	MOVDR 45,R20,1
	LDBR R21,80H,1		;Int_Reg.7=EA
	OR R20,R21,1
	MOVRD R20,45,1
	RET
	
EA_Disable:
	;关定时器总中断
	MOVDR 45,R20,1
	LDBR R21,7FH,1
	AND R20,R21,1
	MOVRD R20,45,1
	RET

Constant_Init:
	;将版本号保存在变量空间，方便从串口读取
	LDADR Version_TAB
	MOVC R20,2
	LDWR R0,Mdobus_Ver
	MOVXR R20,0,1
	RET
        
Modbus_Master:
	LDWR R0,Modbus_EN		;Modbus启用标记,5AA5H表示启用Modbus_Master
	MOVXR R60,1,1
	IJNE R60,5AH,Modbus_Master_RET
	IJNE R61,A5H,Modbus_Master_RET     
	LDWR R0,Modbus_Mode		;Modbus主从机模式
	MOVXR R60,1,1
	IJNE R61,0,Modbus_Master_RET
	;Modbus主机
	RDXLEN 4,R18		;读串口4接收缓冲区字节长度
	IJNE R18,0,Modbus_Master_Rx
	;0x00表示接收缓冲区没有数据，可以发送
		GOTO Modbus_Master_Tx
Modbus_Master_Rx:
	MOVDR 17,R19,1   	;DR17表示串口4接收帧超时定时器状态 
	IJNE R19,0,Modbus_Master_RET
	;DR17=0x00表示一帧数据接收完成
	CALL TIMER0_Disable			;停止定时器0中断
	RDXDAT 4,R20,R18	;读取串口缓冲区数据到R20开始的寄存器
	DEC R18,0,2
	CRCA R20,R16,R18	;计算CRC16校验值,结果存放在R16:R17
	MOV R16,R254,2
	LDBR R238,0,8		;R238-253，16个寄存器
	LDWR R240,20		;数据帧起始位置
	MOV R18,R245,1		;帧长度-校验位
	ADD R238,R242,R246
	MOV R253,R2,1		;数据帧中CRC校验值存放位置
	LDBR R3,18,1
	LDBR R9,2,1
	MOVA
	CJNE R254,R18,MODBUS_MasterRx_ERR
	CJNE R255,R19,MODBUS_MasterRx_ERR
	;校验正确，数据帧存放的寄存器空间为R20-R199，最长180字节
        LDWR R0,MODBUS_CMD_Buff	;当前16字节指令缓存区
        LDWR R2,240
        LDBR R9,16,1
        MOVA 1
        CJNE R241,R20,MODBUS_MasterRx_ERR
        ;站号匹配
        IJNE R21,1,2
        ;从机响应0x01指令
			CALL MODBUS_MasterRx_CMD01
            GOTO MODBUS_MasterRx_END
        IJNE R21,2,2
        ;从机响应0x02指令
			CALL MODBUS_MasterRx_CMD01	;0x02指令响应内容与0x01类似,数据存储格式为LSB
            GOTO MODBUS_MasterRx_END
        IJNE R21,3,2
        ;从机响应0x03指令
			CALL MODBUS_MasterRx_CMD03	;0x03指令响应,数据存储格式为MSB
            GOTO MODBUS_MasterRx_END
        IJNE R21,4,2
        ;从机响应0x04指令
			CALL MODBUS_MasterRx_CMD03	;0x04指令响应内容与0x03类似
            GOTO MODBUS_MasterRx_END
        IJNE R21,7,2
        ;从机响应0x07指令
			CALL MODBUS_MasterRx_CMD07
            GOTO MODBUS_MasterRx_END
        IJNE R21,5,1
			GOTO MODBUS_MasterRx_END
        IJNE R21,6,1
			GOTO MODBUS_MasterRx_END
        IJNE R21,0FH,1
			GOTO MODBUS_MasterRx_END 
        IJNE R21,10H,MODBUS_MasterRx_ERR      
MODBUS_MasterRx_END:
	;当前指令已完成收发，下一条指令不再延时，准备直接发送
	MOV R244,R60,2
	LDWR R0,60
	LDWR R2,MODBUS_Cnt
	LDBR R9,2,1
	MOVA 1
	LDWR R100,FFH		;通信成功
	CALL MODBUS_STA_FeedBack
	CALL TIMER0_Enable
	GOTO Modbus_Master_RET
MODBUS_MasterRx_ERR:
	LDWR R100,0		;通信失败
	CALL MODBUS_STA_FeedBack
	CALL TIMER0_Enable
	GOTO Modbus_Master_RET
	
Modbus_Master_Tx:
	CALL TIMER0_Disable			;停止定时器0中断
	LDWR R0,MODBUS_STA			;MODBUS指令状态，0表示可以进入下一条指令，1表示正在计时
	LDWR R2,60
	LDBR R9,1,1
	MOVA 1
	IJNE R60,0,Modbus_MasterTx_NEXT
	CALL Modbus_Master_CMDCheck	;检测并依次读取有效指令
	IJNE R50,0,1
		GOTO Modbus_Master_END
	;当前指令有效
	LDBR R60,1,1	;MODBUS指令状态标记置1
	LDBR R61,0,1	;MODBUS_RW_STA
	LDWR R0,60
	LDWR R2,MODBUS_STA
	LDBR R9,2,1
	MOVA 1
Modbus_MasterTx_NEXT:
	;MODBUS_RW_STA=0表示可以发送指令，1表示上一条指令已发送并正在延时
	LDWR R0,MODBUS_RW_STA
	LDWR R2,60
	LDBR R9,1,1
	MOVA 1
	IJNE R60,0,Modbus_Master_END
	LDWR R0,MODBUS_CMD_Buff		;当前16字节发送指令缓存区
	LDWR R2,20
	LDBR R9,16,1
	MOVA 1
	IJNE R27,2,Modbus_MasterTx_NEXT1
	;0x02模式，直接发送
		CALL Modbus_Master_TXD
	LDBR R60,0,8
	LDWR R0,MODBUS_SP	;当前指令指针，表示第N条指令，0<=N<=1022
	LDWR R2,60			;目标寄存器地址
	LDBR R9,2,1			;交换的字节长度
	MOVA 1				;寄存器数据交换（跨寄存器页）        
	LDWR R62,8			;每条指令占8个字
	SMAC R60,R62,R64	;SP*8为指令偏移字数
	LDBR R70,0,12
	LDWR R72,Modbus_CMD1	;第一条指令的起始地址
	ADD R70,R64,R74
	MOV R80,R0,2		;第N条指令的起始地址
	;预先读取下一条待发送指令，判断是否为0x02模式且同一个变量触发的指令
	MOVXR R70,1,8
	IJNE R70,5AH,Modbus_MasterTx02Mode_CLR			;判断指令是否有效
	IJNE R77,2,Modbus_MasterTx02Mode_CLR	;判断是否为02模式
	CJNE R78,R28,Modbus_MasterTx02Mode_CLR
	CJNE R79,R29,Modbus_MasterTx02Mode_CLR	;判断是否与当前指令为同一个变量触发
		;当存在连续的多条指令为同一个变量触发时，暂不清零变量
		GOTO Modbus_Master_END
Modbus_MasterTx02Mode_CLR:
	MOV R28,R0,2
	LDWR R60,0		;发送完成后将VP变量内容清零,防止重复发送本条指令
	MOVXR R60,0,1
	GOTO Modbus_Master_END
Modbus_MasterTx_NEXT1:
	CALL Modbus_Master_TXD	;执行当前指
Modbus_Master_END:		
	CALL TIMER0_Enable
Modbus_Master_RET:
    RET

MODBUS_MasterRx_CMD01:
	LDBR R200,0,16
	MOV R22,R207,1	;字节数，存在单数
	LDWR R214,2
	DIV R200,R208,0
	IJNE R215,0,1
		GOTO MODBUS_MasterRx_CMD01_NEXT
	;单数字节，末位字节填0
	LDWR R200,0
	LDWR R0,200
	MOV R22,R2,1
	INC R2,0,23		;R23+字节数=需要填0的寄存器地址
	LDBR R9,1,1
	MOVA
	INC R207,0,1
MODBUS_MasterRx_CMD01_NEXT:
	MOV R207,R9,1	;字数
	MOV R250,R0,2	;变量存储空间首地址
	MOVXR R23,0,0
	RET

MODBUS_MasterRx_CMD03:
	LDBR R200,0,16
	MOV R22,R207,1	;字节数
	LDWR R214,2
	DIV R200,R208,0          
	MOV R207,R9,1	;字数
	MOV R250,R0,2	;变量存储空间首地址
	MOVXR R23,0,0
	RET
        
MODBUS_MasterRx_CMD07:
;从机响应内容：站号 功能码 异常状态高位 异常状态低位 CRCL CRCH
	MOV R250,R0,2	;变量存储地址
	MOVXR R22,0,1
	RET

MODBUS_STA_FeedBack:
	;总线通信状态反馈，用户读取通信状态反馈字后应清零	
	LDBR R60,0,16
	LDWR R0,MODBUS_SP
	LDWR R2,62
	LDBR R9,2,1
	MOVA 1
	JU R60,R62,2
	;R62:R63=0，上一刻发送的是第1022条指令（最后一条）
		LDWR R62,1022
		GOTO MODBUS_FeedBack_NEXT
        DEC R62,1,1	;上一刻发送的是第N条指令，N=0~1021
MODBUS_FeedBack_NEXT:
	LDWR R60,8	;一条指令占8个字
	SMAC R60,R62,R64
	LDBR R60,0,4
	LDWR R62,Modbus_CMD1
	ADD R60,R64,R68	;SP(Modbus_CMD1)+N*8=当前指令首地址
	LDBR R60,0,12
	LDWR R70,7
	ADD R68,R72,R60	;当前指令首地址+0x07=总线通信状态反馈地址
	MOV R66,R0,2
	MOVXR R100,0,1       
	RET              
        
Modbus_Master_CMDCheck:
	;R50=0表示无有效指令，1表示有待发送指令
	;R20-35为当前待发送指令
	LDBR R50,0,1		;清空R50寄存器 
	LDBR R60,0,8
	LDWR R0,MODBUS_SP	;当前指令指针，表示第N条指令，0<=N<=1022
	LDWR R2,60		;目标寄存器地址
	LDBR R9,2,1		;交换的字节长度
	MOVA 1			;寄存器数据交换（跨寄存器页）        
	LDWR R62,8		;每条指令占8个字
	SMAC R60,R62,R64	;SP*8为指令偏移字数
	LDBR R70,0,12
	LDWR R72,Modbus_CMD1	;第一条指令的起始地址
	ADD R70,R64,R74
	MOV R80,R0,2		;第N条指令的起始地址
	MOVXR R20,1,8
	INC R60,1,1		;指令指针N+1
	LDWR R100,1023
	JU R60,R100,MM_CMDCheck_NEXT
	;第1022条指令检测完毕
		LDWR R60,0                      
MM_CMDCheck_NEXT: 
	LDWR R0,60
	LDWR R2,MODBUS_SP	;保存下一条指令指针N
	LDBR R9,2,1
	MOVA 1
	IJNE R20,5AH,MM_CMDCheck_RET	;若当前指令无效，则退出，等待下一周再检测下一条指令
	IJNE R23,0,1
	    ;读写数据长度=0，本条指令无效
	    GOTO MM_CMDCheck_RET
        IJNE R27,1,MM_CMDCheck_NEXT1
	    ;0x01模式，在指定页面下执行
            LDWR R0,PIC_Now	;当前页面ID
            MOVXR R200,1,1
            TESTS R200,R28,2
            IJNE R0,0,MM_CMDCheck_RET
			GOTO MM_CMDCheck_NEXT2
MM_CMDCheck_NEXT1: 
	IJNE R27,2,MM_CMDCheck_NEXT2
	;0x02模式，仅在指向的变量低字节为0x5A时才执行
		MOV R28,R0,2
		MOVXR R200,1,1
		IJNE R201,5AH,MM_CMDCheck_RET	 
MM_CMDCheck_NEXT2:
	LDWR R200,0
	LDWR R202,180		;数据长度上限，180字节=90字
	MOV R23,R201,1		;读写数据长度
	JU R202,R200,MM_CMDCheck_RET
	LDBR R200,0,16
	MOV R30,R202,2		;读写数据在VP空间的起始地址
	MOV R23,R207,1		;读写数据长度
	ADD R200,R204,R208
	LDWR R208,DFFFH		;VP空间可读写上限
	JU R208,R214,MM_CMDCheck_RET
		;本条指令有效
		LDWR R0,20
		LDWR R2,MODBUS_CMD_Buff	;将待发送的指令内容写入到发送缓冲区
		LDBR R9,16,1
		MOVA 1
		LDBR R50,1,1
MM_CMDCheck_RET:
	RET
        
Modbus_Master_TXD:
	;发送状态置1，表明已经发送
	LDBR R60,1,1
	LDWR R0,60
	LDWR R2,MODBUS_RW_STA
	LDBR R9,1,1
	MOVA 1
	;执行指令
	MOV R21,R60,2	;ID+功能码
        IJNE R22,1,2
        ;0x01，读取输入线圈状态
	    CALL Modbus_Master_CMD01	
	    GOTO Modbus_MasterTXD_RET	;发送指令后，等待从机回复再进入下一条指令      
	IJNE R22,2,2
        ;0x02，读取输入位变量状态
	    CALL Modbus_Master_CMD01	;0x02指令除了功能码以外，其余和0x01指令内容一样
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,3,2
        ;0x03，读取保持寄存器数据
	    CALL Modbus_Master_CMD03
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,4,2        
        ;0x04，读取输入寄存器数据
	    CALL Modbus_Master_CMD03	;0x04指令除功能码外和0x03指令相同
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,7,2        
        ;0x07，读取异常状态
	    CALL Modbus_Master_CMD07
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,5,2        
        ;0x05，强置单个线圈
	    CALL Modbus_Master_CMD05
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,6,2        
        ;0x06，预置单个寄存器
	    CALL Modbus_Master_CMD05	;0x06指令除功能码外和0x05指令相同
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,0FH,2      
        ;0x0F，强置多个线圈
	    CALL Modbus_Master_CMD0F
	    GOTO Modbus_MasterTXD_RET
	IJNE R22,10H,Modbus_MasterTXD_RET        
        ;0x10，预置多个寄存器
	    CALL Modbus_Master_CMD10
Modbus_MasterTXD_RET:   
        RET
        
Modbus_Master_CMD01:        
;站号ID 功能码 起始地址高位 起始地址低位 总位数高位 总位数低位 CRCL CRCH
	MOV R32,R62,2	;起始地址
	LDBR R40,0,8
	MOV R23,R41,1	;待读取数据长度=线圈个数/8
	LDWR R42,8
	SMAC R40,R42,R44 ;总位数（线圈个数）=待读取数据长度*8
	MOV R46,R64,2	;总位数
	LDBR R40,6,1
	CRCA R60,R66,R40 ;LSB
	INC R40,0,2
	COMTXD 4,R60,R40  
	RET
        
Modbus_Master_CMD03:        
;站号ID 功能码 起始地址高位 起始地址低位 总寄存器数高位 总寄存器数低位 CRCL CRCH              
	MOV R32,R62,2	;起始地址
	LDBR R40,0,16
	MOV R23,R47,1	;待读取数据长度=寄存器数*2
	LDWR R54,2
	DIV R40,R48,0	;总寄存器数=待读取数据长度/2
	MOV R46,R64,2	;总寄存器数
	LDBR R40,6,1
	CRCA R60,R66,R40 ;LSB
	INC R40,0,2
	COMTXD 4,R60,R40
	RET
       
Modbus_Master_CMD05:
;站号ID 功能码 线圈地址高位 线圈地址低位 强制状态高位 强制状态低位 CRCL CRCH
	MOV R32,R62,2	;线圈地址
	MOV R30,R0,2	;存放线圈状态的变量地址
	MOVXR R64,1,1
	LDBR R40,6,1
	CRCA R60,R66,R40 ;LSB
	INC R40,0,2
	COMTXD 4,R60,R40
	RET

Modbus_Master_CMD07:
;站号ID 功能码 CRCL CRCH
	LDBR R40,2,1
	CRCA R60,R62,R40
	INC R40,0,2
	COMTXD 4,R60,R40
	RET
        
Modbus_Master_CMD0F:
;站号ID 功能码 线圈地址高位 线圈地址低位 线圈数量高位 线圈数量低位 字节数 n*(线圈状态高位 线圈状态低位) CRCL CRCH
	MOV R32,R62,2	;线圈地址
	LDBR R64,0,1
	MOV R23,R65,1	;线圈数量
	LDBR R40,0,16
	MOV R23,R47,1
	LDWR R54,8		;1字节=8个线圈
	DIV R40,R48,0
	IJNE R55,0,1
	;余数为0，则字节数正确
		GOTO Modbus_MasterCMD0F_NEXT
	;余数不为0，则字节数+1	(剩余线圈数量不足1个字节时，补齐1个字节，未使用的位需要填0)
	INC R47,0,1
Modbus_MasterCMD0F_NEXT:
	MOV R47,R66,1	;字节数
	MOV R47,R9,1
	MOV R30,R0,2	;线圈状态存放的变量地址
	MOVXR R67,1,0
	INC R47,0,7
	CRCA R60,R58,R47 ;CRC校验值结果存放在R58:59
	LDBR R40,0,16
	LDWR R42,60		;目标寄存器起始地址
	MOV R66,R47,1	;写入字节数
	INC R47,0,7		;数据长度
	ADD R40,R44,R48
	LDBR R2,58,1
	MOV R55,R3,1	;CRC校验在数据帧中的位置=起始地址+数据长度
	LDBR R9,2,1
	MOVA 
	INC R47,0,2	;数据长度+2字节校验值=数据帧长度
	COMTXD 4,R60,R47
	RET        
       
Modbus_Master_CMD10:
;站号ID 功能码 起始地址高位 起始地址低位 寄存器总数高位 寄存器总数低位 寄存器总字节数 n*（寄存器值高位 寄存器值低位） CRCL CRCH
	MOV R32,R62,2	;起始地址
	LDBR R40,0,8
	MOV R23,R47,1	;字节数
	LDBR R50,0,8
	LDWR R56,2
	DIV R40,R50,0
	MOV R46,R64,2	;寄存器总数
	MOV R23,R66,1	;寄存器总字节数
	MOV R30,R0,2	;待写入变量起始地址
	MOV R65,R9,1	;数据字长度（1-94）
	MOVXR R67,1,0
	INC R23,0,7
	CRCA R60,R58,R23 ;CRC校验值结果存放在R58:59
	LDBR R40,0,16
	LDWR R42,60	;目标寄存器起始地址
	MOV R23,R47,1	;数据长度
	ADD R40,R44,R48
	LDBR R2,58,1
	MOV R55,R3,1	;CRC校验在数据帧中的位置=起始地址+数据长度
	LDBR R9,2,1
	MOVA 
	INC R47,0,2	;数据长度+2字节校验值=数据帧长度
	COMTXD 4,R60,R47
	RET         
       
Modbus_Slave:
	LDWR R0,Modbus_EN		;Modbus启用标记
	MOVXR R60,1,1
	LDWR R62,5AA5H
	TESTS R60,R62,2
	IJNE R0,0,Modbus_Slave_RET
	LDWR R0,Modbus_Mode		;Modbus主从机模式
	MOVXR R60,1,1
	IJNE R61,0,1
	GOTO Modbus_Slave_RET
	;Modbus从机
	CALL ModbusSlave_ID_Check	;设备ID检测
	RDXLEN 4,R18		;读串口4接收缓冲区字节长度
	IJNE R18,0,Modbus_Slave_Rx
	;0x00表示没有数据 
	GOTO Modbus_Slave_RET
Modbus_Slave_Rx:
	MOVDR 17,R19,1   	;DR17表示串口4接收帧超时定时器状态 
	IJNE R19,0,Modbus_Slave_RET
	;DR17=0x00表示一帧数据接收完成
	RDXDAT 4,R20,R18	;读取串口缓冲区数据到R20-199的寄存器空间
	MOV R18,R237,1
	DEC R237,0,2
	CRCA R20,R16,R237	;计算CRC16校验值,结果存放在R16:R17
	MOV R16,R254,2
	LDBR R238,0,8		;R238-253，16个寄存器
	LDWR R240,20		;数据帧起始位置
	MOV R237,R245,1		;帧长度-校验位
	ADD R238,R242,R246
	MOV R253,R2,1		;数据帧中CRC校验值存放位置
	LDBR R3,238,1
	LDBR R9,2,1
	MOVA
	CJNE R254,R238,Modbus_SlaveRx_ERR
	CJNE R255,R239,Modbus_SlaveRx_ERR
        ;校验正确
        LDWR R0,Modbus_SlaveID
        MOVXR R250,1,1
        CJNE R20,R251,Modbus_SlaveRx_ERR
        ;站号匹配
	IJNE R21,03H,Modbus_SlaveRx_CMD06
	;0x03指令,读取VP变量空间
	    LDWR R250,90	;单次最多读写90个字
	    JU R250,R24,Modbus_SlaveRx_ERR		;R24:25存放的是寄存器总数，即字数
	    LDBR R240,0,16
		MOV R22,R242,2	;VP变量起始地址
		MOV R24,R246,2	;变量字数
		ADD R240,R244,R248
		LDWR R250,DFFFH	;变量可读写范围：0x0000~0xDFFF
		JU R250,R254,Modbus_SlaveRx_ERR
	    MOV R22,R0,2	;起始地址
		MOV R25,R9,1	;读取字数
		MOVXR R23,1,0
		LDWR R244,2
		LDBR R240,0,4
		SMAC R244,R246,R240
		MOV R243,R22,1	;待返回的寄存器字节数
		MOV R22,R255,1
		INC R255,0,3
		CRCA R20,R250,R255	;校验值存放在R250:251
		LDBR R230,0,16
		LDWR R232,20
		MOV R255,R237,1
		ADD R230,R234,R238	;CRC校验应存放的位置=数据帧首地址+帧数据长度
		LDBR R2,250,1
		MOV R245,R3,1
		LDBR R9,2,1
		MOVA 
		INC R255,0,2	;待发送数据帧总长度
		COMTXD 4,R20,R255
		GOTO Modbus_Slave_RET  
Modbus_SlaveRx_CMD06:
	IJNE R21,06H,Modbus_SlaveRx_CMD10
        ;0x06指令，写单个VP变量
	    LDWR R240,DFFFH
		JU R240,R22,Modbus_SlaveRx_ERR
		MOV R22,R0,2	;目标变量
		MOVXR R24,0,1
		COMTXD 4,R20,R18	;原指令返回
		GOTO Modbus_Slave_RET
Modbus_SlaveRx_CMD10:
	IJNE R21,10H,Modbus_SlaveRx_ERR
        ;0x10指令，写VP变量空间
	    LDWR R250,90	;单次最多读写90个字
	    JU R250,R24,Modbus_SlaveRx_ERR		;R24:25存放的是寄存器总数，即字数
	    LDBR R240,0,16
		MOV R22,R242,2	;VP变量起始地址
		MOV R24,R246,2	;变量字数
		ADD R240,R244,R248
		LDWR R250,DFFFH	;变量可读写范围：0x0000~0xDFFF
		JU R250,R254,Modbus_SlaveRx_ERR
		MOV R22,R0,2	;目标变量起始地址
		MOV R25,R9,1	;写入变量字数
		MOVXR R27,0,0
		LDBR R255,6,1
		CRCA R20,R250,R255
		MOV R250,R26,2
		LDBR R18,8,1
		COMTXD 4,R20,R18
		GOTO Modbus_Slave_RET
Modbus_SlaveRx_ERR:
	LDBR R250,0x80,1
	OR R21,R250,1		;将功能码最高位置1，并返回给主机，表示错误信息
	MOV R18,R255,1
	DEC R255,0,2
	CRCA R20,R250,R255
	LDBR R230,0,16
	LDWR R232,20
	MOV R255,R237,1
	ADD R230,R234,R238	;计算校验值存放位置
	LDBR R2,250,1
	MOV R245,R3,1
	LDBR R9,2,1
	MOVA 
	COMTXD 4,R20,R18
Modbus_Slave_RET:
	RET           

ModbusSlave_ID_Check:
	;若设备ID被错误地设置为0，则恢复默认值
	LDWR R0,Modbus_SlaveID
	MOVXR R60,1,1
	LDWR R62,0
	CJNE R60,R62,MSID_Check_RET
	CJNE R61,R63,MSID_Check_RET
	LDWR R60,5AH
	MOVXR R60,0,1
MSID_Check_RET:        
	RET
         
Version_TAB:
	DW 0407H	

MODBUS_CMD1_TAB:
	DB 5AH		;0x5A=本条指令有效，其他表示无效
	DB 04H		;读写的MODBUS设备地址
	DB 03H		;读写的MODBUS指令
	DB 20		;读写数据长度，0x00表示本条指令无效
	DW 50		;指令等待时间，单位mS
	DB 0		;未定义
	DB 0		;指令操作模式，0x01=指定页面下执行，0x02=指定变量低字节内容为0x5A才执行（执行完自动清零），其他表示总是执行
	DW 0		;Page_ID或VP地址
	DW 1400H	;数据变量存储地址（VP）
	DW 00H		;MODBUS设备寄存器地址
	DW 0		;总线通信状态反馈
MODBUS_CMD2_TAB:
	DB 5AH, 01H, 03H, 20, 0, 50, 0, 0, 0, 0, 15H, 00H, 0, 00H, 0, 0
	
MODBUS_CMD3_TAB:
	DB 5AH, 03H, 03H, 20, 0, 50, 0, 0, 0, 0, 16H, 00H, 0, 00H, 0, 0	
	
	
	
	
	
	
	
	
	
;=================================MY_MAIN================================	

	MY_MAIN:

	
	 LDWR R0,0X1001
	 LDWR R40,0X005A
	 MOVXR R40,0,1
	
	 LDWR R0,0X1002
	 LDWR R40,0XFF00
	 MOVXR R40,0,1
	 
	 LDWR R0,0X1000
	 LDWR R40,0X0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0X1003
	 LDWR R40,0X0001
	 MOVXR R40,0,1
	 
	 	 	
	 LDWR R0,0x20e2    
	 LDWR R50,1 
	 MOVXR R50,0,1
	 
	 
	 CALL FLASH_Read	 		 ;
	 CALL Sys_Hand_Main
	 CALL Main_interface_Reads
	 CALL Processing_interface
	 CALL FILE_interface_Reads
	 CALL Reset_Jump
	 CALL WIFI_SET				 ;
	 CALL Lock_screen
	 CALL Work_Setting
     CALL Screen_Setting
     CALL JOG_Setting
     CALL INF0_Setting
     CALL INF0_Password
     CALL SERVICE_INF0


	 CALL Alarm_OS         	 	 ;报警
	 
;	 CALL Border_crossing_alarm
;	 CALL Open_cover_protection_KEY
;	 CALL Open_cover_protection
;
     RET





FLASH_Read:

	 IJNE R252,0,res_end  ;通常习惯用R255寄存器做标志位，上电只读一次
     LDBR R252,1,1
     
     

	;数据地址0x001500 存放的是语言地址
	 LDWR R0,0x0008  	  ;数据库 
     LDWR R40,0x5A00      ;数据库读操作D7:D6(H)  5A为读， A5为写
     LDWR R42,0x1500      ;读取数据库地址001500 D5D4
     LDWR R44,0x2030      ;读到0x2030 D3D2     
     LDWR R46,2           ;读取2个字长度 D1 
     MOVXR R40,0,4
     
     
     LDWR R0,0x2030       ;读取到数据库的值 
     MOVXR R50,1,1
     MOV R50,R120,2    	  ;将读到的值放入R120
     

  
LOOP1:               ;判断数据库读操作是否完成
     LDWR R0,0x0008
     MOVXR R40,1,1
     IJNE R40,0,LOOP1	  ;如果未完成，等待
     
	 LDWR R0,0x2030  	  ;读取完毕后，判断在FLASH里的寄存器的值是0或1若都不是，初始化为0
	 MOVXR R40,1,1   
     IJNE R41,0X00,res_lnit	
	 RET
res_lnit:
	 LDWR R0,0x2030  ;
	 MOVXR R40,1,1   
     IJNE R41,0X01,res_lnit_01	
	 RET
res_lnit_01:
	 LDWR R0,0x2030  ;     ;第一次烧录工程时，设定为默认语言，写入系统数据库，仅在第一次烧录工程
	 LDWR R40,0
	 MOVXR R40,0,1  
	 
		
	
      LDWR R0,0008H		   ;0x0008为系统数据库变量地址
	  LDWR R40,0xA500      ;数据库写操作
	  LDWR R42,1500H       ;写到数据库地址001500
	  LDWR R44,0x2030      ;需要保存的数据的VP为4444H
	  LDWR R46,2           ;保存2个字数据
	  MOVXR R40,0,4
	  
	       
     LDWR R0,0x2030        ;数据库 
     MOVXR R50,1,1
     MOV R50,R120,2        ;把写入的值保存到R120中
     

res_end:
	RET



Sys_Hand_Main:

	 LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	 MOVXR R40,1,1
	 IJNE R41,0,Sys_hand_not_0Pages  	  ;是否在0界面
	 
	 LDWR R0,0x3090			  ;是否握手成功
	 MOVXR R40,1,1	 
	 IJNE R41,1,Sys_hand_not_error  	  ;

	 LDWR R0,0x20C3			;关闭查询	  	
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x100E			;图标动画  	
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 LDWR R0,0x100A		    ;图标动画  	
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	
	 LDWR R0,0x100C			;图标动画  	
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 

	 
	 ;如果握手成功，开始关闭握手查询指令并开始发送复位指令
	 CALL Sys_Reset_Main
	 
	 RET
	 
Sys_hand_not_error:
	 
	 LDWR R0,0x3090			  ;是否握手成功
	 MOVXR R40,1,1	
	 IJNE R41,0,Sys_hand_break  
	 
	 LDWR R0,0x20C3			  ;modbus 查询握手状态  	
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x100E			;图标动画  	
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x100A		    ;图标动画  	
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	
	 LDWR R0,0x100C			;图标动画  	
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 RET
Sys_hand_not_0Pages:
Sys_hand_break:
	RET
	
Sys_Reset_Main:


	LDWR R0,0x1FF1				  ;复位按键开关
	MOVXR R40,1,1
	IJNE R41,0,Sys_Reset_break  	 

	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,0,Sys_Reset_break  	  ;是否在0界面
 
	LDWR R0,0x2082			;
	LDWR R40,0x005A
	MOVXR R40,0,1

	LDWR R0,0x1FF2
    MOVXR R50,1,1
    IJNE R51,0X01,Sys_Reset_Main_Null;查询复位完成的标志位是否为1
    
    
    	
    LDWR R0,0x2080			;关闭写入
	LDWR R40,0x0000
	MOVXR R40,0,1

    LDWR R0,0x1FF2			;完成置位
    LDWR R40,0x0000
    MOVXR R40,0,1
    
    LDWR R0,0x2082			;关闭查询
	LDWR R40,0x0000
	MOVXR R40,0,1

	
	LDWR R0,0x1FF0			;写入复位标志
	LDWR R40,0x0000
	MOVXR R40,0,1
	
	
	LDWR R0,0x2080			;
	LDWR R40,0x0000
	MOVXR R40,0,1
	
	
	LDWR R0,0x0084						;标志位为1跳转到主界面
    LDWR R40,0x5A01
    LDWR R42,1
    MOVXR R40,0,2
    
    LDWR R0,0x1FF1		;
	LDWR R40,0x0001
	MOVXR R40,0,1
    
		
	LDWR R0,0x100A		;图标动画  	
	LDWR R40,0x0001
	MOVXR R40,0,1
	
	LDWR R0,0x100C			;图标动画  	
	LDWR R40,0x0001
	MOVXR R40,0,1
	
	LDWR R0,0x100E			;图标动画  	
	LDWR R40,0x0002
	MOVXR R40,0,1
 
 
;    LDWR R0,0x2030
;    MOVXR R50,1,1
;    IJNE R51,0X00,Sys_Reset_Main_en;查询语言 为中文或英文
; 
;    LDWR R0,0x0084						;标志位为1跳转到中文主界面
;    LDWR R40,0x5A01
;    LDWR R42,6
;    MOVXR R40,0,2
 
    RET
 
;Sys_Reset_Main_en:
;    LDWR R0,0x2030
;    MOVXR R50,1,1
;    IJNE R51,0X01,Sys_Reset_Main_Null;查询语言 为中文或英文
; 
;    LDWR R0,0x0084						;标志位为1跳转到英文主界面
;    LDWR R40,0x5A01
;    LDWR R42,31
;    MOVXR R40,0,2
; 
;    RET

Sys_Reset_Main_Null:

	LDWR R0,0x1FF1				  
	MOVXR R40,1,1
	IJNE R41,0,Sys_Reset_break 


	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,0,Sys_Reset_break  	  ;是否在0界面

	LDWR R0,0x1FF2
    MOVXR R50,1,1
    IJNE R51,0X00,Sys_Reset_break;查询复位开关的标志位是否为1
    
	LDWR R0,0x1FF0
    MOVXR R50,1,1
    IJNE R51,0X00,Sys_Reset_query;查询复位完成的标志位是否为1
    
	LDWR R0,0x2080			;写入复位
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x1FF0			;写入复位标志
	LDWR R40,0x0001
	MOVXR R40,0,1
	
	LDWR R0,0x100A			;图标动画  	
	LDWR R40,0x0000
	MOVXR R40,0,1
   
	LDWR R0,0x100C			;图标动画  	
	LDWR R40,0x0000
	MOVXR R40,0,1
	
	LDWR R0,0x100E			;图标动画  	
	LDWR R40,0x0002
	MOVXR R40,0,1
    
	Sys_Reset_query:
    RET
    Sys_Reset_break:
    RET	
    
    
    
Main_interface_Reads:

	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,1,Main_interface_break  	  ;是否在0界面

		
	LDWR R0,0x2068					
	LDWR R40,0x005A
	MOVXR R40,0,1
	

 
 NAME_1:
 
 	CALL X/Y/Z_control		  ;轴按压方式
	CALL X/Y/Z_control_main	  ;轴运动过程处理

	CALL X/Y/Z_RESET		  ;轴复位
	
	LDWR R0,0x2042			;
	MOVXR R50,1,1
	IJNE R51,0x5A,Axis_is_moving  ;是否轴空闲
	
;	LDWR R0,0x2062			
;	LDWR R60,0x005A
;	MOVXR R60,0,1
	
			
	LDWR R0,0x2066		
	LDWR R60,0x005A
	MOVXR R60,0,1
	
		
	LDWR R0,0x2068		
	LDWR R60,0x005A
	MOVXR R60,0,1

 
	CALL Progress_Main		  ;进度条
    CALL Stop_processing	  ;停止 
    CALL File_status		  ;文件状态 
 
    RET    
Main_interface_break:


    RET
    
Axis_is_moving:

	LDWR R0,0x2066		
	LDWR R60,0x0000
	MOVXR R60,0,1
	
			
	LDWR R0,0x2068		
	LDWR R60,0x0000
	MOVXR R60,0,1    
	
	RET



FILE_interface_Reads:



	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,3,FILE_interface_break  	  ;是否在3界面


	LDWR R0,0x2070					;打开读文件总数
	LDWR R40,0X005A
	MOVXR R40,0,1
	 


	CALL FILE_OS_Total_pages			;文件处理     
	CALL FILE_OS_Current_number    
	CALL FILE_OS_Number
	CALL FILE_OS_KEY
	CALL FILE_OS_KEY_Modbus

	RET
FILE_interface_break:
    RET	   
    
X/Y/Z_control:
  
  
	LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,50 			;x坐标值100 
	LDWR  R42,550 			;x坐标值360
	LDWR  R44,500 			;y坐标值400
	LDWR  R46,835 			;y坐标值650
 
	JS R52,R40,X/Y/Z_KEY_3	;判断按压是否在+号范围里
	JS R42,R52,X/Y/Z_KEY_3
	JS R54,R44,X/Y/Z_KEY_3
	JS R46,R54,X/Y/Z_KEY_3  

	IJNE R51,0x01,X/Y/Z_KEY_1;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	LDWR R0,0x2048			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
	  	  	
	RET
	
	

X/Y/Z_KEY_1:
	IJNE R51,0x03,X/Y/Z_KEY_2;按键长按
  
	LDWR R0,0x2044			  ;0x2044标志置为1
	LDWR R60,0x0001
	MOVXR R60,0,1
	
	LDWR R0,0x2048			  ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1
	
		
	
	RET
	
	X/Y/Z_KEY_2:
	IJNE R51,0x02,X/Y/Z_KEY_3;按键抬起
  
	LDWR R0,0x2048			;0x2048标志置为1
	LDWR R60,0x0001
	MOVXR R60,0,1
	
	LDWR R0,0x2044			;0x2044标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1
	
	LDWR R0,0x2046			;0x2044标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1
	

	RET
  
X/Y/Z_KEY_3:				;若其他情况，标志位置零
  
  	LDWR R0,0x2048		
	LDWR R60,0x0000
	MOVXR R60,0,1
	
	LDWR R0,0x2044	
	LDWR R60,0x0000
	MOVXR R60,0,1	
	
	LDWR R0,0x2046		
	LDWR R60,0x0000
	MOVXR R60,0,1
	

    RET
  
  
X/Y/Z_control_main:		;通过按键状态，进行判断与控制
  

  
    LDWR R0,0x2046	 ;按下
    MOVXR R40,1,1
    IJNE R41,0x01,X/Y/Z_No_First_KEY  
   
    LDWR R0,0x2042
    LDWR R50,0
    MOVXR R50,0,1
    
;   LDWR R0,0x2015        ;主界面读功率
;   LDWR R50,0
;   MOVXR R50,0,1
;   
;   LDWR R0,0x2017		 ;主界面读速度
;   LDWR R50,0
;   MOVXR R50,0,1
   
    LDWR R0,0x2050		 
    LDWR R50,0x005A
    MOVXR R50,0,1   

   
   
    RET
X/Y/Z_No_First_KEY:
    LDWR R0,0x2044	
    MOVXR R40,1,1
    IJNE R41,0x01,X/Y/Z_No_KEY  
   

   
    LDWR R0,0x2042
    LDWR R50,0
    MOVXR R50,0,1
    
;   LDWR R0,0x2015        ;主界面读功率
;   LDWR R50,0
;   MOVXR R50,0,1
;   
;   LDWR R0,0x2017		 ;主界面读速度
;   LDWR R50,0
;   MOVXR R50,0,1
;

    LDWR R0,0x2050		 
    LDWR R50,0x005A
    MOVXR R50,0,1
   
    RET

X/Y/Z_No_KEY:   
 
    LDWR R0,0x2050		 
    LDWR R50,0
    MOVXR R50,0,1
   
	
    LDWR R0,0x2012	
    MOVXR R40,1,1
   
    LDWR R0,0x2003	
    MOVXR R42,1,1
   
    LDWR R0,0x200E	
    MOVXR R44,1,1
   
    LDWR R0,0x2007	
    MOVXR R46,1,1
   
    LDWR R0,0x2009	
    MOVXR R48,1,1
   
    LDWR R0,0x2014	
    MOVXR R50,1,1
   
    LDWR R0,0x2005	
    MOVXR R52,1,1
   
    LDWR R0,0x2010	
    MOVXR R54,1,1
    
    IJNE R41,0x00,X/Y/Z_KEY_END   
    IJNE R43,0x00,X/Y/Z_KEY_END   
    IJNE R45,0x00,X/Y/Z_KEY_END   
    IJNE R47,0x00,X/Y/Z_KEY_END   
    IJNE R49,0x00,X/Y/Z_KEY_END   
    IJNE R51,0x00,X/Y/Z_KEY_END   
    IJNE R53,0x00,X/Y/Z_KEY_END 
    IJNE R55,0x00,X/Y/Z_KEY_END   
  
	
    LDWR R0,0x2042
    LDWR R50,0x005A
    MOVXR R50,0,1
   
	
    LDWR R0,0x2044		
    LDWR R60,0x0000
    MOVXR R60,0,1
	
    LDWR R0,0x2046		
    LDWR R60,0x0000
    MOVXR R60,0,1
   
    LDWR R0,0x2050		 
    LDWR R50,0x005A
    MOVXR R50,0,1
   
    RET
	
	
	

 
 X/Y/Z_KEY_END: 
 

  
  LDWR R0,0x2042
  LDWR R50,0x0000
  MOVXR R50,0,1
  
      
;  LDWR R0,0x2015        ;主界面读功率
;  LDWR R50,0x0000 
;  MOVXR R50,0,1
;
;  LDWR R0,0x2017		 ;主界面读速度
;  LDWR R50,0x0000
;  MOVXR R50,0,1
	
	
   LDWR R0,0x2050		 
   LDWR R50,0x0000
   MOVXR R50,0,1


  RET     
    
    
X/Y/Z_RESET:
	 LDWR R0,0x1016
	 MOVXR R40,1,1
	 IJNE R41,0X01,X/Y/Z_RESET_NULL;是否按下
	 LDWR R0,0x1016			   		   ;按下置0
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	  ;停止
	 LDWR R0,0x2001			       ;0x2001写005a，触发modbus指令发送
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x3010					;修改启动图标
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	;复位
	 LDWR R0,0x200A			       ;0x200A写005a，触发modbus指令发送
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x0084						;
	 LDWR R40,0x5A01
	 LDWR R42,0X0001
	 MOVXR R40,0,2
	 
	 
	 RET

X/Y/Z_RESET_NULL:

	 RET   
 
Processing_interface:


	 LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	 MOVXR R40,1,1
	 IJNE R41,2,Processing_break  	  ;是否在界面
	 
	 LDWR R0,0x2066			       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 	 
	 LDWR R0,0x2050		       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2064			       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2068			       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x20CD			       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 
	 ;读IO状态
	 
	 	 
	 LDWR R0,0x20D0			       ;
	 LDWR R40,0x005A
	 MOVXR R40,0,1

	 
	 
	 CALL File_status
	 CALL Progress_Main		  ;进度条
	 CALL Stop_processing	  ;停止 
	 CALL Button_state
	 
	 LDWR R0,0x101C					;读工作状态数据处理
	 MOVXR R40,1,1
	 IJNE R40,0X00,Processing_break ;状态不为0：空闲，跳转
	 IJNE R41,0X05,Processing_break ;状态不为0：空闲，跳转
	 
	 LDWR R0,0x0084						;
	 LDWR R40,0x5A01
	 LDWR R42,0X0001
	 MOVXR R40,0,2
	 RET
Processing_break:	 
	 RET   
     
     
Button_state:

Button_1:

	 LDWR R0,0x10b1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_2
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x10A1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_1
	 
	 LDWR R0,0x10A1			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_1_sent
	 
	 RET
	 
Button_ADD1_1:	 
	 
	 LDWR R0,0x10A1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_ADD2_1
	 
	 LDWR R0,0x10A1			     ;按键状态复位
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 CALL Button_1_sent
	 
	 RET

Button_ADD2_1:
 
	 LDWR R0,0x10A1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_ADD3_1
	 
	 LDWR R0,0x10A1			     ;按键状态复位
	 LDWR R40,0x0003
	 MOVXR R40,0,1
	 
	 CALL Button_1_sent
	 
	 RET
	 
Button_ADD3_1:
 
	 LDWR R0,0x10A1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_1_Break
	 
	 LDWR R0,0x10A1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_1_sent
	 
	 RET
Button_1_sent:
	 
	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D1		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET   
Button_1_Break:    
     RET
     
Button_2:

	 LDWR R0,0x10b1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_3
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x10A2				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_2
	 
	 LDWR R0,0x10A2			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_2_sent
	 
	 RET

Button_ADD1_2:
	 LDWR R0,0x10A2				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_ADD2_2
	 
	 LDWR R0,0x10A2			     ;按键状态复位
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 CALL Button_2_sent
	 
	 RET
	 
Button_ADD2_2:
	 LDWR R0,0x10A2				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_ADD3_2
	 
	 LDWR R0,0x10A2			     ;按键状态复位
	 LDWR R40,0x0003
	 MOVXR R40,0,1
	 
	 CALL Button_2_sent
	 
	 RET

Button_ADD3_2:
	 LDWR R0,0x10A2				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_2_Break
	 
	 LDWR R0,0x10A2			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_2_sent
	 
	 RET
	 
Button_2_sent:	 
	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D2		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET  
     
Button_2_Break:    
     RET
     
Button_3:

	 LDWR R0,0x10b1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_4
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 
	 LDWR R0,0x10A3				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_3
	 
	 LDWR R0,0x10A3			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_3_sent
	 
	 RET

Button_ADD1_3:
	 LDWR R0,0x10A3				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_ADD2_3
	 
	 LDWR R0,0x10A3			     ;按键状态复位
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 CALL Button_3_sent
	 
	 RET
	 
Button_ADD2_3:
	 LDWR R0,0x10A3				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_ADD3_3
	 
	 LDWR R0,0x10A3			     ;按键状态复位
	 LDWR R40,0x0003
	 MOVXR R40,0,1
	 
	 CALL Button_3_sent
	 
	 RET

Button_ADD3_3:
	 LDWR R0,0x10A3				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_3_Break
	 
	 LDWR R0,0x10A3			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_3_sent
	 
	 RET
	 
Button_3_sent:	 


	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D3		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET  
     
Button_3_Break:    
     RET     
     
Button_4:

	 LDWR R0,0x10b1				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X04,Button_5
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 
	 LDWR R0,0x10A4				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_4
	 
	 LDWR R0,0x10A4			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_4_sent
	 
	 RET

Button_ADD1_4:
	 LDWR R0,0x10A4				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_ADD2_4
	 
	 LDWR R0,0x10A4			     ;按键状态复位
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 CALL Button_4_sent
	 
	 RET
	 
Button_ADD2_4:
	 LDWR R0,0x10A4				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_ADD3_4
	 
	 LDWR R0,0x10A4			     ;按键状态复位
	 LDWR R40,0x0003
	 MOVXR R40,0,1
	 
	 CALL Button_4_sent
	 
	 RET

Button_ADD3_4:
	 LDWR R0,0x10A4				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_4_Break
	 
	 LDWR R0,0x10A4			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_4_sent
	 
	 RET
	 
Button_4_sent:	 	 
	 
	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D4		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET
Button_4_Break:
     RET     
     
Button_5:

	 LDWR R0,0x10b1			;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X05,Button_6
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 
	 LDWR R0,0x10A5				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_5
	 
	 LDWR R0,0x10A5			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_5_sent
	 
	 RET

Button_ADD1_5:
	 LDWR R0,0x10A5				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_ADD2_5
	 
	 LDWR R0,0x10A5			     ;按键状态复位
	 LDWR R40,0x0002
	 MOVXR R40,0,1
	 
	 CALL Button_5_sent
	 
	 RET
	 
Button_ADD2_5:
	 LDWR R0,0x10A5				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X02,Button_ADD3_5
	 
	 LDWR R0,0x10A5			     ;按键状态复位
	 LDWR R40,0x0003
	 MOVXR R40,0,1
	 
	 CALL Button_5_sent
	 
	 RET

Button_ADD3_5:
	 LDWR R0,0x10A5				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X03,Button_5_Break
	 
	 LDWR R0,0x10A5			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_5_sent
	 
	 RET
	 
Button_5_sent:	
	 
	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D5		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET
Button_5_Break:

	 RET
	 
Button_6:

	 LDWR R0,0x10b1			;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X06,Button_break
	 
	
	 LDWR R0,0x10b1			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 
	 LDWR R0,0x10A6				;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X00,Button_ADD1_6
	 
	 LDWR R0,0x10A6			     ;按键状态复位
	 LDWR R40,0x0001
	 MOVXR R40,0,1
	 
	 CALL Button_6_sent
	 
	 RET

Button_ADD1_6:
	 LDWR R0,0x10A6			;读按键状态
	 MOVXR R40,1,1
	 IJNE R41,0X01,Button_6_Break
	 
	 LDWR R0,0x10A6			     ;按键状态复位
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 CALL Button_6_sent
	 
	 RET
Button_6_sent:	 
	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x0000
	 MOVXR R40,0,1

     LDWR R0,0x20D6		       ;开启发送	     
	 LDWR R40,0x005a
	 MOVXR R40,0,1

     RET
     
Button_6_Break:
     RET
     
Button_break:

	 LDWR R0,0x20D0		       ;关闭查询	     
	 LDWR R40,0x005A
	 MOVXR R40,0,1
     RET
  
Progress_Main:
	 LDWR R0,0x1030
	 MOVXR R42,1,1
	  
	 LDWR R44,0x0063 ;99
	 JS R42,R44,progress_END
	  
	 LDWR R44,0x00C7 ;199
	 JS R42,R44,progress_8
	  
	 LDWR R44,0x012B ;299
	 JS R42,R44,progress_16
	  
	 LDWR R44,0x018F ;399
	 JS R42,R44,progress_24
	  
	 LDWR R44,0x01F3 ;499
	 JS R42,R44,progress_32
	  
	 LDWR R44,0x0257 ;599
	 JS R42,R44,progress_40
	 
	 LDWR R44,0x02BB ;699
	 JS R42,R44,progress_48
	  
	 LDWR R44,0x031F ;799
	 JS R42,R44,progress_56
	  
	 LDWR R44,0x0383 ;899	
     JS R42,R44,progress_64
	  
     LDWR R44,0x03E7 ;999
	 JS R42,R44,progress_72
	  
	 LDWR R44,0x044B ;1099
	 JS R42,R44,progress_80
	  

	  
	 LDWR R0,0x302A
	 LDWR R46,0x000D
	 MOVXR R46,0,1
	  
	 RET
	  
  
  progress_80:
  
     LDWR R0,0x302A
     LDWR R46,0x000A
     MOVXR R46,0,1
  
     RET
  
  progress_72:
  
     LDWR R0,0x302A
     LDWR R46,0x0009
     MOVXR R46,0,1
  
     RET
  
  progress_64:
  
     LDWR R0,0x302A
     LDWR R46,0x0008
     MOVXR R46,0,1
  
  RET
  
  progress_56:
  
     LDWR R0,0x302A
     LDWR R46,0x0007
     MOVXR R46,0,1
  
     RET
  
  progress_48:
  
     LDWR R0,0x302A
     LDWR R46,0x0006
     MOVXR R46,0,1
  
     RET
  
  progress_40:
  
     LDWR R0,0x302A
     LDWR R46,0x0005
     MOVXR R46,0,1
  
     RET
  
  progress_32:
  
     LDWR R0,0x302A
     LDWR R46,0x0004
     MOVXR R46,0,1
  
     RET
  
  progress_24:
  
     LDWR R0,0x302A
     LDWR R46,0x0003
     MOVXR R46,0,1
  
     RET
  
  progress_16:
  
     LDWR R0,0x302A
     LDWR R46,0x0002
     MOVXR R46,0,1
  
     RET
 
  progress_8:
  
     LDWR R0,0x302A
     LDWR R46,0x0001
     MOVXR R46,0,1
  
     RET
  
  progress_END:
  
     LDWR R0,0x302A
     LDWR R46,0x0000
     MOVXR R46,0,1
  
     RET
 
 
 



Stop_processing:
	 LDWR R0,0x1011
	 MOVXR R40,1,1
	 IJNE R41,0X01,Stop_processing_NULL;是否按下
	 LDWR R0,0x1011			   		   ;按下置0
	 LDWR R40,0x0000
	 MOVXR R40,0,1

	 LDWR R0,0x2001			       ;0x2001写005a，触发modbus指令发送
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x3010					;修改启动图标
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 RET

Stop_processing_NULL:
RET
	
	
File_status:

     LDWR R0,0x101C					;读工作状态数据处理
	 MOVXR R40,1,1
	 IJNE R40,0X00,File_status_No_0 ;状态不为0：空闲，跳转
	 IJNE R41,0X00,File_status_No_0 ;状态不为0：空闲，跳转

	 LDWR R0,0x301C					;汉字“空闲的GBK”显示
	 LDWR R60,0x4944                ;ID
	 LDWR R62,0x4C45				;LE
	 LDWR R64,0x0000
	 LDWR R66,0x0000
	 MOVXR R60,0,4 ;将0xb6af写入0x301C
	 
	 
	 LDWR R0,0x3010
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2064
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x1021
	 LDWR R40,0x0000
	 LDWR R42,0x0000
	 LDWR R44,0x0000
	 MOVXR R40,0,3
	 
	 LDWR R0,0x1030
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	; 
	; LDWR R0,0x2068					
	; LDWR R40,0x0000
	; MOVXR R40,0,1
	; 
	 
	 
	 
	 RET

	File_status_No_0:


	 LDWR R0,0x101C					;读工作状态数据处理
	 MOVXR R40,1,1
	 IJNE R40,0X00,File_status_No_1 ;状态不为1：加工，跳转
	 IJNE R41,0X01,File_status_No_1 ;状态不为1：加工，跳转
	 
	 LDWR R0,0x301C					;汉字“空闲的GBK”显示
	 LDWR R60,0x4255                ;BU
	 LDWR R62,0x5359				;SY
	 LDWR R64,0x0000
	 LDWR R66,0x0000
	 MOVXR R60,0,4 ;将0xb6af写入0x301C
	 
	 LDWR R0,0x3010
	 LDWR R40,0x0001
	 MOVXR R40,0,1 
	 
	 LDWR R0,0x2064
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2068					
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
 
	 
	 
	 RET
	 
	 
	 
	File_status_No_1:


	 LDWR R0,0x101C					;读工作状态数据处理
	 MOVXR R40,1,1
	 
	 IJNE R40,0X00,File_status_No_2 ;状态不为0x003：暂停，跳转
	 IJNE R41,0X03,File_status_No_2 ;状态不为0x003：暂停，跳转
	 

	 LDWR R0,0x301C					;汉字“暂停GBK”显示
	 LDWR R60,0x5041                ;PA
	 LDWR R62,0x5553				;US
	 LDWR R64,0x4500				;E
	 LDWR R66,0x0000
	 MOVXR R60,0,4 ;将0xb6af写入0x301C
	 
	 LDWR R0,0x3010
	 LDWR R40,0x0000
	 MOVXR R40,0,1 
	 
	 LDWR R0,0x2064
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2068					
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	 
	 
	 
	 
	 RET
	 
	File_status_No_2:

	 LDWR R0,0x101C					;读工作状态数据处理
	 MOVXR R40,1,1
	 
	 IJNE R40,0X00,File_status_No_3 ;状态不为0x005：停止，跳转
	 IJNE R41,0X05,File_status_No_3 ;状态不为0x005：停止，跳转
	 

	 LDWR R0,0x301C					;汉字“空闲的GBK”显示
	 LDWR R60,0x5354                ;ST
	 LDWR R62,0x4F50				;OP
	 LDWR R64,0x0000				;
	 LDWR R66,0x0000
	 MOVXR R60,0,4 ;将0xb6af写入0x301C
	 
	 
	 LDWR R0,0x3010					;若为停止，将启动图标置位
	 LDWR R50,0x0000
	 MOVXR R50,0,1
	 
	 LDWR R0,0x2064
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x1021
	 LDWR R40,0x0000
	 LDWR R42,0x0000
	 LDWR R44,0x0000
	 MOVXR R40,0,3
	 
	 LDWR R0,0x1030
	 LDWR R40,0x0000
	 MOVXR R40,0,1
	 
	 LDWR R0,0x2068					
	 LDWR R40,0x005A
	 MOVXR R40,0,1
	  
	 
	 File_status_No_3:
	 File_status_END:RET

FILE_OS_Total_pages:  
 LDWR R0,0x1031				 ;读文件总数
 MOVXR R40,1,1
 
 LDWR R42,0X0000 ;0
 JS  R40,R42,file_number_over_0 ;文件数小于等于0
 LDWR R42,0X0008 ;8
 JS  R40,R42,file_number_over_8 ;文件数大于等于10
 LDWR R42,0X000F; 15
 JS  R40,R42,file_number_over_15 ;文件数大于等于15
 LDWR R42,0X0016 ;22
 JS  R40,R42,file_number_over_22 ;文件数大于等于22
 LDWR R42,0X001D; 29
 JS  R40,R42,file_number_over_29 ;文件数大于等于29
 LDWR R42,0X0024 ;36
 JS  R40,R42,file_number_over_36 ;文件数大于等于36
 LDWR R42,0X002B; 43
 JS  R40,R42,file_number_over_43 ;文件数大于等于43
 LDWR R42,0X0032 ;50
 JS  R40,R42,file_number_over_50 ;文件数大于等于50
 LDWR R42,0X0039; 57
 JS  R40,R42,file_number_over_57 ;文件数大于等于57
 LDWR R42,0X0040; 64
 JS  R40,R42,file_number_over_64 ;文件数大于等于64
 LDWR R42,0X0047; 71
 JS  R40,R42,file_number_over_71 ;文件数大于等于71
 LDWR R42,0X004E; 78
 JS  R40,R42,file_number_over_78 ;文件数大于等于78
 LDWR R42,0X0055; 85
 JS  R40,R42,file_number_over_85 ;文件数大于等于85
 LDWR R42,0X005C; 92
 JS  R40,R42,file_number_over_92 ;文件数大于等于92
 LDWR R0,0x304F		  ;总页面设为12页		
 LDWR R40,15		
 MOVXR R40,0,1 
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,99
 LDWR R0,0x3050	      
 MOVXR R40,0,1
 RET
 

file_number_over_0:
 LDWR R0,0x304F		  ;总页面设为0页(从0开始)		
 LDWR R40,1		
 MOVXR R40,0,1 
 
 LDWR R0,0x3050	
 LDWR R40,0
 MOVXR R40,0,1
RET

file_number_over_8:  ;文件数小于8 第一页
 LDWR R0,0x304F		  ;总页面设为1页		
 LDWR R40,1		
 MOVXR R40,0,1 
 LDWR R0,0x1031		  
 MOVXR R42,1,1
 LDWR R0,0x3050	
 MOVXR R42,0,1
 RET
 
file_number_over_15:  ;文件数小于15
 LDWR R0,0x304F		  ;总页面设为2页		
 LDWR R40,2		
 MOVXR R40,0,1 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,7
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
  
file_number_over_22:  ;文件数小于22
 LDWR R0,0x304F		  ;总页面设为3页		
 LDWR R40,3	
 MOVXR R40,0,1 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,14
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
file_number_over_29:  ;文件数小于29
 LDWR R0,0x304F		  ;总页面设为4页		
 LDWR R40,4	
 MOVXR R40,0,1
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,21
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
 file_number_over_36:  ;文件数小于36
 LDWR R0,0x304F		  ;总页面设为4页		
 LDWR R40,5
 MOVXR R40,0,1
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,28
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
 file_number_over_43:  ;文件数小于43
 LDWR R0,0x304F		  ;总页面设为6页		
 LDWR R40,6
 MOVXR R40,0,1
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,35
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
 file_number_over_50:  ;文件数小于50
 LDWR R0,0x304F		  ;总页面设为7页		
 LDWR R40,7
 MOVXR R40,0,1
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,42
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
 file_number_over_57:  ;文件数小于57
 LDWR R0,0x304F		  ;总页面设为8页		
 LDWR R40,8
 MOVXR R40,0,1
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,49
 LDWR R0,0x3050	
 MOVXR R40,0,1
 RET
 
 
 file_number_over_64:  ;文件数小于64

 LDWR R0,0x304F		  ;总页面设为8页		
 LDWR R40,9
 MOVXR R40,0,1
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,56
 LDWR R0,0x3050	
 MOVXR R40,0,1
 
 RET
 
 file_number_over_71:  ;文件数小于91

 LDWR R0,0x304F		  ;总页面设为10页		
 LDWR R40,10
 MOVXR R40,0,1
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,63
 LDWR R0,0x3050	
 MOVXR R40,0,1
 
 RET
 
 file_number_over_78:  ;文件数小于78

 LDWR R0,0x304F		  ;总页面设为10页		
 LDWR R40,11
 MOVXR R40,0,1
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,71
 LDWR R0,0x3050	
 MOVXR R40,0,1
 
 RET
 
 file_number_over_85:  ;文件数小于85

 LDWR R0,0x304F		  ;总页面设为10页		
 LDWR R40,12
 MOVXR R40,0,1
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,78
 LDWR R0,0x3050	
 MOVXR R40,0,1
 
 RET
 
 
 file_number_over_92:  ;文件数小于85

 LDWR R0,0x304F		  ;总页面设为10页		
 LDWR R40,13
 MOVXR R40,0,1
 
 LDWR R0,0x1031		  ;最后一页剩余文件数	  		
 MOVXR R40,1,1	
 DEC R40,1,85
 LDWR R0,0x3050	
 MOVXR R40,0,1
 
 RET
 

 
 
 
 
 FILE_OS_Current_number:  ;当前界面       判断当前界面号为0或者1
 
 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 LDWR R0,0x304F		  ;		
 MOVXR R42,1,1
 JS  R40,R42,FILE_OS_Current_number_less 
 ;当前页码所需读取文件名地址判断
  LDWR R0,0x3051
  MOVXR R42,0,1 


FILE_OS_Current_number_less:
 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 LDWR R42,1

 JS R42,R40,FILE_OS_Current_number_normal;文件数大于等于10
  LDWR R0,0x3051
  MOVXR R42,0,1

FILE_OS_Current_number_normal:
RET




FILE_Not_Last_Page:

LDWR R0,0X3064
LDWR R30,1
LDWR R32,1
LDWR R34,1
LDWR R36,1
LDWR R38,1
LDWR R40,1
LDWR R42,1

MOVXR R30,0,7 

;CALL FILE_OS_Number_1
;CALL FILE_OS_Number_2
;CALL FILE_OS_Number_3
;CALL FILE_OS_Number_4
;CALL FILE_OS_Number_5
;CALL FILE_OS_Number_6
;CALL FILE_OS_Number_7
;CALL FILE_OS_Number_8
;CALL FILE_OS_Number_9
RET

FILE_Not_Last_Page_1:

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,2
LDWR R38,2
LDWR R40,2
LDWR R42,2

MOVXR R30,0,7

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
CALL FILE_OS_Number_4
CALL FILE_OS_Number_5
CALL FILE_OS_Number_6
CALL FILE_OS_Number_7
RET


FILE_OS_Number:      


 LDWR R0,0x1031		  ;当前总文件 		
 MOVXR R48,1,1
 
 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R50,1,1
 LDWR R0,0x304F		  ;	总文件頁碼	
 MOVXR R52,1,1
 LDWR R0,0x3050		  ;最后一个个界面的文件数
 MOVXR R54,1,1
 
 LDWR R58,0x0000	  
 
JS R58,R54,FILE_Not_0

CALL FILE_Not_Last_Page
 
RET 
 
FILE_Not_0: 
 
JS R50,R52,FILE_Not_Last_Page_1




LDWR R56,1
JS R56,R54,FILE_last_page_Num_not_1

LDWR R0,0X3064
LDWR R30,2
LDWR R32,1
LDWR R34,1
LDWR R36,1
LDWR R38,1
LDWR R40,1
LDWR R42,1
MOVXR R30,0,7 

CALL FILE_OS_Number_1
RET

FILE_last_page_Num_not_1:
LDWR R56,2
JS R56,R54,FILE_last_page_Num_not_2

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,1
LDWR R36,1
LDWR R38,1
LDWR R40,1
LDWR R42,1
MOVXR R30,0,7 


CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
RET

FILE_last_page_Num_not_2:
LDWR R56,3
JS R56,R54,FILE_last_page_Num_not_3


LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,1
LDWR R38,1
LDWR R40,1
LDWR R42,1

MOVXR R30,0,7 

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
RET

FILE_last_page_Num_not_3:
LDWR R56,4
JS R56,R54,FILE_last_page_Num_not_4

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,2
LDWR R38,1
LDWR R40,1
LDWR R42,1

MOVXR R30,0,7 

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
CALL FILE_OS_Number_4
RET

FILE_last_page_Num_not_4:
LDWR R56,5
JS R56,R54,FILE_last_page_Num_not_5

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,2
LDWR R38,2
LDWR R40,1
LDWR R42,1

MOVXR R30,0,7 

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
CALL FILE_OS_Number_4
CALL FILE_OS_Number_5
RET

FILE_last_page_Num_not_5:
LDWR R56,6
JS R56,R54,FILE_last_page_Num_not_6

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,2
LDWR R38,2
LDWR R40,2
LDWR R42,1

MOVXR R30,0,7 

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
CALL FILE_OS_Number_4
CALL FILE_OS_Number_5
CALL FILE_OS_Number_6
RET

FILE_last_page_Num_not_6:
LDWR R56,7
JS R56,R54,FILE_last_page_Num_not_END

LDWR R0,0X3064
LDWR R30,2
LDWR R32,2
LDWR R34,2
LDWR R36,2
LDWR R38,2
LDWR R40,2
LDWR R42,2
MOVXR R30,0,7 

CALL FILE_OS_Number_1
CALL FILE_OS_Number_2
CALL FILE_OS_Number_3
CALL FILE_OS_Number_4
CALL FILE_OS_Number_5
CALL FILE_OS_Number_6
CALL FILE_OS_Number_7
RET

FILE_last_page_Num_not_END:RET





FILE_OS_KEY:
 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R50,1,1
 LDWR R0,0x304F		  ;	总文件数目	
 MOVXR R52,1,1
 LDWR R0,0x3050		  ;最后一个个界面的文件数
 MOVXR R54,1,1
 
 

 
 LDWR R0,0x306D		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_1
 
 LDWR R0,0x305B		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 
 LDWR R0,0x3052		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_1_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,130 			;y坐标值
	LDWR  R46,195 			;y坐标值
 
	JS R52,R40,FILE_KEY_1_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_1_Touch
	JS R54,R44,FILE_KEY_1_Touch
	JS R46,R54,FILE_KEY_1_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_1_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x306D	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_1_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,130 			;y坐标值
	LDWR  R46,195 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_1_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_1_Touch
	JS R54,R44,FILE_OS_NOT_KEY_1_Touch
	JS R46,R54,FILE_OS_NOT_KEY_1_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_1_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 

	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	LDWR R0,0x306D	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_1_Touch:
 
	LDWR R0,0x306D	
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3201			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		
	
	RET
 

FILE_OS_NOT_KEY_1:


 LDWR R0,0x306E		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_2
 
 LDWR R0,0x305C		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 
 LDWR R0,0x3053		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_2_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,205 			;y坐标值
	LDWR  R46,270 			;y坐标值
 
	JS R52,R40,FILE_KEY_2_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_2_Touch
	JS R54,R44,FILE_KEY_2_Touch
	JS R46,R54,FILE_KEY_2_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_2_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x306E	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_2_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,205 			;y坐标值
	LDWR  R46,270 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_2_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_2_Touch
	JS R54,R44,FILE_OS_NOT_KEY_2_Touch
	JS R46,R54,FILE_OS_NOT_KEY_2_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_2_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	LDWR R0,0x306E	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_2_Touch:
 
	LDWR R0,0x306E	
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3202			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET

 
 FILE_OS_NOT_KEY_2:
 LDWR R0,0x306F		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_3
 
 LDWR R0,0x305D		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 LDWR R0,0x3054		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_3_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,280 			;y坐标值
	LDWR  R46,345 			;y坐标值
 
	JS R52,R40,FILE_KEY_3_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_3_Touch
	JS R54,R44,FILE_KEY_3_Touch
	JS R46,R54,FILE_KEY_3_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_3_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x306F	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_3_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,280 			;y坐标值
	LDWR  R46,345 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_3_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_3_Touch
	JS R54,R44,FILE_OS_NOT_KEY_3_Touch
	JS R46,R54,FILE_OS_NOT_KEY_3_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_3_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	LDWR R0,0x306F	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_3_Touch:
 
	LDWR R0,0x306F	
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3203			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET

 
 FILE_OS_NOT_KEY_3:
 LDWR R0,0x3070		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_4
 
 LDWR R0,0x305E		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 LDWR R0,0x3055		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_4_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,355 			;y坐标值
	LDWR  R46,420 			;y坐标值
 
	JS R52,R40,FILE_KEY_4_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_4_Touch
	JS R54,R44,FILE_KEY_4_Touch
	JS R46,R54,FILE_KEY_4_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_4_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x3070	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_4_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,355 			;y坐标值
	LDWR  R46,420 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_4_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_4_Touch
	JS R54,R44,FILE_OS_NOT_KEY_4_Touch
	JS R46,R54,FILE_OS_NOT_KEY_4_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_4_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	
	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	LDWR R0,0x3070	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_4_Touch:
 
	LDWR R0,0x3070
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3204			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET



 FILE_OS_NOT_KEY_4:
 LDWR R0,0x3071		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_5
 
 LDWR R0,0x305F		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 LDWR R0,0x3056		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_5_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,425 			;y坐标值
	LDWR  R46,490 			;y坐标值
 
	JS R52,R40,FILE_KEY_5_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_5_Touch
	JS R54,R44,FILE_KEY_5_Touch
	JS R46,R54,FILE_KEY_5_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_5_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x3071	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_5_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,425 			;y坐标值
	LDWR  R46,490 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_5_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_5_Touch
	JS R54,R44,FILE_OS_NOT_KEY_5_Touch
	JS R46,R54,FILE_OS_NOT_KEY_5_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_5_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	 
	LDWR R0,0x3071	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_5_Touch:
 
	LDWR R0,0x3071
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3205			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET


FILE_OS_NOT_KEY_5:
 LDWR R0,0x3072		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_6
 
 LDWR R0,0x3060		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 LDWR R0,0x3057		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_6_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,500 			;y坐标值
	LDWR  R46,565 			;y坐标值
 
	JS R52,R40,FILE_KEY_6_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_6_Touch
	JS R54,R44,FILE_KEY_6_Touch
	JS R46,R54,FILE_KEY_6_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_6_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	
	LDWR R0,0x3072	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_6_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,500 			;y坐标值
	LDWR  R46,565 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_6_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_6_Touch
	JS R54,R44,FILE_OS_NOT_KEY_6_Touch
	JS R46,R54,FILE_OS_NOT_KEY_6_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_6_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	LDWR R0,0x0084						
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	LDWR R0,0x3072	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_6_Touch:
 
	LDWR R0,0x3072
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3206			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET
 
FILE_OS_NOT_KEY_6: 
 LDWR R0,0x3073		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_END
 
 LDWR R0,0x3061		  ;读第一个文件序号 		
 MOVXR R50,1,1
 LDWR R0,0x201F       
 MOVXR R50,0,1
 
 LDWR R0,0x3058		  
 MOVXR R40,1,1
 IJNE R41,0X01,FILE_OS_NOT_KEY_7_Touch
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
	LDWR  R40,290 			;x坐标值
	LDWR  R42,355 			;x坐标值
	LDWR  R44,580 			;y坐标值
	LDWR  R46,645 			;y坐标值
 
	JS R52,R40,FILE_KEY_7_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_KEY_7_Touch
	JS R54,R44,FILE_KEY_7_Touch
	JS R46,R54,FILE_KEY_7_Touch 

	IJNE R51,0x01,FILE_OS_NOT_KEY_7_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 
	
	
	
	LDWR R0,0x201F       
	MOVXR R50,1,1
	LDWR R0,0x20C8      
	MOVXR R50,0,1
	
	LDWR R0,0X20C7	
	LDWR R50,0x005A
	MOVXR R50,0,1 
	
	CALL FILE_OS_MODBUS_SET_UDisk_Delete
	
	LDWR R0,0x3073	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_KEY_7_Touch:
 
 
    LDWR R0,0x0016			;系统寄存器0x0016 触摸屏触摸信息
	MOVXR R50,1,4 			;R50,R51为触摸屏更新与状态 R52,R53为x坐标位置 R54,R55为y坐标位置
   	LDWR  R40,375			;x坐标值
	LDWR  R42,440			;x坐标值
	LDWR  R44,590 			;y坐标值
	LDWR  R46,645 			;y坐标值
 
	JS R52,R40,FILE_OS_NOT_KEY_7_Touch	;判断按压是否在+号范围里
	JS R42,R52,FILE_OS_NOT_KEY_7_Touch
	JS R54,R44,FILE_OS_NOT_KEY_7_Touch
	JS R46,R54,FILE_OS_NOT_KEY_7_Touch 
	
	IJNE R51,0x01,FILE_OS_NOT_KEY_7_Touch ;查询触摸屏的按压方式，点击阶段(01) - 长按阶段(03) - 	松开状态(02)
	LDWR R60,0x0001  
	MOVXR R60,0,1
	
	 	
	LDWR R0,0x2020	 ;
	LDWR R60,0x0001
	MOVXR R60,0,1	
	
	CALL FILE_OS_KEY_Modbus
	
	 LDWR R0,0x0084						
	 LDWR R40,0x5A01
	 LDWR R42,1
	 MOVXR R40,0,2
	
	LDWR R0,0x3073	
	LDWR R50,0
	MOVXR R50,0,1 
 
 RET
 
 FILE_OS_NOT_KEY_7_Touch:
 
	LDWR R0,0x3073
	LDWR R50,0
	MOVXR R50,0,1 
	
	LDWR R0,0x3207			 ;0x2048标志置为0
	LDWR R60,0x0000
	MOVXR R60,0,1	
		

	RET

 
 
; FILE_OS_NOT_KEY_7:
; LDWR R0,0x3074	  
; MOVXR R40,1,1
; IJNE R41,0X01,FILE_OS_NOT_KEY_8
; 
; LDWR R0,0x3062		  ;读第一个文件序号 		
; MOVXR R50,1,1
; LDWR R0,0x201F       
; MOVXR R50,0,1
; 
; LDWR R0,0x3074	
; LDWR R50,0
; MOVXR R50,0,1
; RET
; 
; 
; FILE_OS_NOT_KEY_8:
;  LDWR R0,0x3075	  
; MOVXR R40,1,1
; IJNE R41,0X01,FILE_OS_NOT_KEY_END
; 
; LDWR R0,0x3063		  ;读第一个文件序号 		
; MOVXR R50,1,1
; LDWR R0,0x201F       
; MOVXR R50,0,1
; 
; LDWR R0,0x3075
; LDWR R50,0
; MOVXR R50,0,1
; RET

FILE_OS_NOT_KEY_END:


 LDWR R0,0x201F       
 MOVXR R56,1,1
 
 LDWR R0,0x305B		  ;		
 MOVXR R60,1,1
 
 LDWR R64,2		  ;		
 LDWR R0,0x3064		  ;		
 MOVXR R62,1,1
 

 
CJNE R63,R65,FILE_OS_KEY_NEXT_1
CJNE R57,R61,FILE_OS_KEY_NEXT_1

 

 
 
 LDWR R0,0x3052
 LDWR R20,1
 LDWR R22,0
 LDWR R24,0
 LDWR R26,0
 LDWR R28,0
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7 
 RET
 
 
 FILE_OS_KEY_NEXT_1:
 
  
 LDWR R0,0x201F       
 MOVXR R56,1,1
 
 
 LDWR R0,0x305C		  ;		
 MOVXR R60,1,1
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x3065		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_2
 
CJNE R57,R61,FILE_OS_KEY_NEXT_2
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,1
 LDWR R24,0
 LDWR R26,0
 LDWR R28,0
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7
 
 
 RET
 
 FILE_OS_KEY_NEXT_2:
 
 LDWR R0,0x201F       
 MOVXR R56,1,1
 
 LDWR R0,0x305D		  ;		
 MOVXR R60,1,1
 
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x3066		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_3
 
CJNE R57,R61, FILE_OS_KEY_NEXT_3
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,1
 LDWR R26,0
 LDWR R28,0
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7 
 RET
 
 
 
FILE_OS_KEY_NEXT_3:

 LDWR R0,0x201F       
 MOVXR R56,1,1 
 
 LDWR R0,0x305E		  ;		
 MOVXR R60,1,1
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x3067		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_4
 
 
CJNE R57,R61, FILE_OS_KEY_NEXT_4
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,0
 LDWR R26,1
 LDWR R28,0
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7 
 
 
 RET
 
 
 FILE_OS_KEY_NEXT_4:

 LDWR R0,0x201F       
 MOVXR R56,1,1 
 
 LDWR R0,0x305F		  ;		
 MOVXR R60,1,1
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x3068		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_5
CJNE R57,R61, FILE_OS_KEY_NEXT_5
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,0
 LDWR R26,0
 LDWR R28,1
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7
 
 
 RET
 
 
 FILE_OS_KEY_NEXT_5:

 LDWR R0,0x201F       
 MOVXR R56,1,1 
 
 LDWR R0,0x3060		  ;		
 MOVXR R60,1,1
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x3069		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_6
 
CJNE R57,R61, FILE_OS_KEY_NEXT_6
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,0
 LDWR R26,0
 LDWR R28,0
 LDWR R30,1
 LDWR R32,0

 MOVXR R20,0,7 
 
 
 RET
 
 
  FILE_OS_KEY_NEXT_6:

 LDWR R0,0x201F       
 MOVXR R56,1,1 
 
 LDWR R0,0x3061		  ;		
 MOVXR R60,1,1
 
 
 
 LDWR R64,2		  ;		
 LDWR R0,0x306A		  ;		
 MOVXR R62,1,1
 
CJNE R63,R65,FILE_OS_KEY_NEXT_END
CJNE R57,R61, FILE_OS_KEY_NEXT_END
 
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,0
 LDWR R26,0
 LDWR R28,0
 LDWR R30,0
 LDWR R32,1
 MOVXR R20,0,7
 
 
 RET
 
 
 FILE_OS_KEY_NEXT_END:
 LDWR R0,0x3052
 LDWR R20,0
 LDWR R22,0
 LDWR R24,0
 LDWR R26,0
 LDWR R28,0
 LDWR R30,0
 LDWR R32,0
 MOVXR R20,0,7
 
 LDWR R0,0x201F 
 LDWR R56,0      
 MOVXR R56,0,1
 
 
 RET

FILE_OS_KEY_Modbus:

 LDWR R0,0x201F       
 MOVXR R50,1,1
 
 LDWR R0,0x2020      
 MOVXR R52,1,1
 
 IJNE R51,0X00,FILE_OS_KEY_Modbus_1
 
   	LDWR R0,0x2020     
	LDWR R50,0 
	MOVXR R50,0,1
    RET
    
  FILE_OS_KEY_Modbus_1:
 IJNE R53,0X01,FILE_OS_NOT_KEY_Modbus
  ;若按下
  
  	LDWR R0,0x2020     
	LDWR R50,0 
	MOVXR R50,0,1
	
	LDWR R0,0x2033     
	LDWR R50,0x005A
	MOVXR R50,0,1

	LDWR R0,0x201F       
	MOVXR R48,1,1
	LDWR R0,0x2034      
	MOVXR R48,0,1
	CALL FILE_OS_MODBUS_SET
	
	LDWR R0,0x201F    
	LDWR R50,0 
	MOVXR R50,0,1

FILE_OS_NOT_KEY_Modbus:
 RET






;================================================================



FILE_OS_Number_1:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 

 LDWR R48,1 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x305B
 MOVXR R48,0,1
 LDWR R50,0 
 
;LDWR R0,0X305B		;1号  !!!!!!!!     
;MOVXR R48,1,1
DEC R48,1,1




LDWR R46,0X0063		;*****  0063  99






LDWR R42,0X0004
SMAC R48,R42,R44    ;R46

LDWR R0,0X20B0
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_1

RET

FILE_OS_Number_2:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 


 LDWR R48,2 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x305C
 MOVXR R48,0,1
 LDWR R50,0 
 
DEC R48,1,1


LDWR R46,0X0063		;*****  0063  99



LDWR R42,0X0004
SMAC R48,R42,R44    ;R46

LDWR R0,0X20B1
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_2

RET


FILE_OS_Number_3:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 
 LDWR R48,3 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x305D
 MOVXR R48,0,1
 LDWR R50,0 
 
DEC R48,1,1

LDWR R46,0X0063		;*****  0063  99



LDWR R42,0X0004
SMAC R48,R42,R44    ;R46

LDWR R0,0X20B2
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_3


RET 
 
 FILE_OS_Number_4:

 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 

 LDWR R48,4 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x305E
 MOVXR R48,0,1
 LDWR R50,0 
 
DEC R48,1,1


LDWR R46,0X0063		;*****  0063  99


LDWR R42,0X0004
SMAC R48,R42,R44    ;R46

LDWR R0,0X20B3
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_4
 
RET 
 
 FILE_OS_Number_5:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1 
 

 LDWR R48,5 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x305F
 MOVXR R48,0,1
 LDWR R50,0 
 
 
DEC R48,1,1

LDWR R46,0X0063		;*****  0063  99x
FLIE_NOT_ADD_499_5:



LDWR R42,0X0004
SMAC R48,R42,R44    ;R46

LDWR R0,0X20B4
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_5 

RET
 
FILE_OS_Number_6:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1
 
 LDWR R48,6 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x3060
 MOVXR R48,0,1
 LDWR R50,0 
 
DEC R48,1,1


LDWR R46,0X0063		;*****  0063  99



LDWR R42,0X0004
SMAC R48,R42,R44    ;R46


LDWR R0,0X20B5
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_6
 
RET 
 
 FILE_OS_Number_7:


 LDWR R0,0x3051		  ;读当前页面号  		
 MOVXR R40,1,1

 LDWR R48,7 
 LDWR R32,7
 DEC R40,1,1
 SMAC R32,R40,R46
 LDWR R0,0x3061
 MOVXR R48,0,1
 LDWR R50,0 
 
DEC R48,1,1

LDWR R46,0X0063		;*****  0063  99



LDWR R42,0X0004
SMAC R48,R42,R44    ;R46


LDWR R0,0X20B6
LDWR R66,0X005A
MOVXR R66,0,1
CALL FILE_OS_MODBUS_7
 
RET 
 


Reset_Jump:

	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,4,Reset_Jump_NUMB  	  ;是否在4界面

Reset_Jump_stay:
	LDWR R0,0x3200		  		
	MOVXR R40,1,1
	IJNE  R41,0X01,Reset_Jump_Break
	
	LDWR R0,0x1FF1				
	LDWR R40,0x0000
	MOVXR R40,0,1
	
	LDWR R0,0x3200	
	LDWR R40,0X0000	  	
	MOVXR R40,0,1
	
	LDWR R0,0x0084						
    LDWR R40,0x5A01
    LDWR R42,0
    MOVXR R40,0,2
	
	 
	LDWR R0,0x100E			;图标动画  	
	LDWR R40,0x0002
	MOVXR R40,0,1
	 
	LDWR R0,0x100A		    ;图标动画  	
	LDWR R40,0x0000
	MOVXR R40,0,1
	
	LDWR R0,0x100C			;图标动画  	
	LDWR R40,0x0000
	MOVXR R40,0,1
	
		


	CALL Sys_Reset_Main
	
	RET
Reset_Jump_NUMB:

	LDWR R0,0x0014				  ;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,8,Reset_Jump_Break  	  ;是否在4界面
		
	CALL Reset_Jump_stay
    RET

Reset_Jump_Break:
	RET


 WIFI_SET:
 
 	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,14,IP_SET_NO_KEY  ;
	
	CALL IP_SET
	
  
	RET

 
	IP_SET:
	 
	LDWR R0,0x2078			;读ok按下状态
	MOVXR R40,1,1
;	LDWR R0,0X2076			;读当前WIFI状态
;	MOVXR R42,1,1
	
	IJNE R41,0X01,IP_SET_NO_KEY
;	IJNE R43,0X00,IP_SET_NO_KEY
	
	LDWR R0,0x102C			;modbus发送			
	LDWR R50,0x005A
	MOVXR R50,0,1
	
	
	LDWR R0,0x2078			;modbus发送			
	LDWR R50,0x0000
	MOVXR R50,0,1
	
	RET
 IP_SET_NO_KEY:RET




Lock_screen:


 	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,4,Lock_screen_jump  ;
	
	
	LDWR R0,0x3302			;
	MOVXR R40,1,1
	IJNE R41,1,Lock_screen_Break  ;
	
	
	LDWR R0,0X1019					
	LDWR R50,0x0000
	MOVXR R50,0,1
	
	LDWR R0,0x3301			;
	MOVXR R40,1,1
	IJNE R41,1,Lock_screen_Break  ;
	
	LDWR R0,0x3301				
	LDWR R50,0x0000
	MOVXR R50,0,1
	
	LDWR R0,0x0084						
    LDWR R40,0x5A01
    LDWR R42,8
    MOVXR R40,0,2
    
	LDWR R0,0X1019					
	LDWR R50,0x0000
	MOVXR R50,0,1
	
	RET
	
	Lock_screen_jump:
	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,8,Lock_screen_Break  ;
	
	LDWR R0,0X1019					
	LDWR R50,0x0001
	MOVXR R50,0,1
	
	CALL Reset_Jump
	


Lock_screen_Break:

	LDWR R0,0x3301				
	LDWR R50,0x0000
	MOVXR R50,0,1
RET




Work_Setting:


 	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,10,Work_Setting_12  ;
	
	LDWR R0,0x20D6					
	LDWR R50,0x0050
	MOVXR R50,0,1
	
	CALL Button_state
	
	RET
	
Work_Setting_12:
 	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,12,Work_Setting_Break  ;
	
	LDWR R0,0x20D0					
	LDWR R50,0x005A
	MOVXR R50,0,1
	
	CALL Button_state
	
	RET

Work_Setting_Break:
RET


Screen_Setting:

 	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,13,Screen_Setting_Break  ;
	
	LDWR R0,0x20E0			;
	MOVXR R40,1,1
	IJNE R41,1,Work_Setting_Break  ;
	LDWR R0,0x20E0				
	LDWR R50,0x0000
	MOVXR R50,0,1
	
	CALL LOOK_SET
	CALL Back_Light
	
	RET
	
Back_Light:
	LDWR R0,0X10A8			;
	MOVXR R40,1,1
	IJNE R41,1,Back_Light_2  ;
	
	LDWR R0,0x0082				
	LDWR R50,0x1414
	MOVXR R50,0,1
	
;	LDWR R0,0x0084						
;    LDWR R40,0x5A01
;    LDWR R42,9
;    MOVXR R40,0,2
	
	RET
Back_Light_2:   
	LDWR R0,0X10A8			;
	MOVXR R40,1,1
	IJNE R41,2,Back_Light_3  ;
	
	LDWR R0,0x0082				
	LDWR R50,0x3232
	MOVXR R50,0,1
	
;	LDWR R0,0x0084						
;    LDWR R40,0x5A01
;    LDWR R42,9
;    MOVXR R40,0,2
	
	RET
Back_Light_3:   
	LDWR R0,0X10A8			;
	MOVXR R40,1,1
	IJNE R41,3,Back_Light_break  ;
	
	LDWR R0,0x0082				
	LDWR R50,0x6464
	MOVXR R50,0,1
	
;	LDWR R0,0x0084						
;    LDWR R40,0x5A01
;    LDWR R42,9
;    MOVXR R40,0,2
;	
	RET
Back_Light_break:
	RET
RET	

LOOK_SET:
	LDWR R0,0X10A7			;
	MOVXR R40,1,1
	IJNE R41,1,LOOK_SET_OFF  ;
	
	LDWR R0,0x3302				
	LDWR R50,0x0001
	MOVXR R50,0,1
	
	RET
LOOK_SET_OFF:
	
	LDWR R0,0x3302				
	LDWR R50,0x0000
	MOVXR R50,0,1
	

Screen_Setting_Break:
RET






JOG_Setting:
	
	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,6,JOG_Setting_Break  ;
	
	LDWR R0,0x2068					
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	CALL NAME_1
	
	
	
	
	
JOG_Setting_Break:
RET   



INF0_Setting:

	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,15,INF0_Setting_Break  ;

	
	LDWR R0,0x2500					
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2040					
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	
	RET



INF0_Setting_Break:
RET


INF0_Password:

	LDWR R0,0x0014			;f
	MOVXR R40,1,1
	IJNE R41,16,INF0_Password_Break  ;
	
	LDWR R0,0x401F			;
	MOVXR R40,1,1
	IJNE R41,1,INF0_Password_Break  ;
	
	LDWR R0,0x401F					
	LDWR R40,0x0000
	MOVXR R40,0,1

	LDWR R0,0x4020				
	MOVXR R40,1,1
	IJNE R41,0X01,INF0_Password_Break  ;
	LDWR R0,0x4021				
	MOVXR R40,1,1
	IJNE R41,0X02,INF0_Password_Break  ;
	LDWR R0,0x4022				
	MOVXR R40,1,1
	IJNE R41,0X03,INF0_Password_Break  ;
	LDWR R0,0x4023				
	MOVXR R40,1,1
	IJNE R41,0X03,INF0_Password_Break  ;
	LDWR R0,0x0084						
	LDWR R40,0x5A01
    LDWR R42,17
    MOVXR R40,0,2
	
	RET
INF0_Password_Break:
RET




SERVICE_INF0:

	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,17,SERVICE_INF0_Break  ;

		
	LDWR R0,0x2501				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2500				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2502				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2503				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2504				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2505				
	LDWR R40,0x005A
	MOVXR R40,0,1
	
	LDWR R0,0x2506				
	LDWR R40,0x005A
	MOVXR R40,0,1


SERVICE_INF0_Break:
RET

SYSTEM_LOCK_TIME:


	LDWR R0,0x0014			;
	MOVXR R40,1,1
	IJNE R41,18,SYSTEM_LOCK_TIME_Break  ;
	
	LDWR R0,0x401E				
	MOVXR R40,1,1
	IJNE R41,0X01,SYSTEM_LOCK_TIME_Break  ;
	
	LDWR R0,0x401E				
	LDWR R40,0x0000
	MOVXR R40,0,1
	
		
	LDWR R0,0x2507			
	LDWR R40,0x005A
	MOVXR R40,0,1
	



SYSTEM_LOCK_TIME_Break:
RET










;通过T5 OS 直接访问0xE000~0xFFFF 的8KW 变量空间来定义Modbus 参数； 
;为了避免冲突，用户定义os定义modbus从0xEE00开始定义

;==================================================================================
	
FILE_OS_MODBUS_1:	
	LDWR R0, 0XEE08 ;
	LDBR R70,0X5A,1 ;5A表示本条指令有效
	LDBR R71,0X01,1 ;读写的modbus设备地址
	LDBR R72,0X03,1 ;读写modbus指令  ; 
	LDBR R73,0x08,1 ;LEN *2 ;
	LDWR R74,0X01F4 ;TIM 500MS
	LDWR R76,0X0002 ;MARK 
	LDWR R78,0x20B0 ;MARK 
	LDWR R80,0X302B ;一号文件0x302b-0x302e
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,4    ;R50 存放第一个文件的地址
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	
;	LDWR R0, 0XEE10 ;
;	LDBR R70,0X5A,1 ;5A表示本条指令有效
;	LDBR R71,0X01,1 ;读写的modbus设备地址
;	LDBR R72,0X03,1 ;读写modbus指令  ; 
;	LDBR R73,0x08,1 ;LEN *2 ;
;	LDWR R74,0X01F4 ;TIM 500MS
;	LDWR R76,0X0001 ;MARK 
;	LDWR R78,0X0029 ;MARK 
;	LDWR R80,0X302B ;一号文件0x302b-0x302e
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,4    ;R50 存放第一个文件的地址
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	
	
	RET
	
FILE_OS_MODBUS_2:
	LDWR R0, 0XEE18 ;第二个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0x20B1 ; 
	LDWR R80,0X302f ;二号文件0x302f-0x3032
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2   
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
;	LDWR R0, 0XEE20 ;第二个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0X302f ;二号文件0x302f-0x3032
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2   
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	
FILE_OS_MODBUS_3:
	LDWR R0, 0XEE28 ;第三个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0X20B2 ; 
	LDWR R80,0X3033 ;三号文件0x3033-0x3036
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2   
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	
;	LDWR R0, 0XEE30 ;第三个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0X3033 ;三号文件0x3033-0x3036
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2   
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
;	
	RET
	
FILE_OS_MODBUS_4:
	
	LDWR R0, 0XEE38 ;第四个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0x20B3; 
	LDWR R80,0X3037 ;四号文件0x3037-0x303A
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2   
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	
;	LDWR R0, 0XEE40 ;第三个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0X3037 ;三号文件0x3033-0x3036
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2   
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	
FILE_OS_MODBUS_5:
	
	LDWR R0, 0XEE48 ;第五个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0x20B4 ; 
	LDWR R80,0X303B ;五号文件0x303B-0x303E
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2   
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
;	LDWR R0, 0XEE50 ;第五个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0X303B ;五号文件0x303B-0x303E
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2   
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	
FILE_OS_MODBUS_6:
	
	LDWR R0, 0XEE58 ;第六个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0x20B5 ; 
	LDWR R80,0X303f ;六号文件0x303F-0x3042
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2 
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	
;	LDWR R0, 0XEE60 ;第六个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0X303f ;六号文件0x303F-0x3042
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2 
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	RET
	
FILE_OS_MODBUS_7:
	
	LDWR R0, 0XEE68 ;第七个文件
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X03,1 ; 
	LDBR R73,0x08,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0x20B6 ; 
	LDWR R80,0x3043 ;七号文件0x3043-0x3046
	;LDWR R82,0X0032 ;ID_ADDRE
	MOV R46,R82,2 
	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	
;	LDWR R0, 0XEE70 ;第七个文件
;	LDBR R70,0X5A,1 ;
;	LDBR R71,0X01,1 ;
;	LDBR R72,0X03,1 ; 
;	LDBR R73,0x08,1 ;
;	LDWR R74,0X01F4 ;
;	LDWR R76,0X0001 ;
;	LDWR R78,0X0029 ; 
;	LDWR R80,0x3043 ;七号文件0x3043-0x3046
;	;LDWR R82,0X0032 ;ID_ADDRE
;	MOV R46,R82,2 
;	LDWR R84,0X0000
;	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	

 
FILE_OS_MODBUS_SET:
	
		
	LDWR R0, 0XEE98 ;
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X10,1 ; 
	LDBR R73,0x02,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0X2033 ; 
	LDWR R80,0X2034 ;
	LDWR R82,0x0000 ;

	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	
	
	
FILE_OS_MODBUS_SET_UDisk_Delete:
	
		
	LDWR R0, 0XEEB8 ;
	LDBR R70,0X5A,1 ;
	LDBR R71,0X01,1 ;
	LDBR R72,0X10,1 ; 
	LDBR R73,0x02,1 ;
	LDWR R74,0X01F4 ;
	LDWR R76,0X0002 ;
	LDWR R78,0X20C7 ; 
	LDWR R80,0x20C8 ;
	LDWR R82,0x0037 ;

    

	LDWR R84,0X0000
	MOVXR R70,0,8 ;READ_X1-X7
	
	RET
	
	
	
	Alarm_OS:
	LDWR R0,0x0014			 ;
    MOVXR R40,1,1
    IJNE R41,1,Alarm_OS_sys  ;	  

	LDWR R0,0x2062			
	LDWR R60,0x005A
	MOVXR R60,0,1
	
	CALL Alarm_OS_EN
	
	RET
	Alarm_OS_sys:

    LDWR R0,0x0014					;系统寄存器0x0014 只读当前界面
	MOVXR R40,1,1
	IJNE R41,2,Alarm_OS_sys_24 
	 
	LDWR R0,0x2062			
	LDWR R60,0x005A
	MOVXR R60,0,1
	
	CALL Alarm_OS_EN
	
	RET
	
	Alarm_OS_sys_24:
	
		 

	 LDWR R0,0x0014					;系统寄存器0x0014 只读当前界面
	 MOVXR R40,1,1
	 IJNE R41,24,Alarm_OS_sys_end
	 
	LDWR R0,0x2062			
	LDWR R60,0x005A
	MOVXR R60,0,1
	
		
	LDWR R0,0x2056					
	MOVXR R40,1,1
	IJNE R41,1,Alarm_OS_EN
	 
	LDWR R0,0x2056		
	LDWR R60,0x0000
	MOVXR R60,0,1
	
	LDWR R0,0x2001		
	LDWR R60,0x005A
	MOVXR R60,0,1
	
	
	LDWR R0,0x0084						;跳转到报警
	LDWR R40,0x5A01
	LDWR R42,1
	MOVXR R40,0,2
	
	RET


	
	RET


	
	Alarm_OS_sys_end:
	
	RET 

	
	RET
	
	
	Alarm_OS_EN:

 

	LDWR R0,0X308C     
	MOVXR R40,1,1
	IJNE R40,0X00,Alarm_OS_ok_EN
	IJNE R41,0X00,Alarm_OS_ok_EN


		LDWR R0,0x0014					;系统寄存器0x0014 只读当前界面
		MOVXR R40,1,1
		IJNE R41,24,Alarm_OS_Numb_54_en  ;是否在文件界面
		
		


		
		RET
		Alarm_OS_Numb_54_en:
		
		LDWR R0,0x2023
		LDWR R60,0X0000
		LDWR R62,0X0000
		LDWR R64,0X0000
		LDWR R66,0X0000
		LDWR R68,0X0000
		LDWR R70,0X0000
		LDWR R72,0X0000
		MOVXR R60,0,7
		
		RET

	Alarm_OS_ok_EN:



	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0001
	AND R40,R50,2
	;x限位触发
	IJNE R41,0X01,Alarm_OS_1_EN



	LDWR R0,0x2023
	LDWR R60,0X5820
	LDWR R62,0X4C69
	LDWR R64,0X6d69
	LDWR R66,0X7420
	LDWR R68,0X7472
	LDWR R70,0X6967
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2



	Alarm_OS_1_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0002
	AND R40,R50,2
	;Y限位触发
	IJNE R41,0X02,Alarm_OS_2_EN

	LDWR R0,0x2023
	LDWR R60,0X5920
	LDWR R62,0X4C69
	LDWR R64,0X6d69
	LDWR R66,0X7420
	LDWR R68,0X7472
	LDWR R70,0X6967
	LDWR R72,0X0000
	MOVXR R60,0,7


	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2



	Alarm_OS_2_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0004
	AND R40,R50,2
	;Z限位触发
	IJNE R41,0X04,Alarm_OS_3_EN
	LDWR R0,0x2023
	LDWR R60,0X5A20
	LDWR R62,0X4C69
	LDWR R64,0X6d69
	LDWR R66,0X7420
	LDWR R68,0X7472
	LDWR R70,0X6967
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2



	Alarm_OS_3_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0008
	AND R40,R50,2
	;u限位触发
	IJNE R41,0X08,Alarm_OS_5_EN
	LDWR R0,0x2023
	LDWR R60,0X5520
	LDWR R62,0X4C69
	LDWR R64,0X6d69
	LDWR R66,0X7420
	LDWR R68,0X7472
	LDWR R70,0X6967
	LDWR R72,0X0000
	MOVXR R60,0,7


	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2


	
	Alarm_OS_4_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0100
	AND R40,R50,2

	IJNE R40,0X01,Alarm_OS_5_EN
	IJNE R41,0X00,Alarm_OS_5_EN
	LDWR R0,0x2023
	LDWR R60,0X5820
	LDWR R62,0x4F76
	LDWR R64,0X6572
	LDWR R66,0X7363
	LDWR R68,0X616C
	LDWR R70,0X6500
	LDWR R72,0X0000
	MOVXR R60,0,7
	;
	;
	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	;
	;
	;
	Alarm_OS_5_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0200
	AND R40,R50,2
	;Y边框越界
	IJNE R40,0X02,Alarm_OS_6_EN
	IJNE R41,0X00,Alarm_OS_6_EN
	LDWR R0,0x2023
	LDWR R60,0X5920
	LDWR R62,0x4F76
	LDWR R64,0X6572
	LDWR R66,0X7363
	LDWR R68,0X616C
	LDWR R70,0X6500
	LDWR R72,0X0000
	MOVXR R60,0,7
	;
	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2



	Alarm_OS_6_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0400
	AND R40,R50,2
	;机器被保护
	IJNE R40,0X04,Alarm_OS_8_EN
	IJNE R41,0X00,Alarm_OS_8_EN
	LDWR R0,0x2023
	LDWR R60,0X5072
	LDWR R62,0X6F74
	LDWR R64,0X6563
	LDWR R66,0X7469
	LDWR R68,0X6F6E
	LDWR R70,0X2100
	LDWR R72,0X0000
	MOVXR R60,0,7
	;
	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	;

	Alarm_OS_8_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0800
	AND R40,R50,2
	;水保护被触发
	IJNE R40,0X08,Alarm_OS_9_EN
	IJNE R41,0X00,Alarm_OS_9_EN
	LDWR R0,0x2023
	LDWR R60,0X5761
	LDWR R62,0X7465
	LDWR R64,0X7220
	LDWR R66,0X616c
	LDWR R68,0X6172
	LDWR R70,0X6D00
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2



	Alarm_OS_9_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x1000
	AND R40,R50,2
	;机器未复位
	IJNE R40,0X10,Alarm_OS_A_EN
	IJNE R41,0X00,Alarm_OS_A_EN
	LDWR R0,0x2023
	LDWR R60,0X4E6F
	LDWR R62,0X2048
	LDWR R64,0X6F6D
	LDWR R66,0X696E
	LDWR R68,0X6721
	LDWR R70,0X0000
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	 
	 
	 Alarm_OS_A_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0010
	AND R40,R50,2
	;高温报警
	IJNE R40,0X00,Alarm_OS_B_EN
	IJNE R41,0X10,Alarm_OS_B_EN
	LDWR R0, 0x2023
	LDWR R60,0X4869
	LDWR R62,0X6768
	LDWR R64,0X2074
	LDWR R66,0X656D
	LDWR R68,0X7020
	LDWR R70,0X0000
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	 
	 
	 Alarm_OS_B_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0020
	AND R40,R50,2
	;烟雾报警
	IJNE R40,0X00,Alarm_OS_C_EN
	IJNE R41,0X20,Alarm_OS_C_EN
	LDWR R0, 0x2023
	LDWR R60,0X536D
	LDWR R62,0X6F6B
	LDWR R64,0X6520
	LDWR R66,0X616C
	LDWR R68,0X6172
	LDWR R70,0X6D00
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	 
	 
	  Alarm_OS_C_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0040
	AND R40,R50,2
	;授权到期
	IJNE R40,0X00,Alarm_OS_C1_EN
	IJNE R41,0X40,Alarm_OS_C1_EN
	LDWR R0, 0x2023
	LDWR R60,0X4D61
	LDWR R62,0XCADA
	LDWR R64,0X7475
	LDWR R66,0X7269
	LDWR R68,0X7479
	LDWR R70,0X0000
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	 
	 
	 
	 
	  
	 Alarm_OS_C1_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x0080
	AND R40,R50,2
	;XY边框越界
	IJNE R40,0X00,Alarm_OS_D_EN
	IJNE R41,0X80,Alarm_OS_D_EN
	LDWR R0, 0x2023
	LDWR R60,0X5859
	LDWR R62,0x4F76
	LDWR R64,0X6572
	LDWR R66,0X7363
	LDWR R68,0X616C
	LDWR R70,0X6500
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2

	  Alarm_OS_D_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x2000
	AND R40,R50,2
	;X缓冲距离不足
	IJNE R40,0X20,Alarm_OS_E_EN
	IJNE R41,0X00,Alarm_OS_E_EN
	LDWR R0, 0x2023
	LDWR R60,0X5820
	LDWR R62,0X6E6F
	LDWR R64,0X7420
	LDWR R66,0X6275
	LDWR R68,0X6666
	LDWR R70,0X6572
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2


	  Alarm_OS_E_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x4000
	AND R40,R50,2
	;Y缓冲距离不足
	IJNE R40,0X40,Alarm_OS_F_EN
	IJNE R41,0X00,Alarm_OS_F_EN
	LDWR R0, 0x2023
	LDWR R60,0X5920
	LDWR R62,0X6E6F
	LDWR R64,0X7420
	LDWR R66,0X6275
	LDWR R68,0X6666
	LDWR R70,0X6572
	LDWR R72,0X0000
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2
	 
	 
	   Alarm_OS_F_EN:
	LDWR R0,0X308C
	MOVXR R40,1,1
	LDWR R50,0x8000
	AND R40,R50,2
	;XY缓冲距离不足
	IJNE R40,0X80,Alarm_OS_FF_EN
	IJNE R41,0X00,Alarm_OS_FF_EN
	LDWR R0, 0x2023
	LDWR R60,0X5859
	LDWR R62,0X206E
	LDWR R64,0X6F74
	LDWR R66,0X2062
	LDWR R68,0X7566
	LDWR R70,0X6665
	LDWR R72,0X7200
	MOVXR R60,0,7

	 LDWR R0,0x0084						;跳转到报警
	 LDWR R40,0x5A01
	 LDWR R42,24
	 MOVXR R40,0,2





	Alarm_OS_FF_EN:RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;Border_crossing_alarm:
;
; LDWR R0,0x0014					
; MOVXR R40,1,1
; IJNE R41,27,Alarm_OS_4
; 
; CALL Border_crossing_alarm_Stay
;RET
;
; 
; 
; Border_crossing_alarm_Stay:
; 
; LDWR R0,0X20F6					
; MOVXR R40,1,1
; IJNE R41,1,Alarm_OS_4
; 
; LDWR R0,0X20F6
; LDWR R40,0x0000	 			   ;寻焦状态清除
; MOVXR R40,0,1
; 
;  LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
;    LDWR R0,0x2062			
;	LDWR R60,0x0000
;	MOVXR R60,0,1
;	
;	
;	LDWR R0,0X308C			
;	LDWR R60,0x0000
;	MOVXR R60,0,1
; 
; LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1 
; 
;
; LDWR R0,0x0084						
; LDWR R40,0x5A01
; LDWR R42,1
; MOVXR R40,0,2
; 
;  LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
; RET
; 
;
; 
; Border_crossing_alarm_Stay_END:
; RET
; 
;
;Alarm_OS_4:
;
;
;CALL Alarm_OS_4_EN
; 
; RET
;
;
;
;Alarm_OS_4_EN:
;LDWR R0,0X308C
;MOVXR R40,1,1
;LDWR R50,0x0100
;AND R40,R50,2
;;X边框越界
;IJNE R40,0X01,Alarm_OS_5_EN
;IJNE R41,0X00,Alarm_OS_5_EN
;
;
;
; LDWR R0,0x0084						;跳转到报警
; LDWR R40,0x5A01
; LDWR R42,27
; MOVXR R40,0,2
;
;Alarm_OS_5_EN:
;LDWR R0,0X308C
;MOVXR R40,1,1
;LDWR R50,0x0200
;AND R40,R50,2
;;Y边框越界
;IJNE R40,0X02,Border_crossing_alarm_Break
;IJNE R41,0X00,Border_crossing_alarm_Break
;
; LDWR R0,0x0084						;跳转到报警
; LDWR R40,0x5A01
; LDWR R42,27
; MOVXR R40,0,2
;RET
;
;Border_crossing_alarm_Break:
;
;RET
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;
;
;
;
;
;
;
;
;Open_cover_protection:
;
;
;LDWR R0,0X20F5					
;MOVXR R40,1,1
;IJNE R41,0,Open_cover_protection_Break
;
;
;
;LDWR R0,0X308C 
;MOVXR R40,1,1
;LDWR R50,0x0400
;AND R40,R50,2
;;机器被保护
;IJNE R40,0X04,Open_cover_protection_MAIN_CH_OR_EN
;IJNE R41,0X00,Open_cover_protection_MAIN_CH_OR_EN
;
; 
; LDWR R0,0x0014					;系统寄存器0x0014 只读当前界面
; MOVXR R40,1,1
; IJNE R41,26,Open_cover_protection_TO_68_cn
; 
; LDWR R0,0X2062
; LDWR R40,0x005A	 			   ;寻焦状态清除
; MOVXR R40,0,1
; 
; RET
; 
; 
; 
; Open_cover_protection_TO_68_cn:
;
; LDWR R0,0x0084						;跳转到报警
; LDWR R40,0x5A01
; LDWR R42,26
; MOVXR R40,0,2
; 
; LDWR R0,0X2062
; LDWR R40,0x005A	 			   ;寻焦状态清除
; MOVXR R40,0,1
;
; RET
; 
; Open_cover_protection_Lang_end:
; RET
;
;
;
;
;Open_cover_protection_MAIN_CH_OR_EN:
;
; 
; Open_cover_protection_MAIN__EN:
; LDWR R0,0x0014					;系统寄存器0x0014 只读当前界面
; MOVXR R40,1,1
; IJNE R41,26,Open_cover_protection_Break
; 
; 
; CALL Open_cover_protection_MAIN_EN
; 
; RET
; 
; 
; Open_cover_protection_MAIN_EN:
; 
; 
; LDWR R0,0X2062
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
; 
; LDWR R0,0X308C
; MOVXR R40,1,1
; LDWR R50,0x0400
; AND R40,R50,2
;;机器被保护
; IJNE R40,0X00,Open_cover_protection_Break
; IJNE R41,0X00,Open_cover_protection_Break 
; 
; LDWR R0,0x0084						;跳转到报警
; LDWR R40,0x5A01
; LDWR R42,1
; MOVXR R40,0,2
; 
; LDWR R0,0X2000
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
;
;
;RET
;
;
;Open_cover_protection_Break:
;RET
;
;
;
;
;
;
;Open_cover_protection_KEY:
; 
; LDWR R0,0X20F4
; MOVXR R40,1,1
; IJNE R41,0X01,Open_cover_protection_KEY_Break
; 
;   
; LDWR R0,0X20F5
; LDWR R40,0x0001	 			   
; MOVXR R40,0,1 
;
;  
; LDWR R0,0X2062
; LDWR R40,0x0000	 			   
; MOVXR R40,0,1
; 
; LDWR R0,0X308C
; LDWR R40,0x0000	 			   
; MOVXR R40,0,1
; 
; 
; LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
;
; 
; LDWR R0,0X20F4
; LDWR R40,0x0000	 			   
; MOVXR R40,0,1
; 
; 
; LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
; 
;
;
; 
; Open_cover_protection_KEY_EN:
; 
;  	LDWR R0,0x1FF1			;
;	LDWR R40,0x0000
;	MOVXR R40,0,1
;
;   ;
; LDWR R0,0x0084						;跳转到报警
; LDWR R40,0x5A01
; LDWR R42,0
; MOVXR R40,0,2
; 
;
;
; LDWR R0,0X2001
; LDWR R40,0x005A	 			   
; MOVXR R40,0,1
; 
;  
;
;
; 
;; 
; RET
; 
; 
;Open_cover_protection_KEY_Break:
;RET
;
;








