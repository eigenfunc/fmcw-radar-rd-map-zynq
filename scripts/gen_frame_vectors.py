#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2D FFT 통합 검증용 한 프레임(128x128) 생성기
--------------------------------------------
모드 두 가지를 같은 .mem 포맷으로 뽑는다:
  - 합성(synth)   : 거리/속도가 알려진 가짜 타겟. 통합 정확도 검증 기준.
  - 실데이터(real): ColoRadar frame_984.bin에서 TX0/RX0 한 채널 추출.

.mem 포맷(= range_fft 입력 순서):
  처프0[샘플0..127], 처프1[샘플0..127], ... , 처프127[...]
  각 줄 = 32-bit hex = {Q[15:0], I[15:0]}   (총 128*128 = 16384줄)

골든 R-D Map(power)도 계산해 피크 위치를 출력/저장한다.
"""
import numpy as np

N = 128                      # range = doppler = 128
COLORADAR_BIN = "/mnt/user-data/uploads/1780885337536_frame_984.bin"

# ---------- 공통: .mem 저장 ----------
def write_mem(cube, fname):
    """cube[chirp, sample] 복소 -> {Q,I} hex .mem"""
    I = np.clip(np.round(cube.real), -32768, 32767).astype(np.int16)
    Q = np.clip(np.round(cube.imag), -32768, 32767).astype(np.int16)
    with open(fname, "w") as f:
        for c in range(N):
            for s in range(N):
                w = ((int(Q[c, s]) & 0xFFFF) << 16) | (int(I[c, s]) & 0xFFFF)
                f.write(f"{w:08x}\n")
    print(f"[저장] {fname}  ({N*N}줄)")

# ---------- 공통: 골든 2D FFT (power) ----------
def golden_rd(cube):
    wr, wd = np.hanning(N), np.hanning(N)
    rng = np.fft.fft(cube * wr[None, :], axis=1)                 # Range FFT (sample축)
    rd  = np.fft.fftshift(np.fft.fft(rng * wd[:, None], axis=0), axes=0)  # Doppler FFT
    return np.abs(rd) ** 2                                       # power

def report_peaks(rd, label, k=4):
    flat = np.argsort(rd.ravel())[::-1]
    seen, out = set(), []
    for idx in flat:
        d, r = np.unravel_index(idx, rd.shape)
        key = (round(d / 3), round(r / 3))
        if key in seen: continue
        seen.add(key); out.append((d, r))
        if len(out) >= k: break
    print(f"  [{label}] 상위 피크 (doppler_bin, range_bin):", out)
    return out

# ============================================================
#  1) 합성 프레임
# ============================================================
FC, B, TC = 77e9, 4e9, 40e-6
FS, S, C = N / TC, B / TC, 3e8
LAMBDA = C / FC
ADC_FS = 2 ** 15 - 1
d_res = C / (2 * B); d_max = FS * C / (2 * S)
v_res = LAMBDA / (2 * N * TC); v_max = LAMBDA / (4 * TC)
print(f"합성: d_max={d_max:.2f}m d_res={d_res:.4f}m | v_max=±{v_max:.2f} v_res={v_res:.3f}")

targets = [(1.0, 2.0, 1.0), (2.5, -5.0, 0.7), (4.0, 0.0, 0.5)]
n = np.arange(N)
synth = np.zeros((N, N), dtype=complex)         # [chirp, sample]
for d, v, a in targets:
    f_if = 2 * S * d / C
    for m in range(N):
        ph = 4 * np.pi * v * TC * m / LAMBDA
        synth[m] += a * np.exp(1j * (2 * np.pi * f_if * (n / FS) + ph))
synth += 0.02 * (np.random.randn(N, N) + 1j * np.random.randn(N, N))
synth *= (ADC_FS * 0.9) / np.max(np.abs(synth))   # 풀스케일 90%

write_mem(synth, "frame_synth.mem")
rd_s = golden_rd(synth.real.round() + 1j * synth.imag.round())
np.savetxt("golden_synth_rd.txt", rd_s.ravel(), fmt="%.6e")
print("  기대 타겟 (거리,속도):", [(d, v) for d, v, _ in targets])
report_peaks(rd_s, "synth")

# ============================================================
#  2) ColoRadar 실데이터 프레임
# ============================================================
try:
    raw = np.fromfile(COLORADAR_BIN, np.int16).reshape(3, 4, N, N, 2)
    real = raw[0, 0, :, :, 0].astype(float)     # TX0, RX0
    imag = raw[0, 0, :, :, 1].astype(float)
    cube = real + 1j * imag
    cube = cube - cube.mean()                   # DC 제거
    write_mem(cube, "frame_real.mem")
    rd_r = golden_rd(cube)
    np.savetxt("golden_real_rd.txt", rd_r.ravel(), fmt="%.6e")
    report_peaks(rd_r, "real")
    have_real = True
except FileNotFoundError:
    print("  (ColoRadar bin 없음 - 합성만 생성)")
    have_real = False

# ============================================================
#  골든 R-D Map 시각화
# ============================================================
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
ncol = 2 if have_real else 1
fig, ax = plt.subplots(1, ncol, figsize=(6.5 * ncol, 5), squeeze=False)
def show(a, rd, t):
    m = 10 * np.log10(rd + 1e-9)
    im = a.imshow(m, aspect="auto", origin="lower", cmap="turbo",
                  extent=[0, N, -N // 2, N // 2])
    a.set_xlabel("Range bin"); a.set_ylabel("Doppler bin"); a.set_title(t)
    fig.colorbar(im, ax=a, label="Power [dB]")
show(ax[0, 0], rd_s, "Synthetic frame (golden 2D FFT)")
if have_real:
    show(ax[0, 1], rd_r, "ColoRadar frame_984 (golden 2D FFT)")
plt.tight_layout(); plt.savefig("golden_frames_rd.png", dpi=120)
print("[저장] golden_frames_rd.png")
