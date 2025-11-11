// lib/src/zk_constants.dart

const int USHRT_MAX = 65535;


const int CMD_CONNECT = 1000;
const int CMD_EXIT = 1001;
const int CMD_ENABLEDEVICE = 1002;
const int CMD_DISABLEDEVICE = 1003;
const int CMD_RESTART = 1004;
const int CMD_POWEROFF = 1005;
const int CMD_GET_VERSION = 1100;
const int CMD_AUTH = 1102;

const int CMD_PREPARE_DATA = 1500;
const int CMD_DATA = 1501;
const int CMD_FREE_DATA = 1502;
const int CMD_DATA_WRRQ = 1503;
const int CMD_READ_BUFFER_CHUNK = 1504;

const int CMD_ACK_OK = 2000;
const int CMD_ACK_ERROR = 2001;
const int CMD_ACK_UNAUTH = 2005;

const int CMD_USERTEMP_RRQ = 9;
const int CMD_ATTLOG_RRQ = 13;
const int CMD_CLEAR_ATTLOG = 15;
const int CMD_GET_FREE_SIZES = 50;
const int CMD_GET_TIME = 201;
const int CMD_SET_TIME = 202;
const int FCT_USER = 5;

const int CMD_OPTIONS_RRQ = 11;

// Additional constants from base.py
const int MACHINE_PREPARE_DATA_1 = 20560;
const int MACHINE_PREPARE_DATA_2 = 32130;
// User privilege constants
class Privilege {
  static const int USER_DEFAULT = 0;
  static const int USER_ADMIN = 14;
}
