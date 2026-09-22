# Vivado 블록디자인 단계별 가이드 (FMCW R-D Map 시스템)

처음이라도 한 단계씩 따라오면 된다. 모르는 창이 뜨면 기본값을 두고 OK를 눌러도 대부분 괜찮다.

---

## 0. 사전 준비 (블록디자인 전에)

1. Vivado 새 프로젝트 생성 → RTL Project → Part는 `xc7z020clg484-1` 선택.
2. Sources 패널 → Add Sources → Add or create design sources →
   우리 `.v` 전부 + 교수 `lcd_ctrl.v` 추가.
   **제외**: `xfft_0.v`, `stub_clk_wiz_0.v`, `stub_lcd_ctrl.v`, `tb_*` (시뮬 전용)
3. IP Catalog에서 두 IP 생성:
   - **Fast Fourier Transform** → 이름 `xfft_0`, 128-point, Pipelined Streaming,
     Fixed Point 16-bit, Scaled, Natural Order, ARESETn (앞 RANGE_FFT_GUIDE 참고)
   - **Clocking Wizard** → 이름 `clk_wiz_0`, 입력 100MHz, 출력 1개 33MHz, reset/locked 포함
   `pl_top`이 이 둘을 내부에서 부르므로 반드시 먼저 만들어 둔다.

---

## 1. 블록디자인 만들기

- 좌측 Flow Navigator → IP Integrator → **Create Block Design** → 이름(예: `system`) → OK.
- 빈 캔버스가 열린다.

## 2. Zynq PS 올리기

1. 캔버스에서 **+** 버튼(Add IP) → "ZYNQ7 Processing System" 검색 → 더블클릭.
2. 위에 초록 띠 **Run Block Automation** → 클릭 → 기본값 OK.
   (DDR, 고정 I/O가 자동 설정된다)
3. 올라온 PS 블록을 **더블클릭**해서 설정:
   - **Clock Configuration** → PL Fabric Clocks → FCLK_CLK0 = **100 MHz** 체크
   - **PS-PL Configuration** → AXI Non Secure → **M AXI GP0** 체크
   - **Peripheral I/O Pins** → **SD 0** 켜져 있는지 확인 (SD카드 읽기용)
   - OK

## 3. AXI DMA 올리기

1. Add IP → "AXI DMA" → 더블클릭.
2. 더블클릭해서 설정:
   - **Enable Scatter Gather** 체크 해제 (Direct 모드 = 간단)
   - **Enable Read Channel (MM2S)** 만 체크, Write(S2MM) 해제
   - Width of Buffer Length Register 기본
   - Stream Data Width = **32**
   - OK
   (이게 DDR의 IQ 프레임을 PL로 흘려보낸다)

## 4. AXI GPIO 올리기 (스위치)

1. Add IP → "AXI GPIO" → 더블클릭.
2. 설정:
   - **All Inputs** 체크
   - GPIO Width = **2** (sw[1:0])
   - OK

## 5. pl_top 올리기

- 캔버스 빈 곳에서 **우클릭 → Add Module** → `pl_top` 선택 → OK.
- `pl_top`의 `s_axis_*` 포트들이 하나의 **S_AXIS** 인터페이스로 묶여 보이면 정상이다.
  (이름이 AXI-Stream 규약이라 Vivado가 자동 인식한다)

## 6. 자동 연결

- 위 초록 띠 **Run Connection Automation** → 전부 체크 → OK.
  - PS의 M_AXI_GP0가 AXI Interconnect를 거쳐 DMA·GPIO의 제어포트(S_AXI)에 연결된다.
  - 클럭/리셋도 상당수 자동으로 잡힌다.

## 7. 수동 연결 (3가지)

자동으로 안 된 것을 직접 잇는다. 포트에 마우스를 올리면 연필 모양이 되고, 끌어다 놓으면 선이 그어진다.

1. **데이터**: AXI DMA의 `M_AXIS_MM2S` → `pl_top`의 `s_axis`
2. **클럭**: PS의 `FCLK_CLK0` → `pl_top`의 `sys_clk`
   (DMA·GPIO·Interconnect의 clk는 자동 연결됐을 것. 안 됐으면 같은 FCLK_CLK0로)
3. **리셋**: "Processor System Reset" 블록이 자동으로 생겼을 것이다.
   그 블록의 `peripheral_aresetn` → `pl_top`의 `sys_rst_n`
   (active-Low라 우리 `sys_rst_n`과 맞는다)

## 8. 외부 포트 빼기 (Make External)

LCD와 스위치는 칩 밖 핀으로 나가야 한다.

1. `pl_top`의 LCD 출력들(`rgb_lcd`, `hsync`, `vsync`, `lcd_clk`, `lcd_de`, `lcd_ud`, `lcd_bl`)을
   하나씩 우클릭 → **Make External**. (또는 포트 선택 후 Ctrl+T)
2. AXI GPIO의 `GPIO` 포트 우클릭 → **Make External**.
   → `gpio_rtl` 같은 외부 포트가 생긴다. 이름을 더블클릭해 `sw`로 바꿔두면 XDC가 편하다.

## 9. 마무리

1. 캔버스 상단 체크 아이콘 또는 **F6** (Validate Design) → 에러 없는지 확인.
2. Sources 패널 → 블록디자인(`system.bd`) 우클릭 → **Create HDL Wrapper** →
   "Let Vivado manage" → OK.
3. **XDC 추가**: 같이 준 `system.xdc`(아래 설명)를 constraints로 추가.
4. Flow Navigator → **Generate Bitstream** (Synthesis·Implementation 자동 실행, 수~십수 분).
5. File → Export → **Export Hardware** → **Include bitstream** 체크 → `.xsa` 저장.
   이 `.xsa`를 들고 Vitis로 간다.

---

## XDC 정리 (중요)

교수 `lcd.xdc`를 그대로 쓰면 안 된다. 우리는 PS를 쓰므로:

- **삭제**: `sys_clk`(Y9), `sys_rst_n`(F22) 줄 → PS가 클럭·리셋을 대신한다.
- **유지**: LCD 핀 전부 (hsync, vsync, lcd_clk, lcd_de, lcd_ud, lcd_bl, rgb_lcd[23:0])
- **추가**: 스위치 2개. 단, 포트 이름을 8단계에서 GPIO를 External로 뺀 **실제 이름**에
  맞춰야 한다. Vivado가 만든 이름이 `sw_tri_i`라면:

```
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {sw_tri_i[0]}]
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {sw_tri_i[1]}]
```

(정확한 포트 이름은 Wrapper 생성 후 I/O Ports 창에서 확인할 수 있다)

---

## 자주 막히는 곳

- **s_axis가 인터페이스로 안 묶임**: `pl_top` 포트 이름이 `s_axis_tdata`/`tvalid`/`tready`/`tlast`
  인지 확인. 맞으면 자동 인식된다.
- **Connection Automation이 클럭을 못 잡음**: DMA/GPIO/Interconnect의 모든 `*_aclk`를
  FCLK_CLK0에, `*_aresetn`을 Processor System Reset의 출력에 수동 연결.
- **Validate 에러 "clock pin unconnected"**: `pl_top.sys_clk`, DMA aclk 등 빠진 클럭을 잇는다.
- **XDC 포트 이름 불일치**: Make External로 만든 실제 이름을 I/O Ports 창에서 확인 후 XDC 수정.
