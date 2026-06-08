from __future__ import annotations

import ctypes

import ctypes.wintypes

import math

import json

import os

from pathlib import Path

import socket

import struct

import threading

import time

from dataclasses import dataclass

from typing import Optional

from PySide6.QtCore import QObject, Property, Signal, Slot

try:

    import vgamepad as vg

except Exception:

    vg = None

_xinput_dll = None

for _dll_name in ("xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"):

    try:

        _xinput_dll = ctypes.windll.LoadLibrary(_dll_name)

        break

    except Exception:

        continue

class XINPUT_GAMEPAD(ctypes.Structure):

    _fields_ = [

        ("wButtons", ctypes.wintypes.WORD),

        ("bLeftTrigger", ctypes.c_ubyte),

        ("bRightTrigger", ctypes.c_ubyte),

        ("sThumbLX", ctypes.c_short),

        ("sThumbLY", ctypes.c_short),

        ("sThumbRX", ctypes.c_short),

        ("sThumbRY", ctypes.c_short),

    ]

class XINPUT_STATE(ctypes.Structure):

    _fields_ = [("dwPacketNumber", ctypes.wintypes.DWORD), ("Gamepad", XINPUT_GAMEPAD)]

XI_DPAD_UP = 1

XI_DPAD_DOWN = 2

XI_DPAD_LEFT = 4

XI_DPAD_RIGHT = 8

XI_START = 16

XI_BACK = 32

XI_LEFT_THUMB = 64

XI_RIGHT_THUMB = 128

XI_LEFT_SHOULDER = 256

XI_RIGHT_SHOULDER = 512

XI_A = 4096

XI_B = 8192

XI_X = 16384

XI_Y = 32768

AXIS_LEFT_X = 0

AXIS_LEFT_Y = 1

AXIS_RIGHT_X = 2

AXIS_RIGHT_Y = 3

AXIS_LT = 4

AXIS_RT = 5

BTN_A = 0

BTN_B = 1

BTN_X = 2

BTN_Y = 3

BTN_LB = 4

BTN_RB = 5

BTN_BACK = 6

BTN_START = 7

BTN_LS = 8

BTN_RS = 9

BTN_DPAD_UP = 10

BTN_DPAD_DOWN = 11

BTN_DPAD_LEFT = 12

BTN_DPAD_RIGHT = 13

BUTTON_MASKS: dict[int, tuple[str, int]] = {

    BTN_A: ("A", XI_A),

    BTN_B: ("B", XI_B),

    BTN_X: ("X", XI_X),

    BTN_Y: ("Y", XI_Y),

    BTN_LB: ("LB", XI_LEFT_SHOULDER),

    BTN_RB: ("RB", XI_RIGHT_SHOULDER),

    BTN_BACK: ("BACK", XI_BACK),

    BTN_START: ("START", XI_START),

    BTN_LS: ("LS", XI_LEFT_THUMB),

    BTN_RS: ("RS", XI_RIGHT_THUMB),

    BTN_DPAD_UP: ("↑", XI_DPAD_UP),

    BTN_DPAD_DOWN: ("↓", XI_DPAD_DOWN),

    BTN_DPAD_LEFT: ("←", XI_DPAD_LEFT),

    BTN_DPAD_RIGHT: ("→", XI_DPAD_RIGHT),

}

PACKET_FIELDS = [

    ("IsRaceOn", "i"), ("TimestampMS", "I"), ("EngineMaxRpm", "f"), ("EngineIdleRpm", "f"),

    ("CurrentEngineRpm", "f"), ("AccelerationX", "f"), ("AccelerationY", "f"), ("AccelerationZ", "f"),

    ("VelocityX", "f"), ("VelocityY", "f"), ("VelocityZ", "f"), ("AngularVelocityX", "f"),

    ("AngularVelocityY", "f"), ("AngularVelocityZ", "f"), ("Yaw", "f"), ("Pitch", "f"), ("Roll", "f"),

    ("NormalizedSuspensionTravelFrontLeft", "f"), ("NormalizedSuspensionTravelFrontRight", "f"),

    ("NormalizedSuspensionTravelRearLeft", "f"), ("NormalizedSuspensionTravelRearRight", "f"),

    ("TireSlipRatioFrontLeft", "f"), ("TireSlipRatioFrontRight", "f"), ("TireSlipRatioRearLeft", "f"),

    ("TireSlipRatioRearRight", "f"), ("WheelRotationSpeedFrontLeft", "f"), ("WheelRotationSpeedFrontRight", "f"),

    ("WheelRotationSpeedRearLeft", "f"), ("WheelRotationSpeedRearRight", "f"), ("WheelOnRumbleStripFrontLeft", "i"),

    ("WheelOnRumbleStripFrontRight", "i"), ("WheelOnRumbleStripRearLeft", "i"), ("WheelOnRumbleStripRearRight", "i"),

    ("WheelInPuddleFrontLeft", "i"), ("WheelInPuddleFrontRight", "i"), ("WheelInPuddleRearLeft", "i"),

    ("WheelInPuddleRearRight", "i"), ("SurfaceRumbleFrontLeft", "f"), ("SurfaceRumbleFrontRight", "f"),

    ("SurfaceRumbleRearLeft", "f"), ("SurfaceRumbleRearRight", "f"), ("TireSlipAngleFrontLeft", "f"),

    ("TireSlipAngleFrontRight", "f"), ("TireSlipAngleRearLeft", "f"), ("TireSlipAngleRearRight", "f"),

    ("TireCombinedSlipFrontLeft", "f"), ("TireCombinedSlipFrontRight", "f"), ("TireCombinedSlipRearLeft", "f"),

    ("TireCombinedSlipRearRight", "f"), ("SuspensionTravelMetersFrontLeft", "f"),

    ("SuspensionTravelMetersFrontRight", "f"), ("SuspensionTravelMetersRearLeft", "f"),

    ("SuspensionTravelMetersRearRight", "f"), ("CarOrdinal", "i"), ("CarClass", "i"),

    ("CarPerformanceIndex", "i"), ("DrivetrainType", "i"), ("NumCylinders", "i"), ("CarGroup", "I"),

    ("SmashableVelDiff", "f"), ("SmashableMass", "f"), ("PositionX", "f"), ("PositionY", "f"),

    ("PositionZ", "f"), ("Speed", "f"), ("Power", "f"), ("Torque", "f"), ("TireTempFrontLeft", "f"),

    ("TireTempFrontRight", "f"), ("TireTempRearLeft", "f"), ("TireTempRearRight", "f"), ("Boost", "f"),

    ("Fuel", "f"), ("DistanceTraveled", "f"), ("BestLap", "f"), ("LastLap", "f"), ("CurrentLap", "f"),

    ("CurrentRaceTime", "f"), ("LapNumber", "H"), ("RacePosition", "B"), ("Accel", "B"), ("Brake", "B"),

    ("Clutch", "B"), ("HandBrake", "B"), ("Gear", "B"), ("Steer", "b"), ("NormalizedDrivingLine", "b"),

    ("NormalizedAIBrakeDifference", "b"),

]

PACK_FMT = "<" + "".join(fmt for _, fmt in PACKET_FIELDS)

FIELD_NAMES = [name for name, _ in PACKET_FIELDS]

PACKET_SIZE = struct.calcsize(PACK_FMT)

FORZA_FULL_LOCK_STICK = 1.0

REVERSE_GEAR_SLIP_FF_MULT = 0.0

REAL_CONTROLLER_INDEX = 0

GAMEPAD_HZ = 120

OVERLAY_HZ = 60

def build_vgamepad_button_map() -> dict[int, object]:

    if vg is None:

        return {}

    return {

        BTN_A: vg.XUSB_BUTTON.XUSB_GAMEPAD_A,

        BTN_B: vg.XUSB_BUTTON.XUSB_GAMEPAD_B,

        BTN_X: vg.XUSB_BUTTON.XUSB_GAMEPAD_X,

        BTN_Y: vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,

        BTN_LB: vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,

        BTN_RB: vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,

        BTN_BACK: vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,

        BTN_START: vg.XUSB_BUTTON.XUSB_GAMEPAD_START,

        BTN_LS: vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,

        BTN_RS: vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,

        BTN_DPAD_UP: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,

        BTN_DPAD_DOWN: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,

        BTN_DPAD_LEFT: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,

        BTN_DPAD_RIGHT: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,

    }

VGAMEPAD_BUTTONS = build_vgamepad_button_map()

def parse_packet(data: bytes) -> Optional[dict]:

    if len(data) < PACKET_SIZE:

        return None

    return dict(zip(FIELD_NAMES, struct.unpack_from(PACK_FMT, data)))

def clamp(val: float, lo: float, hi: float) -> float:

    return max(lo, min(hi, val))

def sign(val: float) -> float:

    if val > 0:

        return 1.0

    if val < 0:

        return -1.0

    return 0.0

def apply_deadzone(val: float, dz: float) -> float:

    if abs(val) < dz:

        return 0.0

    rescaled = (abs(val) - dz) / (1.0 - dz)

    return sign(val) * rescaled

def body_slip_deg(vx: float, vz: float) -> float:

    if abs(vz) < 0.01:

        return 0.0

    return math.degrees(math.atan2(vx, abs(vz)))

def spin_solver_components(

    vx: float,

    vz: float,

    yaw_rate: float,

    intent_max_yaw_rate: float,

) -> tuple[float, float, float]:

    speed_sq = vx * vx + vz * vz

    if speed_sq < 0.0001:

        return 1.0, 0.0, 0.0

    speed = math.sqrt(speed_sq)

    forwardness = clamp(vz / speed, -1.0, 1.0)

    rearward_phase = clamp((1.0 - forwardness) * 0.5, 0.0, 1.0)

    side_phase = clamp(1.0 - abs(forwardness), 0.0, 1.0)

    y = abs(yaw_rate) / max(intent_max_yaw_rate, 0.001)

    y2 = y * y

    spin_energy = (y2 * y2) / (1.0 + y2 * y2)

    release = clamp(rearward_phase * spin_energy, 0.0, 1.0)

    normal_authority = 1.0 - release

    catch_authority = clamp(side_phase * release, 0.0, 1.0)

    catch_phase = math.sin(side_phase * (math.pi * 0.5))

    catch_curve = math.asin(clamp(catch_phase * spin_energy, -1.0, 1.0)) / (math.pi * 0.5)

    catch_target = -sign(yaw_rate) * catch_curve * FORZA_FULL_LOCK_STICK

    return normal_authority, catch_authority, catch_target

def pygame_axis_to_vg(val: float) -> int:

    return int(clamp(val, -1.0, 1.0) * 32767)

def _norm_thumb(val: int) -> float:

    return val / 32767.0 if val >= 0 else val / 32768.0

def _norm_trigger(val: int) -> float:

    return val / 255.0

def compute_drift_style_values(slider_percent: float) -> tuple[float, float, float]:

    p = max(0.0, min(100.0, float(slider_percent)))

    if p <= 50.0:

        t = p / 50.0

        f = 0.60 + (1.00 - 0.60) * t

    else:

        t = (p - 50.0) / 50.0

        f = 1.00 + (1.40 - 1.00) * t

    intent_max_slip_angle = 90.0 * f

    intent_max_yaw_rate = 1.7 * math.sqrt(f)

    slip_ff_gain = (1.0 + intent_max_yaw_rate) / intent_max_slip_angle

    return intent_max_slip_angle, intent_max_yaw_rate, slip_ff_gain

class XInputController:

    def __init__(self, port: int = 0):

        if _xinput_dll is None:

            raise RuntimeError("No XInput DLL found")

        self.port = port

        self._state = XINPUT_STATE()

        self._update()

    def _update(self) -> bool:

        result = _xinput_dll.XInputGetState(self.port, ctypes.byref(self._state))

        return result == 0

    @property

    def connected(self) -> bool:

        return self._update()

    def get_axis(self, axis_id: int) -> float:

        gp = self._state.Gamepad

        if axis_id == AXIS_LEFT_X:

            return _norm_thumb(gp.sThumbLX)

        if axis_id == AXIS_LEFT_Y:

            return -_norm_thumb(gp.sThumbLY)

        if axis_id == AXIS_RIGHT_X:

            return _norm_thumb(gp.sThumbRX)

        if axis_id == AXIS_RIGHT_Y:

            return -_norm_thumb(gp.sThumbRY)

        if axis_id == AXIS_LT:

            return _norm_trigger(gp.bLeftTrigger)

        if axis_id == AXIS_RT:

            return _norm_trigger(gp.bRightTrigger)

        return 0.0

    def get_button(self, btn_id: int) -> bool:

        mask = BUTTON_MASKS.get(btn_id, ("", 0))[1]

        return bool(self._state.Gamepad.wButtons & mask)

    def get_name(self) -> str:

        return f"XInput Controller (port {self.port})"

def find_xinput_controller(preferred_port: int = 0) -> Optional[XInputController]:

    if _xinput_dll is None:

        return None

    ports = [preferred_port] + [p for p in range(4) if p != preferred_port]

    for port in ports:

        try:

            ctrl = XInputController(port)

        except Exception:

            continue

        if ctrl.connected:

            return ctrl

    return None

@dataclass

class AssistConfig:

    telemetry_ip: str = "127.0.0.1"

    telemetry_port: int = 5600

    drift_style_percent: float = 50.0

    double_shift_fix: bool = False

    upshift_button: int = BTN_B

    downshift_button: int = BTN_X

class AssistState:

    def __init__(self):

        self.telemetry: dict = {}

        self.tel_time: float = 0.0

        self.is_drifting: bool = False

        self.reverse_gear_active: bool = False

        self.reverse_gear_ff_mult: float = 1.0

        self.raw_steer_target: float = 0.0

        self.steer_saturated: bool = False

class AssistBackend(QObject):

    assistRunningChanged = Signal()

    overlayValuesChanged = Signal(float, float, float, float, float, float)

    bindCaptured = Signal(str, str, int)

    bindCaptureCancelled = Signal(str)

    statusChanged = Signal(str)

    backendError = Signal(str)

    configLoaded = Signal(float, bool, str, int, str, int, bool, str, int, int, int, float)

    def __init__(self):

        super().__init__()

        self._config = AssistConfig()

        self._config_lock = threading.RLock()

        self._state = AssistState()

        self._state_lock = threading.RLock()

        self._assist_running = False

        self._stop_event = threading.Event()

        self._worker_thread: Optional[threading.Thread] = None

        self._telemetry_thread: Optional[threading.Thread] = None

        self._bind_lock = threading.RLock()

        self._capture_thread: Optional[threading.Thread] = None

        self._capture_cancel = threading.Event()

    def _config_dir(self) -> Path:

        appdata = os.environ.get("APPDATA")

        if appdata:

            path = Path(appdata) / "Forzassist"

        else:

            path = Path.home() / ".forzassist"

        path.mkdir(parents=True, exist_ok=True)

        return path

    def _config_path(self) -> Path:

        return self._config_dir() / "config.json"

    def _button_display_name(self, button_id: int) -> str:

        return BUTTON_MASKS.get(int(button_id), ("B", 0))[0]

    def _safe_button_id(self, value, fallback: int) -> int:

        try:

            button_id = int(value)

        except Exception:

            return fallback

        return button_id if button_id in BUTTON_MASKS else fallback

    def _read_config_file(self) -> dict:

        path = self._config_path()

        if not path.exists():

            return {}

        try:

            with path.open("r", encoding="utf-8") as f:

                data = json.load(f)

            return data if isinstance(data, dict) else {}

        except Exception as exc:

            self._emit_error(f"Could not read config file: {exc}")

            return {}

    def _write_config_file(self, data: dict) -> None:

        path = self._config_path()

        tmp_path = path.with_suffix(".json.tmp")

        try:

            with tmp_path.open("w", encoding="utf-8") as f:

                json.dump(data, f, indent=2)

            tmp_path.replace(path)

        except Exception as exc:

            self._emit_error(f"Could not save config file: {exc}")

    @Slot()

    def loadConfig(self) -> None:

        data = self._read_config_file()

        drift_style_percent = float(data.get("steering_response_percent", 50.0))

        drift_style_percent = clamp(drift_style_percent, 0.0, 100.0)

        double_shift_fix = bool(data.get("double_shift_fix_enabled", False))

        upshift_button = self._safe_button_id(data.get("upshift_button_id", BTN_B), BTN_B)

        downshift_button = self._safe_button_id(data.get("downshift_button_id", BTN_X), BTN_X)

        pedal_overlay_enabled = bool(data.get("pedal_overlay_enabled", False))

        telemetry_ip = str(data.get("telemetry_ip", "127.0.0.1"))

        try:

            telemetry_port = int(data.get("telemetry_port", 5600))

        except Exception:

            telemetry_port = 5600

        telemetry_port = int(clamp(telemetry_port, 0, 99999))

        try:

            overlay_x = int(data.get("pedal_overlay_x", -1))

        except Exception:

            overlay_x = -1

        try:

            overlay_y = int(data.get("pedal_overlay_y", -1))

        except Exception:

            overlay_y = -1

        try:

            overlay_scale = float(data.get("pedal_overlay_scale", 1.0))

        except Exception:

            overlay_scale = 1.0

        overlay_scale = clamp(overlay_scale, 0.35, 2.0)

        with self._config_lock:

            self._config.telemetry_ip = telemetry_ip

            self._config.telemetry_port = telemetry_port

            self._config.drift_style_percent = drift_style_percent

            self._config.double_shift_fix = double_shift_fix

            self._config.upshift_button = upshift_button

            self._config.downshift_button = downshift_button

        self.configLoaded.emit(

            float(drift_style_percent),

            bool(double_shift_fix),

            self._button_display_name(upshift_button),

            int(upshift_button),

            self._button_display_name(downshift_button),

            int(downshift_button),

            bool(pedal_overlay_enabled),

            str(telemetry_ip),

            int(telemetry_port),

            int(overlay_x),

            int(overlay_y),

            float(overlay_scale),

        )

    @Slot(float, bool, int, int, bool, str, str, int, int, float)

    def saveConfig(

        self,

        steering_response_percent: float,

        double_shift_fix_enabled: bool,

        upshift_button_id: int,

        downshift_button_id: int,

        pedal_overlay_enabled: bool,

        telemetry_ip: str,

        telemetry_port_text: str,

        pedal_overlay_x: int,

        pedal_overlay_y: int,

        pedal_overlay_scale: float,

    ) -> None:

        try:

            telemetry_port = int(str(telemetry_port_text).strip())

        except Exception:

            telemetry_port = 5600

        upshift_button_id = self._safe_button_id(upshift_button_id, BTN_B)

        downshift_button_id = self._safe_button_id(downshift_button_id, BTN_X)

        data = {

            "version": 1,

            "steering_response_percent": int(clamp(float(steering_response_percent), 0.0, 100.0)),

            "double_shift_fix_enabled": bool(double_shift_fix_enabled),

            "upshift_button_id": int(upshift_button_id),

            "upshift_button_name": self._button_display_name(upshift_button_id),

            "downshift_button_id": int(downshift_button_id),

            "downshift_button_name": self._button_display_name(downshift_button_id),

            "pedal_overlay_enabled": bool(pedal_overlay_enabled),

            "pedal_overlay_x": int(pedal_overlay_x),

            "pedal_overlay_y": int(pedal_overlay_y),

            "pedal_overlay_scale": float(clamp(float(pedal_overlay_scale), 0.35, 2.0)),

            "telemetry_ip": str(telemetry_ip).strip() or "127.0.0.1",

            "telemetry_port": int(clamp(telemetry_port, 0, 99999)),

        }

        self._write_config_file(data)

    @Slot(result=str)

    def configPath(self) -> str:

        return str(self._config_path())

    def _get_assist_running(self) -> bool:

        return self._assist_running

    assistRunning = Property(bool, _get_assist_running, notify=assistRunningChanged)

    def _emit_status(self, message: str) -> None:

        print(message)

        self.statusChanged.emit(message)

    def _emit_error(self, message: str) -> None:

        print(message)

        self.backendError.emit(message)

        self.statusChanged.emit(message)

    @Slot()

    def toggleAssist(self) -> None:

        if self._assist_running:

            self.stopAssist()

        else:

            self.startAssist()

    @Slot()

    def startAssist(self) -> None:

        if self._assist_running:

            return

        if vg is None:

            self._emit_error("vgamepad is not installed. Install vgamepad/ViGEmBus before starting the assist.")

            return

        if _xinput_dll is None:

            self._emit_error("No XInput DLL found. This assist requires Windows/XInput.")

            return

        self._stop_event.clear()

        self._state = AssistState()

        self._worker_thread = threading.Thread(target=self._assist_loop, name="ForzassistWorker", daemon=True)

        self._telemetry_thread = threading.Thread(target=self._telemetry_loop, name="ForzassistTelemetry", daemon=True)

        self._assist_running = True

        self.assistRunningChanged.emit()

        self._telemetry_thread.start()

        self._worker_thread.start()

        self._emit_status("Assist started.")

    @Slot()

    def stopAssist(self) -> None:

        if not self._assist_running:

            return

        self._stop_event.set()

        for thread in (self._worker_thread, self._telemetry_thread):

            if thread and thread.is_alive():

                thread.join(timeout=0.8)

        self._worker_thread = None

        self._telemetry_thread = None

        self._assist_running = False

        self.assistRunningChanged.emit()

        self.overlayValuesChanged.emit(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

        self._emit_status("Assist stopped.")

    @Slot()

    def shutdown(self) -> None:

        self._capture_cancel.set()

        self.stopAssist()

    @Slot(float)

    def setDriftStylePercent(self, percent: float) -> None:

        with self._config_lock:

            self._config.drift_style_percent = clamp(float(percent), 0.0, 100.0)

    @Slot(str)

    def setTelemetryIp(self, ip: str) -> None:

        ip = str(ip).strip()

        if not ip:

            return

        with self._config_lock:

            self._config.telemetry_ip = ip

    @Slot(str)

    def setTelemetryPort(self, port_text: str) -> None:

        try:

            port = int(str(port_text).strip())

        except Exception:

            return

        port = int(clamp(port, 0, 99999))

        with self._config_lock:

            self._config.telemetry_port = port

    @Slot(bool)

    def setDoubleShiftFixChecked(self, checked: bool) -> None:

        with self._config_lock:

            self._config.double_shift_fix = bool(checked)

    @Slot(str)

    def startBinding(self, which: str) -> None:

        which = str(which).strip().lower()

        if which not in ("upshift", "downshift"):

            return

        with self._bind_lock:

            self._capture_cancel.set()

            if self._capture_thread and self._capture_thread.is_alive():

                self._capture_thread.join(timeout=0.25)

            self._capture_cancel = threading.Event()

            self._capture_thread = threading.Thread(

                target=self._capture_button_loop,

                args=(which, self._capture_cancel),

                daemon=True,

                name=f"ForzassistBindCapture-{which}",

            )

            self._capture_thread.start()

    def _capture_button_loop(self, which: str, cancel_event: threading.Event) -> None:

        ctrl = find_xinput_controller(preferred_port=REAL_CONTROLLER_INDEX)

        if ctrl is None:

            self._emit_error("No XInput controller found for binding.")

            self.bindCaptureCancelled.emit(which)

            return

        deadline = time.time() + 15.0

        while time.time() < deadline and not cancel_event.is_set():

            ctrl._update()

            if not any(ctrl.get_button(btn_id) for btn_id in BUTTON_MASKS):

                break

            time.sleep(0.02)

        while time.time() < deadline and not cancel_event.is_set():

            ctrl._update()

            for btn_id, (name, _mask) in BUTTON_MASKS.items():

                if ctrl.get_button(btn_id):

                    with self._config_lock:

                        if which == "upshift":

                            self._config.upshift_button = btn_id

                        else:

                            self._config.downshift_button = btn_id

                    self.bindCaptured.emit(which, name, btn_id)

                    return

            time.sleep(0.01)

        self.bindCaptureCancelled.emit(which)

    def _copy_config(self) -> AssistConfig:

        with self._config_lock:

            return AssistConfig(

                telemetry_ip=self._config.telemetry_ip,

                telemetry_port=self._config.telemetry_port,

                drift_style_percent=self._config.drift_style_percent,

                double_shift_fix=self._config.double_shift_fix,

                upshift_button=self._config.upshift_button,

                downshift_button=self._config.downshift_button,

            )

    def _telemetry_loop(self) -> None:

        sock: Optional[socket.socket] = None

        bound_to: Optional[tuple[str, int]] = None

        while not self._stop_event.is_set():

            cfg = self._copy_config()

            target = (cfg.telemetry_ip, cfg.telemetry_port)

            if sock is None or bound_to != target:

                if sock is not None:

                    try:

                        sock.close()

                    except Exception:

                        pass

                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

                sock.settimeout(0.1)

                try:

                    sock.bind(target)

                    bound_to = target

                    self._emit_status(f"Telemetry listening on {target[0]}:{target[1]}")

                except Exception as exc:

                    self._emit_error(f"Could not bind telemetry socket on {target[0]}:{target[1]}: {exc}")

                    bound_to = None

                    try:

                        sock.close()

                    except Exception:

                        pass

                    sock = None

                    time.sleep(0.4)

                    continue

            try:

                data, _addr = sock.recvfrom(1024)

                packet = parse_packet(data)

                if packet:

                    with self._state_lock:

                        self._state.telemetry = packet

                        self._state.tel_time = time.time()

            except socket.timeout:

                pass

            except OSError:

                pass

            except Exception:

                pass

        if sock is not None:

            try:

                sock.close()

            except Exception:

                pass

    def _detect_drift(self, tel: dict) -> bool:

        if tel.get("Gear", 1) == 0:

            return False

        vx = tel.get("VelocityX", 0.0)

        vz = tel.get("VelocityZ", 0.0)

        bslip = abs(body_slip_deg(vx, vz))

        return bslip >= 2.0

    def _solve_drift_steering(

        self,

        tel: dict,

        stick_x: float,

        st: AssistState,

        intent_max_slip_angle: float,

        intent_max_yaw_rate: float,

        slip_ff_gain: float,

    ) -> tuple[float, float, float, float]:

        yaw_rate = tel.get("AngularVelocityY", 0.0)

        vx = tel.get("VelocityX", 0.0)

        vz = tel.get("VelocityZ", 0.0)

        slip_body = body_slip_deg(vx, vz)

        if tel.get("Gear", 1) == 0:

            st.reverse_gear_active = True

            st.reverse_gear_ff_mult = 0.0

            st.raw_steer_target = stick_x

            st.steer_saturated = abs(stick_x) >= FORZA_FULL_LOCK_STICK

            return clamp(stick_x, -FORZA_FULL_LOCK_STICK, FORZA_FULL_LOCK_STICK), 1.0, 0.0, 0.0

        solver_authority, catch_authority, catch_target = spin_solver_components(

            vx, vz, yaw_rate, intent_max_yaw_rate

        )

        target_slip = stick_x * intent_max_slip_angle

        angle_error = target_slip - slip_body

        desired_yaw = angle_error / intent_max_slip_angle * intent_max_yaw_rate

        yaw_error = (desired_yaw - yaw_rate) / intent_max_yaw_rate

        gear = tel.get("Gear", 1)

        in_reverse_gear = gear == 0

        ff_mult = REVERSE_GEAR_SLIP_FF_MULT if in_reverse_gear else 1.0

        st.reverse_gear_active = in_reverse_gear

        st.reverse_gear_ff_mult = ff_mult

        baseline = slip_body * slip_ff_gain * ff_mult

        raw_target = baseline + yaw_error

        target = clamp(raw_target, -FORZA_FULL_LOCK_STICK, FORZA_FULL_LOCK_STICK)

        st.raw_steer_target = raw_target

        st.steer_saturated = abs(raw_target) >= FORZA_FULL_LOCK_STICK

        return target, solver_authority, catch_authority, catch_target

    def _compute_steering(self, tel: dict, stick_x: float, st: AssistState, cfg: AssistConfig) -> float:

        intent_angle, yaw_rate, ff_gain = compute_drift_style_values(cfg.drift_style_percent)

        is_drifting = self._detect_drift(tel)

        st.is_drifting = is_drifting

        if not is_drifting:

            self._solve_drift_steering(tel, stick_x, st, intent_angle, yaw_rate, ff_gain)

            return clamp(stick_x, -1.0, 1.0)

        drift_target, solver_authority, catch_authority, catch_target = self._solve_drift_steering(

            tel, stick_x, st, intent_angle, yaw_rate, ff_gain

        )

        blended = solver_authority * drift_target + catch_authority * catch_target

        return clamp(blended, -1.0, 1.0)

    def _zero_virtual_gamepad(self, gamepad) -> None:

        try:

            gamepad.left_joystick(x_value=0, y_value=0)

            gamepad.right_joystick(x_value=0, y_value=0)

            gamepad.left_trigger(value=0)

            gamepad.right_trigger(value=0)

            for vg_btn in VGAMEPAD_BUTTONS.values():

                gamepad.release_button(button=vg_btn)

            gamepad.update()

        except Exception:

            pass

    def _assist_loop(self) -> None:

        real_joy = find_xinput_controller(preferred_port=REAL_CONTROLLER_INDEX)

        if real_joy is None:

            self._emit_error("No XInput controller found.")

            self._assist_running = False

            self.assistRunningChanged.emit()

            self._stop_event.set()

            return

        try:

            gamepad = vg.VX360Gamepad()

        except Exception as exc:

            self._emit_error(f"Could not create virtual Xbox 360 gamepad: {exc}")

            self._assist_running = False

            self.assistRunningChanged.emit()

            self._stop_event.set()

            return

        interval = 1.0 / GAMEPAD_HZ

        overlay_interval = 1.0 / OVERLAY_HZ

        last_overlay_emit = 0.0

        try:

            while not self._stop_event.is_set():

                t0 = time.time()

                cfg = self._copy_config()

                real_joy._update()

                raw_lx = real_joy.get_axis(AXIS_LEFT_X)

                raw_ly = real_joy.get_axis(AXIS_LEFT_Y)

                raw_rx = real_joy.get_axis(AXIS_RIGHT_X)

                raw_ry = real_joy.get_axis(AXIS_RIGHT_Y)

                raw_lt = real_joy.get_axis(AXIS_LT)

                raw_rt = real_joy.get_axis(AXIS_RT)

                stick_x = apply_deadzone(raw_lx, 0.0)

                stick_y = apply_deadzone(raw_ly, 0.0)

                right_x = apply_deadzone(raw_rx, 0.0)

                right_y = apply_deadzone(raw_ry, 0.0)

                lt_norm = clamp(raw_lt, 0.0, 1.0)

                rt_norm = clamp(raw_rt, 0.0, 1.0)

                with self._state_lock:

                    tel = dict(self._state.telemetry)

                    tel_time = self._state.tel_time

                tel_stale = time.time() - tel_time > 0.2 if tel_time else True

                race_active = bool(tel and not tel_stale and tel.get("IsRaceOn", 0) == 1)

                menu_or_not_racing = not race_active

                if race_active:

                    final_steer = self._compute_steering(tel, stick_x, self._state, cfg)

                else:

                    self._state.is_drifting = False

                    self._state.reverse_gear_active = False

                    self._state.reverse_gear_ff_mult = 1.0

                    self._state.raw_steer_target = 0.0

                    self._state.steer_saturated = False

                    final_steer = stick_x

                if cfg.double_shift_fix and menu_or_not_racing:

                    self._zero_virtual_gamepad(gamepad)

                    final_steer_for_overlay = stick_x

                else:

                    gamepad.left_joystick(

                        x_value=pygame_axis_to_vg(final_steer),

                        y_value=pygame_axis_to_vg(-stick_y),

                    )

                    gamepad.right_joystick(

                        x_value=pygame_axis_to_vg(right_x),

                        y_value=pygame_axis_to_vg(-right_y),

                    )

                    gamepad.left_trigger(value=int(lt_norm * 255))

                    gamepad.right_trigger(value=int(rt_norm * 255))

                    suppressed_buttons = set()

                    if cfg.double_shift_fix:

                        suppressed_buttons.add(cfg.upshift_button)

                        suppressed_buttons.add(cfg.downshift_button)

                    for btn_idx, vg_btn in VGAMEPAD_BUTTONS.items():

                        try:

                            pressed = real_joy.get_button(btn_idx)

                            if btn_idx in suppressed_buttons:

                                pressed = False

                            if pressed:

                                gamepad.press_button(button=vg_btn)

                            else:

                                gamepad.release_button(button=vg_btn)

                        except Exception:

                            pass

                    gamepad.update()

                    final_steer_for_overlay = final_steer

                now = time.time()

                if now - last_overlay_emit >= overlay_interval:

                    if race_active:

                        throttle = clamp(tel.get("Accel", int(rt_norm * 255)) / 255.0, 0.0, 1.0)

                        brake = clamp(tel.get("Brake", int(lt_norm * 255)) / 255.0, 0.0, 1.0)

                        clutch = clamp(tel.get("Clutch", 0) / 255.0, 0.0, 1.0)

                        handbrake = clamp(tel.get("HandBrake", 0) / 255.0, 0.0, 1.0)

                    else:

                        throttle = rt_norm

                        brake = lt_norm

                        clutch = 0.0

                        handbrake = 0.0

                    assist_overlay_steer = (

                        final_steer_for_overlay

                        if race_active and self._state.is_drifting

                        else 0.0

                    )

                    player_overlay_steer = stick_x if race_active else 0.0

                    self.overlayValuesChanged.emit(

                        float(clutch),

                        float(brake),

                        float(throttle),

                        float(handbrake),

                        float(clamp(player_overlay_steer, -1.0, 1.0)),

                        float(clamp(assist_overlay_steer, -1.0, 1.0)),

                    )

                    last_overlay_emit = now

                elapsed = time.time() - t0

                wait = interval - elapsed

                if wait > 0:

                    time.sleep(wait)

        finally:

            self._zero_virtual_gamepad(gamepad)

            if self._assist_running:

                self._assist_running = False

                self.assistRunningChanged.emit()

            self.overlayValuesChanged.emit(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
