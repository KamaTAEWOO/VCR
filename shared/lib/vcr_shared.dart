/// VCR Shared - Common models and protocol constants for VCR
///
/// This package is shared between VCR App (mobile) and VCR Agent (desktop CLI).
library vcr_shared;

// Protocol constants
export 'protocol.dart';

// Command type constants
export 'commands.dart';

// Models
export 'models/vcr_message.dart';
export 'models/vcr_command.dart';
export 'models/vcr_response.dart';
export 'models/frame_data.dart';
export 'models/agent_state.dart';
export 'models/welcome_data.dart';
export 'models/device_info.dart';
export 'models/shell_input_data.dart';
export 'models/shell_output_data.dart';
export 'models/shell_exit_data.dart';
export 'models/shell_resize_data.dart';
export 'models/foreground_process_data.dart';
