--���������λ�ö���PROJECT��VERSION����
--PROJECT��ascii string���ͣ�������㶨�壬ֻҪ��ʹ��,����
--VERSION��ascii string���ͣ����ʹ��Luat������ƽ̨�̼������Ĺ��ܣ����밴��"X.X.X"���壬X��ʾ1λ���֣��������㶨��
PROJECT = "MQTT_CONTROL_LED"
VERSION = "1.0.0"
require"sys"

require"control_led"
--S3�����壺Ӳ�����Ѿ����˿��Ź����ܣ�ʹ��S3��������û���Ҫ������ע�͵Ĵ���"--require"wdt""������4�������һ�����һ��
--require"wdt"

sys.init(0,0)
sys.run()
