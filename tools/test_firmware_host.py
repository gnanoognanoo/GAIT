"""Compile and run the platform-independent firmware test on a host with GCC or Clang."""
from pathlib import Path
import subprocess
import tempfile
import os

root = Path(__file__).resolve().parents[1] / 'firmware'
src = root / 'src'
with tempfile.TemporaryDirectory() as temp:
    work = Path(temp)
    objects = []
    cc = [os.environ.get('ZIG'), 'cc'] if os.environ.get('ZIG') else [os.environ.get('CC', 'gcc')]
    cxx = [os.environ.get('ZIG'), 'c++'] if os.environ.get('ZIG') else [os.environ.get('CXX', 'g++')]
    for name in ('FusionAhrs', 'FusionBias', 'FusionConvention'):
        obj = work / (name + '.o')
        subprocess.run([*cc, '-std=c11', '-c',
                        str(src / 'fusion' / (name + '.c')), '-o', str(obj)], check=True)
        objects.append(str(obj))
    executable = work / ('firmware-tests.exe' if os.name == 'nt' else 'firmware-tests')
    modules = ['sensor_calibration', 'sensor_fusion', 'motion_analyzer', 'telemetry_protocol']
    subprocess.run([*cxx, '-std=gnu++17', '-I', str(src),
                    str(root / 'test/host_tests.cpp'),
                    *[str(src / (m + '.cpp')) for m in modules],
                    *objects, '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)

