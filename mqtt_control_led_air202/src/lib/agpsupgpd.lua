--����ģ��,����������
require"socket"
require"common"
local bit = require"bit"
local gps = require"gps"

module(...,package.seeall)

--���س��õ�ȫ�ֺ���������
local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len

local SCK_IDX,PROT,ADDR,PORT = 2,"TCP","download.openluat.com",80

local linksta

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

local reconncnt,reconncyclecnt,conning = 0,0
local GPD_FILE = "/GPD.txt"
local GPDTIME_FILE = "/GPDTIME.txt"
local GPDTIME_FILEP = "/GPDTIMEP.txt"
local gpdlen,wxlt
local month = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

local head = "AAF00B026602"
local tail,idx,tonum = "0D0A",0

local function print(...)
	_G.print("agpsupgpd",...)
end

local str1 = "GET /9501-xingli/brdcGPD.dat_rda HTTP/1.0\n"
local str2 = "Accept: */*\n"
local str3 = "Accept-Language: cn\n"
local str4 = "User-Agent: Mozilla/4.0\n"
local str5 = "Host: download.openluat.com:80\n"
local str6 = "Connection: Keep-Alive\n"
local str7 = "\n\n"
local str8 = "Content-Length:0"

local sendstr = str1..str2..str3..str4..str5..str6..str7

local gpd = ""

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(data,para)
	return socket.send(SCK_IDX,data,para)
end

--[[
��������gpsup
����  �����͡�����������Ϣ�����ݵ�������
����  ����
����ֵ����
]]
function gpsup()
	print("gpsup",linksta)
	if linksta then
		snd(sendstr,"GPS")		
	end
end

--[[
��������reconn
����  ��������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ����
����ֵ����
]]
local function reconn()
	print("reconn",reconncnt,conning,reconncyclecnt)
	--conning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������reconncnt���ӣ�ʵ�ʵ�������������
	if conning then return end
	--һ�����������ڵ�����
	if reconncnt < RECONN_MAX_CNT then		
		reconncnt = reconncnt+1
		link.shut()
		connect()
	--һ���������ڵ�������ʧ��
	else
		reconncnt,reconncyclecnt = 0,reconncyclecnt+1
		if reconncyclecnt >= RECONN_CYCLE_MAX_CNT then
			sys.restart("connect fail")
		end
		sys.timer_start(reconn,RECONN_CYCLE_PERIOD*1000)
	end
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket.lua��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socket.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	print("ntfy",evt,result,item)
	--���ӽ��������socket.connect����첽�¼���
	if evt == "CONNECT" then
		conning = false
		--���ӳɹ�
		if result then
			reconncnt,reconncyclecnt,linksta = 0,0,true
			--ֹͣ������ʱ��
			sys.timer_stop(reconn)
			gpsup()
		--����ʧ��
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000)
		end	
	--���ݷ��ͽ��������socket.send����첽�¼���
	elseif evt == "SEND" then
		--����ʧ�ܣ�RECONN_PERIOD���������̨����Ҫ����reconn����ʱsocket״̬��Ȼ��CONNECTED���ᵼ��һֱ�����Ϸ�����
		if not result then sys.timer_start(reconn,RECONN_PERIOD*1000) end
		if not result then link.shut() end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		linksta = false
		--reconn()
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		linksta = false
	--���������Ͽ�������socket.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		linksta = false
		--reconn()		
	end
	--�����������Ͽ�������·����������
	if smatch((type(result)=="string") and result or "","ERROR") then
		--RECONN_PERIOD�����������Ҫ����reconn����ʱsocket״̬��Ȼ��CONNECTED���ᵼ��һֱ�����Ϸ�����
		--sys.timer_start(reconn,RECONN_PERIOD*1000)
		link.shut()
	end
end

--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        idx ��socket.lua��ά����socket idx��������socket.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function writetxt(f,v)
	local file = io.open(f,"w")
	if file == nil then
		print("GPD open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

local function readtxt(f)
	local file,rt = io.open(f,"r")
	if file == nil then
		print("GPD can not open file",f)
		return ""
	end
	rt = file:read("*a")
	file:close()
	return rt
end

local writebg
function writegpdbg()
	local tmp = 0
	local str = "$PGKC149,1,115200*15\r\n"
	--[[for i = 2,slen(str)-1 do
		tmp = bit.bxor(tmp,sbyte(str,i))
	end	
	tmp = string.format("%x",tmp)
	str = str..tmp.."\r\n"]]
	print("syy writeapgs str",str,slen(str))
	writebg = true
	gps.writegk(str)
end

function writed()
	local writend = "AAF00B006602FFFF6F0D0A"
	writend = common.hexstobins(writend)
	gps.writegk(writend)
end

function writeswname()
	local writswn = "AAF00E0095000000C20100580D0A"
	print("writeswname")
	writswn = common.hexstobins(writswn)
	gps.writegk(writswn)
end

function writegpd()
	local tmp,inf,body = 0
	local idx2 = string.format("%x",idx)
	if slen(idx2) < 2 then
		idx2 = "0"..idx2
	end
	local str = head..idx2.."00"
	inf = readtxt(GPD_FILE)
	local tolen = slen(inf)
	tonum = tolen/1024
	print("writegpd inf",idx,idx2,tolen,tonum)
	print("inf",ssub(inf,1,512))
	if idx < tonum then
		body = ssub(inf,idx*1024+1,(idx+1)*1024)
	else
		local snum = tolen - idx*1024
		body = ssub(inf,idx*1024+1,-1)
		body = body..string.rep("F",(1024-snum))
	end
	str = str..body
	print("writegpd",slen(body))
	print("writegpd 2",body)
	local str2 = common.hexstobins(str)

	for i = 3,slen(str2) do
		tmp = bit.bxor(tmp,sbyte(str2,i))
	end	
	tmp = string.upper(string.format("%x",tmp))
	if slen(tmp) < 2 then
	tmp = "0"..tmp
	end
	str = str..tmp..tail
	
	print("syy writegpd tmp",tmp)
	
	gps.writegk(common.hexstobins(str))
	idx = idx+1
end

function changem(m)
	for k,v in pairs(month) do
		if m == v then
			return k
		end
	end
end

local xlt
function wxltime(t)
	print("wxltime",t)	
	local clk = {}
	local a,b = nil,nil
	xlt = t
	a,b,clk.day,clk.month,clk.year,clk.hour,clk.min,clk.sec = string.find(t,"(%d+)% (%w+)% (%d+) *(%d%d):(%d%d):(%d%d)")
	clk.month = changem(clk.month)
	clk = common.transftimezone(clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec,0,8)
	print(clk.year,clk.month,clk.day,clk.hour,clk.min,clk.sec )
	wxlt = os.time({year=clk.year,month=clk.month,day=clk.day, hour=clk.hour, min=clk.min, sec=clk.sec})
	print("wxltime",wxlt,os.time())
end

function rcv(idx,data)
	print("syy rcv!!!!!!!!!!",slen(data))
	--print("rcv",data)
	local str1 = string.find(data,"Length: ")
	local dl = string.len("Length: ")
	local t1,t2= string.find(data,"Modified: ")
	if t2 then
		local mt = ssub(data,t2+1,-5)
		wxltime(mt)
	end
	if str1 then  
		gpdlen = ssub(data,str1+dl,str1+dl+3)
	end
	print("syy len:",str1,gpdlen)
	if str1 then
		local str2 = string.find(data,"\r\n\r\n")
		gpd = ssub(data,str2+slen("\r\n\r\n"))
		gpd = common.binstohexs(gpd)
	else		
		gpd = gpd..common.binstohexs(data)
		print("syy gpd",ssub(gpd,1,8),ssub(gpd,slen(gpd)-8))
	end
	print("syy gpd len:",slen(gpd),tonumber(gpdlen))
	if slen(gpd) >= tonumber(gpdlen)*2 then
		socket.close(idx)
		gpd = ssub(gpd,1,tonumber(gpdlen)*2)
		writegpdbg()
		writetxt(GPD_FILE,gpd)
	end
end

--[[
��������gpsstateind
����  ������GPSģ����ڲ���Ϣ
����  ��
		id��gps.GPS_STATE_IND�����ô���
		data����Ϣ��������
����ֵ��true
]]
local function gpsstateind(id,data)
	print("gpsstateind",id,data)
	if data == gps.GPS_BINARY_ACK_EVT then
		print("syy gpsind GPS_BINARY_ACK_EVT writebg",writebg)
		if writebg then writegpd() end
		if not writebg then  sys.dispatch("AGPS_WRDATE_END") end
	elseif data == gps.GPS_BINW_ACK_EVT then
		print("syy gpsind GPS_BINW_ACK_EVT idx",idx)
		if idx <= tonum then
			writegpd()	
		else
			if writebg then writed() end
			writebg = nil
			idx = 0
		end
	elseif data ==	gps.GPS_BINW_END_ACK_EVT then
		print("syy gpsind GPS_BINW_END_ACK_EVT")
		writeswname()
		writetxt(GPDTIME_FILE,wxlt)
		writetxt(GPDTIME_FILEP,xlt)		
	end
	return true
end

function uptimep()
	local uptime = readtxt(GPDTIME_FILEP)
	if uptime == "" then 
		print("uptime nil")
	else
		print("uptime",uptime)
	end
end

local function uptimeck()
	uptimep()	
	local uptime = readtxt(GPDTIME_FILE)
	if uptime == "" then return true end
	local nowtime = os.time()
	if os.difftime(nowtime,uptime) >= 6*3600 then
		return true
	end
		return false
end

--[[
��������connect
����  ����������̨�����������ӣ�
        ������������Ѿ�׼���ã���������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ����
����ֵ����
]]
function connect()
	print("connect uptime",uptimeck())
	if not uptimeck() then 
		sys.dispatch("AGPS_WRDATE_END")
		return 
	end
	socket.connect(SCK_IDX,PROT,ADDR,PORT,ntfy,rcv)
	conning = true
end

local function proc(id)
	print("AGPS_WRDATE_SUC")
	--writegpdbg()
	connect()
	return true
end

--connect()

local function checkup()
	print("checkup",uptimeck())
	if uptimeck() then
		agpsgk.connect()
	end
end

uptimeck()

sys.timer_start(checkup,600*1000)

--ΪGPS�ṩ32Kʱ��
rtos.sys32k_clk_out(1);

--ע��GPS��Ϣ������
sys.regapp(proc,"AGPS_WRDATE_SUC")
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
