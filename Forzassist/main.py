from __future__ import annotations

import sys

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent

if str(APP_DIR) not in sys.path:

    sys.path.insert(0, str(APP_DIR))

QUrl = None

QTimer = None

qInstallMessageHandler = None

QGuiApplication = None

QFontDatabase = None

QIcon = None

QQmlApplicationEngine = None

def _import_pyside() -> bool:

    global QUrl, QTimer, qInstallMessageHandler, QGuiApplication, QFontDatabase, QIcon, QQmlApplicationEngine

    try:

        from PySide6.QtCore import QUrl as _QUrl, QTimer as _QTimer, qInstallMessageHandler as _qInstallMessageHandler

        from PySide6.QtGui import QGuiApplication as _QGuiApplication, QFontDatabase as _QFontDatabase, QIcon as _QIcon

        from PySide6.QtQml import QQmlApplicationEngine as _QQmlApplicationEngine

    except BaseException:

        try:

            import traceback

            _append_startup_log("PySide6 import failed:")

            _append_startup_log(traceback.format_exc())

        except Exception:

            pass

        return False

    QUrl = _QUrl

    QTimer = _QTimer

    qInstallMessageHandler = _qInstallMessageHandler

    QGuiApplication = _QGuiApplication

    QFontDatabase = _QFontDatabase

    QIcon = _QIcon

    QQmlApplicationEngine = _QQmlApplicationEngine

    return True

def _import_backend():

    try:

        from forzassist_backend import AssistBackend

        return AssistBackend

    except BaseException:

        try:

            import traceback

            _append_startup_log("AssistBackend import failed:")

            _append_startup_log(traceback.format_exc())

        except Exception:

            pass

        return None

def _startup_log_path() -> Path:

    import os

    appdata = os.environ.get("APPDATA")

    if appdata:

        folder = Path(appdata) / "Forzassist"

    else:

        folder = Path.home() / ".forzassist"

    folder.mkdir(parents=True, exist_ok=True)

    return folder / "startup_error.log"

def _append_startup_log(message: str) -> None:

    try:

        with _startup_log_path().open("a", encoding="utf-8") as f:

            f.write(str(message).rstrip() + "\n")

    except Exception:

        pass

def _install_qt_message_logger() -> None:

    def _handler(mode, context, message):

        try:

            loc = ""

            if context and getattr(context, "file", None):

                loc = f" ({context.file}:{context.line})"

            _append_startup_log(f"[Qt] {message}{loc}")

        except Exception:

            pass

    try:

        if qInstallMessageHandler is not None:

            qInstallMessageHandler(_handler)

    except Exception:

        pass

def _load_font_family(font_path: Path) -> str | None:

    if not font_path.exists():

        return None

    font_id = QFontDatabase.addApplicationFont(str(font_path))

    if font_id < 0:

        return None

    families = QFontDatabase.applicationFontFamilies(font_id)

    if not families:

        return None

    return families[0]

def _find_font(base_dir: Path, patterns: list[str]) -> Path | None:

    search_dirs = [

        base_dir / "assets" / "fonts",

        base_dir / "fonts",

        base_dir,

        Path.cwd() / "assets" / "fonts",

        Path.cwd() / "fonts",

        Path.cwd(),

    ]

    for directory in search_dirs:

        if not directory.exists():

            continue

        for pattern in patterns:

            matches = sorted(directory.glob(pattern))

            if matches:

                return matches[0]

    return None

def load_inter_fonts(base_dir: Path) -> tuple[str, str, str]:

    regular_path = _find_font(

        base_dir,

        [

            "Inter_18pt-Regular.ttf",

            "Inter_18pt_Regular.ttf",

            "Inter-Regular.ttf",

            "Inter*Regular*.ttf",

            "Inter*.ttf",

        ],

    )

    medium_path = _find_font(

        base_dir,

        [

            "Inter_18pt-Medium.ttf",

            "Inter_18pt-medium.ttf",

            "Inter_18pt_Medium.ttf",

            "Inter-Medium.ttf",

            "Inter*Medium*.ttf",

        ],

    )

    bold_path = _find_font(

        base_dir,

        [

            "Inter_18pt-bold.ttf",

            "Inter_18pt-Bold.ttf",

            "Inter_18pt_Bold.ttf",

            "Inter-Bold.ttf",

            "Inter*Bold*.ttf",

        ],

    )

    regular_family = _load_font_family(regular_path) if regular_path else None

    medium_family = _load_font_family(medium_path) if medium_path else None

    bold_family = _load_font_family(bold_path) if bold_path else None

    if regular_path is None:

        print("Inter regular font not found. Checked assets/fonts, fonts, app folder, and current working directory.")

    else:

        print(f"Loaded regular font: {regular_path}")

    if medium_path is None:

        print("Inter medium font not found. Falling back to regular family with Font.Medium weight.")

    else:

        print(f"Loaded medium font: {medium_path}")

    if bold_path is None:

        print("Inter bold font not found. Checked assets/fonts, fonts, app folder, and current working directory.")

    else:

        print(f"Loaded bold font: {bold_path}")

    regular_family = regular_family or "Inter"

    medium_family = medium_family or regular_family

    bold_family = bold_family or regular_family

    return regular_family, medium_family, bold_family

def get_base_dir() -> Path:

    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):

        return Path(sys._MEIPASS)

    return Path(__file__).resolve().parent

def main() -> int:

    try:

        _startup_log_path().write_text("", encoding="utf-8")

    except Exception:

        pass

    _append_startup_log("Forzassist startup")

    _append_startup_log(f"healthcheck={'--healthcheck' in sys.argv}")

    if not _import_pyside():

        return 1

    _install_qt_message_logger()

    _append_startup_log(f"argv={sys.argv}")

    _append_startup_log(f"frozen={getattr(sys, 'frozen', False)}")

    _append_startup_log(f"_MEIPASS={getattr(sys, '_MEIPASS', None)}")

    app = QGuiApplication(sys.argv)

    app.setApplicationName("Forzassist")

    icon_path = get_base_dir() / "forzassist.ico"

    if icon_path.exists() and QIcon is not None:

        app.setWindowIcon(QIcon(str(icon_path)))

    base_dir = get_base_dir()

    args = [a for a in sys.argv[1:] if a != "--healthcheck"]

    qml_name = args[0] if args else "Main.qml"

    qml_file = base_dir / qml_name

    _append_startup_log(f"base_dir={base_dir}")

    _append_startup_log(f"qml_file={qml_file}")

    _append_startup_log(f"qml_exists={qml_file.exists()}")

    inter_regular, inter_medium, inter_bold = load_inter_fonts(base_dir)

    AssistBackend = _import_backend()

    if AssistBackend is None:

        return 1

    backend = AssistBackend()

    app.aboutToQuit.connect(backend.shutdown)

    engine = QQmlApplicationEngine()

    engine.addImportPath(str(qml_file.parent))

    engine.rootContext().setContextProperty("interRegularFamily", inter_regular)

    engine.rootContext().setContextProperty("interMediumFamily", inter_medium)

    engine.rootContext().setContextProperty("interBoldFamily", inter_bold)

    engine.rootContext().setContextProperty("backend", backend)

    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():

        msg = f"Failed to load QML: {qml_file}"

        print(msg, file=sys.stderr)

        _append_startup_log(msg)

        try:

            if qml_file.parent.exists():

                nearby = [p.name for p in qml_file.parent.iterdir()]

                _append_startup_log(f"base_dir_files={nearby[:80]}")

        except Exception as exc:

            _append_startup_log(f"Could not list base_dir files: {exc}")

        return 1

    _append_startup_log("QML loaded successfully")

    if "--healthcheck" in sys.argv:

        _append_startup_log("Healthcheck mode: QML loaded; quitting.")

        QTimer.singleShot(250, app.quit)

    return app.exec()

if __name__ == "__main__":

    try:

        exit_code = main()

        if exit_code:

            _append_startup_log(f"main() returned non-zero exit code: {exit_code}")

        raise SystemExit(exit_code)

    except SystemExit as exc:

        if exc.code not in (0, None):

            _append_startup_log(f"SystemExit: {exc.code}")

        raise

    except BaseException:

        try:

            import traceback

            _append_startup_log(traceback.format_exc())

        except Exception:

            pass

        raise
