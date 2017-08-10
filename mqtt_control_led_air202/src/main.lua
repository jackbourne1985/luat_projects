--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "MQTT_CONTROL_LED"
VERSION = "1.0.0"
require"sys"

require"control_led"
--S3开发板：硬件上已经打开了看门狗功能，使用S3开发板的用户，要打开这行注释的代码"--require"wdt""，否则4分钟左右会重启一次
--require"wdt"

sys.init(0,0)
sys.run()
