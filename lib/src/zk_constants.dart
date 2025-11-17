// lib/src/zk_constants.dart

/// The maximum value for an unsigned short integer.
const int USHRT_MAX = 65535;

// --- Connection and control commands ---

/// Initiates a connection with the device.
const int CMD_CONNECT = 1000;

/// Disconnects from the device.
const int CMD_EXIT = 1001;

/// Enables the device for operations.
const int CMD_ENABLEDEVICE = 1002;

/// Disables the device, preventing user interaction.
const int CMD_DISABLEDEVICE = 1003;

/// Restarts the device.
const int CMD_RESTART = 1004;

/// Powers off the device.
const int CMD_POWEROFF = 1005;

/// Puts the device into sleep mode.
const int CMD_SLEEP = 1006;

/// Resumes the device from sleep mode.
const int CMD_RESUME = 1007;

/// Starts the fingerprint capture process.
const int CMD_CAPTUREFINGER = 1009;

/// Tests the device's temporary memory.
const int CMD_TEST_TEMP = 1011;

/// Captures an image from the device's camera.
const int CMD_CAPTUREIMAGE = 1012;

/// Refreshes the device's internal data.
const int CMD_REFRESHDATA = 1013;

/// Refreshes the device's options.
const int CMD_REFRESHOPTION = 1014;

/// Plays a pre-recorded voice message.
const int CMD_TESTVOICE = 1017;

/// Retrieves the device's firmware version.
const int CMD_GET_VERSION = 1100;

/// Changes the device's communication speed.
const int CMD_CHANGE_SPEED = 1101;

/// Authenticates with the device.
const int CMD_AUTH = 1102;

// --- Data transfer commands ---

/// Prepares the device for data transfer.
const int CMD_PREPARE_DATA = 1500;

/// Indicates a data packet.
const int CMD_DATA = 1501;

/// Frees the data buffer on the device.
const int CMD_FREE_DATA = 1502;

/// Requests to write data to the device.
const int CMD_DATA_WRRQ = 1503;

/// Reads a chunk of data from the device's buffer.
const int CMD_READ_BUFFER_CHUNK = 1504;

// --- Response codes ---

/// Acknowledges a successful operation.
const int CMD_ACK_OK = 2000;

/// Indicates an error occurred during an operation.
const int CMD_ACK_ERROR = 2001;

/// Acknowledges a data packet.
const int CMD_ACK_DATA = 2002;

/// Requests a retry of the last operation.
const int CMD_ACK_RETRY = 2003;

/// Requests a repeat of the last operation.
const int CMD_ACK_REPEAT = 2004;

/// Indicates that authentication is required.
const int CMD_ACK_UNAUTH = 2005;

/// Indicates an unknown command or error.
const int CMD_ACK_UNKNOWN = 0xffff;

/// Indicates an error with the command itself.
const int CMD_ACK_ERROR_CMD = 0xfffd;

/// Indicates an initialization error.
const int CMD_ACK_ERROR_INIT = 0xfffc;

/// Indicates a data error.
const int CMD_ACK_ERROR_DATA = 0xfffb;

// --- Database commands ---

/// Requests to read from the database.
const int CMD_DB_RRQ = 7;

/// Requests to write a user to the database.
const int CMD_USER_WRQ = 8;

/// Requests to read a user's template from the database.
const int CMD_USERTEMP_RRQ = 9;

/// Requests to write a user's template to the database.
const int CMD_USERTEMP_WRQ = 10;

/// Requests to read device options.
const int CMD_OPTIONS_RRQ = 11;

/// Requests to write device options.
const int CMD_OPTIONS_WRQ = 12;

/// Requests to read the attendance log.
const int CMD_ATTLOG_RRQ = 13;

/// Clears all data from the device.
const int CMD_CLEAR_DATA = 14;

/// Clears the attendance log.
const int CMD_CLEAR_ATTLOG = 15;

/// Deletes a user from the device.
const int CMD_DELETE_USER = 18;

/// Deletes a user's template from the device.
const int CMD_DELETE_USERTEMP = 19;

/// Clears all administrators from the device.
const int CMD_CLEAR_ADMIN = 20;

/// Requests to read user groups.
const int CMD_USERGRP_RRQ = 21;

/// Requests to write user groups.
const int CMD_USERGRP_WRQ = 22;

/// Requests to read user time zones.
const int CMD_USERTZ_RRQ = 23;

/// Requests to write user time zones.
const int CMD_USERTZ_WRQ = 24;

/// Requests to read group time zones.
const int CMD_GRPTZ_RRQ = 25;

/// Requests to write group time zones.
const int CMD_GRPTZ_WRQ = 26;

/// Requests to read time zones.
const int CMD_TZ_RRQ = 27;

/// Requests to write time zones.
const int CMD_TZ_WRQ = 28;

/// Requests to read the unlock log.
const int CMD_ULG_RRQ = 29;

/// Requests to write to the unlock log.
const int CMD_ULG_WRQ = 30;

/// Unlocks the door connected to the device.
const int CMD_UNLOCK = 31;

/// Clears the access control list.
const int CMD_CLEAR_ACC = 32;

/// Clears the operation log.
const int CMD_CLEAR_OPLOG = 33;

/// Requests to read the operation log.
const int CMD_OPLOG_RRQ = 34;

/// Retrieves the free space on the device.
const int CMD_GET_FREE_SIZES = 50;

/// Enables the device's clock.
const int CMD_ENABLE_CLOCK = 57;

/// Starts the verification process.
const int CMD_STARTVERIFY = 60;

/// Starts the enrollment process.
const int CMD_STARTENROLL = 61;

/// Cancels the current capture process.
const int CMD_CANCELCAPTURE = 62;

/// Requests the device's current state.
const int CMD_STATE_RRQ = 64;

/// Writes text to the device's LCD screen.
const int CMD_WRITE_LCD = 66;

/// Clears the device's LCD screen.
const int CMD_CLEAR_LCD = 67;

/// Retrieves the PIN width.
const int CMD_GET_PINWIDTH = 69;

/// Requests to write an SMS message.
const int CMD_SMS_WRQ = 70;

/// Requests to read an SMS message.
const int CMD_SMS_RRQ = 71;

/// Deletes an SMS message.
const int CMD_DELETE_SMS = 72;

/// Requests to write user data.
const int CMD_UDATA_WRQ = 73;

/// Deletes user data.
const int CMD_DELETE_UDATA = 74;

/// Requests the door's current state.
const int CMD_DOORSTATE_RRQ = 75;

/// Writes data to a Mifare card.
const int CMD_WRITE_MIFARE = 76;

/// Empties a Mifare card.
const int CMD_EMPTY_MIFARE = 78;

// --- Time commands ---

/// Retrieves the current time from the device.
const int CMD_GET_TIME = 201;

/// Sets the time on the device.
const int CMD_SET_TIME = 202;

// --- Event commands ---

/// Registers for real-time events.
const int CMD_REG_EVENT = 500;

// --- Event flags ---

/// Flag for attendance log events.
const int EF_ATTLOG = 1;

/// Flag for fingerprint events.
const int EF_FINGER = (1 << 1);

/// Flag for user enrollment events.
const int EF_ENROLLUSER = (1 << 2);

/// Flag for fingerprint enrollment events.
const int EF_ENROLLFINGER = (1 << 3);

/// Flag for button press events.
const int EF_BUTTON = (1 << 4);

/// Flag for unlock events.
const int EF_UNLOCK = (1 << 5);

/// Flag for verification events.
const int EF_VERIFY = (1 << 7);

/// Flag for fingerprint feature events.
const int EF_FPFTR = (1 << 8);

/// Flag for alarm events.
const int EF_ALARM = (1 << 9);

// --- User privilege levels ---

/// Default user privilege.
const int USER_DEFAULT = 0;

/// Enroller privilege.
const int USER_ENROLLER = 2;

/// Manager privilege.
const int USER_MANAGER = 6;

/// Administrator privilege.
const int USER_ADMIN = 14;

// --- Function codes ---

/// Function code for attendance log operations.
const int FCT_ATTLOG = 1;

/// Function code for work code operations.
const int FCT_WORKCODE = 8;

/// Function code for fingerprint template operations.
const int FCT_FINGERTMP = 2;

/// Function code for operation log operations.
const int FCT_OPLOG = 4;

/// Function code for user operations.
const int FCT_USER = 5;

/// Function code for SMS operations.
const int FCT_SMS = 6;

/// Function code for user data operations.
const int FCT_UDATA = 7;

// --- TCP packet headers ---

/// First part of the TCP packet header magic number.
const int MACHINE_PREPARE_DATA_1 = 20560; // 0x5050

/// Second part of the TCP packet header magic number.
const int MACHINE_PREPARE_DATA_2 = 32130; // 0x7282

/// A class containing constants for user privilege levels.
class Privilege {
  /// Default user privilege.
  static const int USER_DEFAULT = 0;

  /// Enroller privilege.
  static const int USER_ENROLLER = 2;

  /// Manager privilege.
  static const int USER_MANAGER = 6;

  /// Administrator privilege.
  static const int USER_ADMIN = 14;
}

/// A class containing constants for attendance status codes.
class AttendanceStatus {
  /// Check-in status.
  static const int CHECK_IN = 0;

  /// Check-out status.
  static const int CHECK_OUT = 1;

  /// Break-out status.
  static const int BREAK_OUT = 2;

  /// Break-in status.
  static const int BREAK_IN = 3;

  /// Overtime-in status.
  static const int OVERTIME_IN = 4;

  /// Overtime-out status.
  static const int OVERTIME_OUT = 5;
}
