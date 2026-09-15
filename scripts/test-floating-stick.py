#!/usr/bin/env python3
"""Exercise the production UIKit stick on an already booted iOS Simulator."""
import os
import platform
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'ios/SpaghettiPadShell.mm').read_text()
start = source.index('@interface SpaghettiPadTouchStick : UIView')
end = source.index('\nstatic CGRect SpaghettiPad_CenteredFrame', start)
with tempfile.TemporaryDirectory(prefix='spaghettipad-touch-') as temporary:
    build = Path(temporary)
    (build / 'SpaghettiPadTouchStick.inc').write_text(source[start:end])
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    binary = build / 'floating-stick-test'
    subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-target',
                    f'{platform.machine()}-apple-ios15.0-simulator', '-isysroot', sdk,
                    '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'CoreGraphics',
                    '-I', str(build), str(root / 'tests/floating_stick_test.mm'),
                    '-o', str(binary)], check=True)
    subprocess.run(['xcrun', 'simctl', 'spawn', os.environ.get('SIMULATOR_DEVICE', 'booted'), str(binary)], check=True)
