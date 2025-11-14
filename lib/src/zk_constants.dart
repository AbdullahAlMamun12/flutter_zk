// lib/src/zk_constants.dart

const int USHRT_MAX = 65535;

// Connection and control commands
const int CMD_CONNECT = 1000;
const int CMD_EXIT = 1001;
const int CMD_ENABLEDEVICE = 1002;
const int CMD_DISABLEDEVICE = 1003;
const int CMD_RESTART = 1004;
const int CMD_POWEROFF = 1005;
const int CMD_SLEEP = 1006;
const int CMD_RESUME = 1007;
const int CMD_CAPTUREFINGER = 1009;
const int CMD_TEST_TEMP = 1011;
const int CMD_CAPTUREIMAGE = 1012;
const int CMD_REFRESHDATA = 1013;
const int CMD_REFRESHOPTION = 1014;
const int CMD_TESTVOICE = 1017;
const int CMD_GET_VERSION = 1100;
const int CMD_CHANGE_SPEED = 1101;
const int CMD_AUTH = 1102;

// Data transfer commands
const int CMD_PREPARE_DATA = 1500;
const int CMD_DATA = 1501;
const int CMD_FREE_DATA = 1502;
const int CMD_DATA_WRRQ = 1503;
const int CMD_READ_BUFFER_CHUNK = 1504;

// Response codes
const int CMD_ACK_OK = 2000;
const int CMD_ACK_ERROR = 2001;
const int CMD_ACK_DATA = 2002;
const int CMD_ACK_RETRY = 2003;
const int CMD_ACK_REPEAT = 2004;
const int CMD_ACK_UNAUTH = 2005;
const int CMD_ACK_UNKNOWN = 0xffff;
const int CMD_ACK_ERROR_CMD = 0xfffd;
const int CMD_ACK_ERROR_INIT = 0xfffc;
const int CMD_ACK_ERROR_DATA = 0xfffb;

// Database commands
const int CMD_DB_RRQ = 7;
const int CMD_USER_WRQ = 8;
const int CMD_USERTEMP_RRQ = 9;
const int CMD_USERTEMP_WRQ = 10;
const int CMD_OPTIONS_RRQ = 11;
const int CMD_OPTIONS_WRQ = 12;
const int CMD_ATTLOG_RRQ = 13;
const int CMD_CLEAR_DATA = 14;
const int CMD_CLEAR_ATTLOG = 15;
const int CMD_DELETE_USER = 18;
const int CMD_DELETE_USERTEMP = 19;
const int CMD_CLEAR_ADMIN = 20;
const int CMD_USERGRP_RRQ = 21;
const int CMD_USERGRP_WRQ = 22;
const int CMD_USERTZ_RRQ = 23;
const int CMD_USERTZ_WRQ = 24;
const int CMD_GRPTZ_RRQ = 25;
const int CMD_GRPTZ_WRQ = 26;
const int CMD_TZ_RRQ = 27;
const int CMD_TZ_WRQ = 28;
const int CMD_ULG_RRQ = 29;
const int CMD_ULG_WRQ = 30;
const int CMD_UNLOCK = 31;
const int CMD_CLEAR_ACC = 32;
const int CMD_CLEAR_OPLOG = 33;
const int CMD_OPLOG_RRQ = 34;
const int CMD_GET_FREE_SIZES = 50;
const int CMD_ENABLE_CLOCK = 57;
const int CMD_STARTVERIFY = 60;
const int CMD_STARTENROLL = 61;
const int CMD_CANCELCAPTURE = 62;
const int CMD_STATE_RRQ = 64;
const int CMD_WRITE_LCD = 66;
const int CMD_CLEAR_LCD = 67;
const int CMD_GET_PINWIDTH = 69;
const int CMD_SMS_WRQ = 70;
const int CMD_SMS_RRQ = 71;
const int CMD_DELETE_SMS = 72;
const int CMD_UDATA_WRQ = 73;
const int CMD_DELETE_UDATA = 74;
const int CMD_DOORSTATE_RRQ = 75;
const int CMD_WRITE_MIFARE = 76;
const int CMD_EMPTY_MIFARE = 78;

// Time commands
const int CMD_GET_TIME = 201;
const int CMD_SET_TIME = 202;

// Event commands
const int CMD_REG_EVENT = 500;

// Event flags
const int EF_ATTLOG = 1;
const int EF_FINGER = (1 << 1);
const int EF_ENROLLUSER = (1 << 2);
const int EF_ENROLLFINGER = (1 << 3);
const int EF_BUTTON = (1 << 4);
const int EF_UNLOCK = (1 << 5);
const int EF_VERIFY = (1 << 7);
const int EF_FPFTR = (1 << 8);
const int EF_ALARM = (1 << 9);

// User privilege levels
const int USER_DEFAULT = 0;
const int USER_ENROLLER = 2;
const int USER_MANAGER = 6;
const int USER_ADMIN = 14;

// Function codes
const int FCT_ATTLOG = 1;
const int FCT_WORKCODE = 8;
const int FCT_FINGERTMP = 2;
const int FCT_OPLOG = 4;
const int FCT_USER = 5;
const int FCT_SMS = 6;
const int FCT_UDATA = 7;

// TCP packet headers
const int MACHINE_PREPARE_DATA_1 = 20560; // 0x5050
const int MACHINE_PREPARE_DATA_2 = 32130; // 0x7282

// User privilege class for convenience
class Privilege {
  static const int USER_DEFAULT = 0;
  static const int USER_ENROLLER = 2;
  static const int USER_MANAGER = 6;
  static const int USER_ADMIN = 14;
}

// Attendance status codes
class AttendanceStatus {
  static const int CHECK_IN = 0;
  static const int CHECK_OUT = 1;
  static const int BREAK_OUT = 2;
  static const int BREAK_IN = 3;
  static const int OVERTIME_IN = 4;
  static const int OVERTIME_OUT = 5;
}
