#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SD카드용 프레임 바이너리 생성기
--------------------------------
PL의 s_axis는 32비트 {Q[15:0], I[15:0]}를 한 샘플로 받는다.
한 프레임 = 128*128 = 16384 샘플 = 64KB.
순서는 처프-major (처프0의 128샘플, 처프1의 128샘플, ...) = PL 입력 순서.

출력:
  synth.bin       : 합성 프레임 1개 (검증 모드용)
  real_0000.bin.. : ColoRadar 프레임들 (실데이터 모드용, 순차 재생)
이 파일들을 SD카드 루트에 복사한다.
"""
import numpy as np, glob, os

N = 128
UPLOAD = "/mnt/user-data/uploads"

def to_bin(cube, fname):
    """cube[chirp, sample] 복소 -> 32bit {Q,I} little-endian .bin"""
    I = np.clip(np.round(cube.real), -32768, 32767).astype(np.int16)
    Q = np.clip(np.round(cube.imag), -32768, 32767).astype(np.int16)
    words = ((Q.astype(np.uint32) & 0xFFFF) << 16) | (I.astype(np.uint32) & 0xFFFF)
    words.astype('<u4').tofile(fname)        # C-order = 처프-major
    print(f"[저장] {fname}  ({words.size} 샘플, {words.nbytes} bytes)")

# ---------- 합성 프레임 (검증 모드) ----------
FC, B, TC = 77e9, 4e9, 40e-6
FS, S, C = N/TC, B/TC, 3e8
LAMBDA = C/FC; ADC = 2**15-1
targets = [(1.0, 2.0, 1.0), (2.5, -5.0, 0.7), (4.0, 0.0, 0.5)]
n = np.arange(N)
synth = np.zeros((N, N), complex)
for d, v, a in targets:
    f_if = 2*S*d/C
    for m in range(N):
        ph = 4*np.pi*v*TC*m/LAMBDA
        synth[m] += a*np.exp(1j*(2*np.pi*f_if*(n/FS) + ph))
synth += 0.02*(np.random.randn(N, N) + 1j*np.random.randn(N, N))
synth *= (ADC*0.9)/np.max(np.abs(synth))
to_bin(synth, "synth.bin")

# ---------- ColoRadar 프레임들 (실데이터 모드) ----------
bins = sorted(glob.glob(os.path.join(UPLOAD, "*frame_*.bin")))
idx = 0
for b in bins:
    try:
        raw = np.fromfile(b, np.int16).reshape(3, 4, N, N, 2)
    except ValueError:
        continue
    cube = raw[0, 0, :, :, 0] + 1j*raw[0, 0, :, :, 1]   # TX0/RX0
    cube = cube - cube.mean()                            # DC 제거
    to_bin(cube, f"real_{idx:04d}.bin")
    idx += 1

if idx == 0:
    print("  (ColoRadar bin 없음 - synth.bin만 생성)")
else:
    print(f"  ColoRadar {idx}개 프레임 생성. 더 받으면 같은 폴더에 두고 재실행하면 된다.")
