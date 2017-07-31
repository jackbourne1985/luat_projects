--[[
ģ�����ƣ�AGPS��ȫ��Assisted Global Positioning System��GPS������λ����(��������u-blox��GPSģ��)
ģ�鹦�ܣ�����AGPS��̨������GPS�������ݣ�д��GPSģ�飬����GPS��λ
ģ������޸�ʱ�䣺2017.02.20
]]

--[[
�����Ϻ�̨��Ӧ�ò�Э�飺
1������AGPS����̨
2����̨�ظ�AGPSUPDATE,total,last,sum1,sum2,sum3,......,sumn
   total�������ܸ���
   last�����һ�������ֽ���
   sum1����һ�������ݵ�У���
   sum2���ڶ��������ݵ�У���
   sum3�������������ݵ�У���
   ......
   sumn����n�������ݵ�У���
3������Getidx
   idx�ǰ�����������Χ��1---total
   ���磺���������ļ�Ϊ4000�ֽڣ�
   Get1
   Get2
   Get3
   Get4
4����̨�ظ�ÿ����������
   ��һ���ֽں͵ڶ����ֽڣ�Ϊ�������������
   ��������Ϊ��������
]]

--����ģ��,����������
local base = _G
local table = require"table"
local rtos = require"rtos"
local sys = require"sys"
local string = require"string"
local link = require"link"
local gps = require"gps"
module(...)

--���س��õ�ȫ�ֺ���������
local print = base.print
local tonumber = base.tonumber
local sfind = string.find
local slen = string.len
local ssub = string.sub
local sbyte = string.byte
local sformat = string.format
local send = link.send
local dispatch = sys.dispatch

--lid��socket id
--isfix��GPS�Ƿ�λ�ɹ�
local lid,isfix
--ispt���Ƿ���AGPS����
--itv������AGPS��̨�������λ�룬Ĭ��2Сʱ����ָ2Сʱ����һ��AGPS��̨������һ����������
--PROT,SVR,PORT��AGPS��̨�����Э�顢��ַ���˿�
--WRITE_INTERVAL��ÿ���������ݰ�д��GPSģ��ļ������λ����
local ispt,itv,PROT,SVR,PORT,WRITE_INTERVAL = true,(2*3600),"UDP","zx1.clouddatasrv.com",8072,50
--mode��AGPS���ܹ���ģʽ�����������֣�Ĭ��Ϊ0��
--0���Զ����Ӻ�̨�������������ݡ�д��GPSģ��
--1����Ҫ���Ӻ�̨ʱ�������ڲ���ϢAGPS_EVT���û������������Ϣ�����Ƿ���Ҫ���ӣ������������ݣ�д��GPSģ��󣬽���������ڲ���ϢAGPS_EVT��֪ͨ�û����ؽ����д����
local mode = 0
--gpssupport���Ƿ���GPSģ��
--eph����AGPS��̨���ص���������
local gpssupport,eph = true,""
--GET_TIMEOUT��GET����ȴ�ʱ�䣬��λ����
--ERROR_PACK_TIMEOUT�������(��ID���߳��Ȳ�ƥ��) ��һ��ʱ���������»�ȡ
--GET_RETRY_TIMES��GET���ʱ���ߴ����ʱ����ǰ���������Ե�������
--PACKET_LEN��ÿ����������ݳ��ȣ���λ�ֽ�
--RETRY_TIMES�����Ӻ�̨���������ݹ��̽����󣬻�Ͽ����ӣ�����˴����ع���ʧ�ܣ�����������Ӻ�̨�����´�ͷ��ʼ���ء��������ָ���������������Ӻ�̨���ص�������
local GET_TIMEOUT,ERROR_PACK_TIMEOUT,GET_RETRY_TIMES,PACKET_LEN,RETRY_TIMES = 10000,5000,3,1024,3
--state��״̬��״̬
--IDLE������״̬
--CHECK������ѯ�������������ݡ�״̬
--UPDATE�����������������С�״̬
--total�������ܸ�����������������Ϊ10221�ֽڣ���total=(int)((10221+1021)/1022)=11;�����ļ�Ϊ10220�ֽڣ���total=(int)((10220+1021)/1022)=10
--last�����һ�������ֽ��������������ļ�Ϊ10225�ֽڣ���last=10225%1022=5;�����ļ�Ϊ10220�ֽڣ���last=1022
--checksum��ÿ�����������ݵ�У��ʹ洢��
--packid����ǰ��������
--getretries����ȡÿ�����Ѿ����ԵĴ���
--retries���������Ӻ�̨���أ��Ѿ����ԵĴ���
--reconnect���Ƿ���Ҫ������̨
local state,total,last,checksum,packid,getretries,retries,reconnect = "IDLE",0,0,{},0,0,1,false

--[[
��������startupdatetimer
����  �����������Ӻ�̨�������������ݡ���ʱ��
����  ����
����ֵ����
]]
local function startupdatetimer()
	--֧��GPS����֧��AGPS
	if gpssupport and ispt then
		sys.timer_start(connect,itv*1000)
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
	--GPS��λ�ɹ�
	if data == gps.GPS_LOCATION_SUC_EVT or data == gps.GPS_LOCATION_UNFILTER_SUC_EVT then
		sys.dispatch("AGPS_UPDATE_SUC")
		startupdatetimer()
		isfix = true
	--GPS��λʧ�ܻ���GPS�ر�
	elseif data == gps.GPS_LOCATION_FAIL_EVT or data == gps.GPS_CLOSE_EVT then
		isfix = false
	--û��GPSоƬ
	elseif data == gps.GPS_NO_CHIP_EVT then
		gpssupport = false
	end
	return true
end

--[[
��������writecmd
����  ��дÿ���������ݵ�GPSģ��
����  ��
		id��gps.GPS_STATE_IND�����ô���
		data����Ϣ��������
����ֵ��true
]]
local function writecmd()
	if eph and slen(eph) > 0 and not isfix then
		local h1,h2 = sfind(eph,"\181\98")
		if h1 and h2 then
			local id = ssub(eph,h2+1,h2+2)
			if id and slen(id) == 2 then
				local llow,lhigh = sbyte(eph,h2+3),sbyte(eph,h2+4)
				if lhigh and llow then
					local length = lhigh*256 + llow
					print("length",h2+6+length,slen(eph))
					if h2+6+length <= slen(eph) then
						gps.writegpscmd(false,ssub(eph,h1,h2+6+length),false)
						eph = ssub(eph,h2+7+length,-1)
						sys.timer_start(writecmd,WRITE_INTERVAL)
						return
					end
				end
			end
		end
	end
	gps.closegps("AGPS")
	eph = ""
	sys.dispatch("AGPS_UPDATE_SUC")
end

--[[
��������startwrite
����  ����ʼд�������ݵ�GPSģ��
����  ����
����ֵ����
]]
local function startwrite()
	if isfix or not gpssupport then
		eph = ""
		return
	end
	if eph and slen(eph) > 0 then
		gps.opengps("AGPS")
		sys.timer_start(writecmd,WRITE_INTERVAL)
	end
end

--[[
��������calsum
����  ������У���
����  ��
		str��Ҫ����У��͵�����
����ֵ��У���
]]
local function calsum(str)
	local sum,i = 0
	for i=1,slen(str) do
		sum = sum + sbyte(str,i)
	end
	return sum
end

--[[
��������errpack
����  �����������
����  ��
		str��Ҫ����У��͵�����
����ֵ��У���
]]
local function errpack()
	print("errpack")
	upend(false)
end

--[[
��������retry
����  �����Զ���
����  ��
		para�����ΪSTOP����ֹͣ���ԣ�����ִ������
����ֵ����
]]
function retry(para)
	if state ~= "UPDATE" and state ~= "CHECK" then
		return
	end

	if para == "STOP" then
		getretries = 0
		sys.timer_stop(errpack)
		sys.timer_stop(retry)
		return
	end

	if para == "ERROR_PACK" then
		sys.timer_start(errpack,ERROR_PACK_TIMEOUT)
		return
	end

	getretries = getretries + 1
	if getretries < GET_RETRY_TIMES then
		if state == "UPDATE" then
			-- δ�����Դ���,�������Ի�ȡ������
			reqget(packid)
		else
			reqcheck()
		end
	else
		-- �������Դ���,����ʧ��
		upend(false)
	end
end

--[[
��������reqget
����  �����͡���ȡ��index�����������ݡ���������
����  ��
		index��������������1��ʼ
����ֵ����
]]
function reqget(idx)
	send(lid,sformat("Get%d",idx))
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
��������getpack
����  �������ӷ������յ���һ������
����  ��
		data��������
����ֵ����
]]
local function getpack(data)
	-- �жϰ������Ƿ���ȷ
	local len = slen(data)
	if (packid < total and len ~= PACKET_LEN) or (packid >= total and len ~= (last+2)) then
		print("getpack:len not match",packid,len,last)
		retry("ERROR_PACK")
		return
	end

	-- �жϰ�����Ƿ���ȷ
	local id = sbyte(data,1)*256 + sbyte(data,2)%256
	if id ~= packid then
		print("getpack:packid not match",id,packid)
		retry("ERROR_PACK")
		return
	end

	--�ж�У����Ƿ���ȷ
	local sum = calsum(ssub(data,3,-1))
	if checksum[id] ~= sum then
		print("getpack:checksum not match",checksum[id],sum)
		retry("ERROR_PACK")
		return
	end

	-- ֹͣ����
	retry("STOP")

	-- ����������
	eph = eph .. ssub(data,3,-1)

	-- ��ȡ��һ������
	if packid == total then
		sum = calsum(eph)
		if checksum[total+1] ~= sum then
			print("getpack:total checksum not match",checksum[total+1],sum)
			upend(false)
		else
			upend(true)
		end
	else
		packid = packid + 1
		reqget(packid)
	end
end

--[[
��������upbegin
����  �������������·�����������Ϣ
����  ��
		data����������Ϣ
����ֵ����
]]
local function upbegin(data)
	--���ĸ��������һ�����ֽ���
	local d1,d2,p1,p2 = sfind(data,"AGPSUPDATE,(%d+),(%d+)")
	local i
	if d1 and d2 and p1 and p2 then
		p1,p2 = tonumber(p1),tonumber(p2)
		total,last = p1,p2
		local tmpdata = data
		--ÿ���������ݵ�У���
		for i=1,total+1 do
			if d2+2 > slen(tmpdata) then
				upend(false)
				return false
			end
			tmpdata = ssub(tmpdata,d2+2,-1)
			d1,d2,p1 = sfind(tmpdata,"(%d+)")
			if d1 == nil or d2 == nil or p1 == nil then
				upend(false)
				return false
			end
			checksum[i] = tonumber(p1)
		end

		getretries,state,packid,eph = 0,"UPDATE",1,""
		--�����1��
		reqget(packid)
		return true
	end

	upend(false)
	return false
end

--[[
��������reqcheck
����  �����͡�����������Ϣ�����ݵ�������
����  ����
����ֵ����
]]
function reqcheck()
	state = "CHECK"
	send(lid,"AGPS")
	sys.timer_start(retry,GET_TIMEOUT)
end

--[[
��������upend
����  �����ؽ���
����  ��
		succ�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function upend(succ)
	state = "IDLE"
	-- ֹͣ��ʵ��ʱ��
	sys.timer_stop(retry)
	sys.timer_stop(errpack)
	-- �Ͽ�����
	link.close(lid)
	getretries = 0
	if succ then
		reconnect = false
		retries = 0
		--д������Ϣ��GPSоƬ
		print("eph rcv",slen(eph))
		startwrite()
		startupdatetimer()
		if mode==1 then dispatch("AGPS_EVT","END_IND",true) end
	else
		if retries >= RETRY_TIMES then
			reconnect = false
			retries = 0
			startupdatetimer()
			if mode==1 then dispatch("AGPS_EVT","END_IND",false) end
		else
			reconnect = true
			retries = retries + 1
		end
	end
end

--[[
��������rcv
����  ��socket�������ݵĴ�����
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function rcv(id,data)
	base.collectgarbage()
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--�����λ�ɹ����߲�֧��GPSģ��
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if state == "CHECK" then
		--����������������Ϣ
		if sfind(data,"AGPSUPDATE") == 1 then
			upbegin(data)
			return
		end
	elseif state == "UPDATE" then
		if data ~= "ERR" then
			getpack(data)
			return
		end
	end

	upend(false)
	return
end

--[[
��������nofity
����  ��socket״̬�Ĵ�����
����  ��
        id��socket id��������Ժ��Բ�����
        evt����Ϣ�¼�����
		val�� ��Ϣ�¼�����
����ֵ����
]]
local function nofity(id,evt,val)
	print("agps notify",lid,id,evt,val,reconnect)
	if id ~= lid then return end
	--�����λ�ɹ����߲�֧��GPSģ��
	if isfix or not gpssupport then
		upend(true)
		return
	end
	if evt == "CONNECT" then
		--���ӳɹ�
		if val == "CONNECT OK" then
			reqcheck()
		--����ʧ��
		else
			upend(false)
		end
	elseif evt == "CLOSE" and reconnect then
		--����
		connect()
	elseif evt == "STATE" and val == "CLOSED" then
		upend(false)
	end
end

--[[
��������connectcb
����  �����ӷ�����
����  ����
����ֵ����
]]
local function connectcb()
	lid = link.open(nofity,rcv,"agps")
	link.connect(lid,PROT,SVR,PORT)
end

--[[
��������connect
����  �����ӷ���������
����  ����
����ֵ����
]]
function connect()
	if ispt then
		--�Զ�ģʽ
		if mode==0 then
			connectcb()
		--�û�����ģʽ
		else
			dispatch("AGPS_EVT","BEGIN_IND",connectcb)
		end		
	end
end

--[[
��������init
����  ���������ӷ����������������ݼ���ʹ�ģ�鹤��ģʽ
����  ��
		inv�����¼������λ��
		md������ģʽ
����ֵ����
]]
function init(inv,md)
	itv = inv or itv
	mode = md or 0
	startupdatetimer()
end

--[[
��������setspt
����  �������Ƿ���AGPS����
����  ��
		spt��trueΪ������false����nilΪ�ر�
����ֵ����
]]
function setspt(spt)
	if spt ~= nil and ispt ~= spt then
		ispt = spt
		if spt then
			startupdatetimer()
		end
	end
end

--[[
��������load
����  �����д˹���ģ��
����  ����
����ֵ����
]]
local function load()
	--(�������� ���� ��翪��) ���� ������������������
	if (rtos.poweron_reason() == rtos.POWERON_KEY or rtos.poweron_reason() == rtos.POWERON_CHARGER) and gps.isagpspwronupd() then
		connect()
	else
		startupdatetimer()
	end
end

--ע��GPS��Ϣ������
sys.regapp(gpsstateind,gps.GPS_STATE_IND)
load()
