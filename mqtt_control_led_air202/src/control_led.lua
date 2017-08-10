
require"misc"
require"mqtt"
require"pincfg"
module(...,package.seeall)

--测试时请搭建自己的服务器
local PROT,ADDR,PORT = "TCP","180.97.80.55",1883
local mqttclient

local function send_response(payload)
  mqttclient:publish(string.format("/device/%s/resp",misc.getimei()), payload)
end

local function send_report(payload)
  mqttclient:publish(string.format("/device/%s/report",misc.getimei()), payload)
end

local function on_receive(topic, payload, qos)
  print("control_led.on_receive", topic, payload)

  if payload == "led on" then
    pins.set(true, pincfg.PIN_LED)
    send_response("ok")
  elseif payload == "led off" then
    pins.set(false, pincfg.PIN_LED)
    send_response("ok")
  else
    send_response("unknown command")
  end
end

local function on_imei_ready()
  mqttclient = mqtt.create(PROT,ADDR,PORT)
  mqttclient:connect(misc.getimei(),
                  600,
                  "user",
                  "password",
                  function() -- connect success callback
                      --订阅主题
                      mqttclient:subscribe({{topic=string.format("/device/%s/req",misc.getimei()),qos=0}},
                                           function(usertag, result)
                                             print("on_subcribe_ack", usertag, result)
                                           end,
                                           "subcribe device remote request")
                      --注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
                      mqttclient:regevtcb({MESSAGE=on_receive})
                      send_report("led connected")
                  end,
                  function(rc) -- connect error callback
                      print("control_led.on_connect_error", rc)
                  end)
end

local procer =
{
	IMEI_READY = on_imei_ready,
}
--注册消息的处理函数
sys.regapp(procer)
