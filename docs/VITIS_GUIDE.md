# Vitis 단계별 가이드 (PS 코드 빌드 & 보드 실행)

전제: 블록디자인 → 비트스트림 → Export Hardware로 **`.xsa`가 이미 있어야 한다**
(BLOCK_DESIGN_GUIDE.md 참고). 그 이유는, C 코드가 쓰는 DMA·GPIO 주소가
`xparameters.h`에 들어있는데 이 헤더는 `.xsa`로 platform을 만들 때 생성되기 때문이다.

---

## 1. Vitis 실행 & Workspace

- Vivado에서 Tools → Launch Vitis IDE, 또는 Vitis를 직접 실행.
- Workspace 폴더를 하나 정한다(빈 폴더 권장).

## 2. Platform Project 만들기 (.xsa 사용)

1. File → New → **Platform Project**.
2. 이름 입력 → Next.
3. "Create from XSA" → 아까 Export한 `.xsa` 선택.
4. Operating System = **standalone**, Processor = **ps7_cortexa9_0** → Finish.
5. 좌측에서 platform을 우클릭 → **Build** (BSP가 생성된다).

## 3. FatFs(SD 읽기) 라이브러리 켜기  ★중요

C 코드의 `f_mount`/`f_open`/`f_read`가 링크되려면 BSP에 FatFs를 켜야 한다.

1. platform의 `platform.spr` (또는 BSP Settings) 열기.
2. standalone → Board Support Package → **Modify BSP Settings**.
3. Supported Libraries 목록에서 **xilffs** 체크 → OK.
4. (SD가 안 잡히면) xilffs 설정에서 `use_lfn`(long file name)을 켜도 된다.
5. platform 다시 **Build**.

## 4. Application Project 만들기

1. File → New → **Application Project**.
2. 위에서 만든 platform 선택 → Next.
3. 이름 입력(예: `rdmap_app`) → Next → 도메인 standalone 확인 → Next.
4. Template은 **Empty Application (C)** → Finish.
5. 생성된 앱의 `src` 폴더에 우리 **`main.c`** 복사(기존 helloworld.c 있으면 삭제).
6. 앱 우클릭 → **Build**.
   - 만약 `XPAR_AXIDMA_0_DEVICE_ID` 같은 이름에서 에러가 나면, BSP의
     `xparameters.h`를 열어 실제 매크로 이름을 확인하고 main.c의 `#define`을 맞춘다.
   - `init_platform()`에서 에러나면 그 줄을 지워도 된다(필수 아님).

## 5. SD카드 준비

- `gen_sd_data.py`로 만든 `synth.bin`, `real_0000.bin`, ... 을 SD카드 **루트**에 복사.
- (부팅 방식에 따라 BOOT.bin도 같이 — 아래)

## 6. 보드에서 실행 — 두 가지 방법

### (A) JTAG으로 바로 실행 (개발 중 권장, 빠름)
1. 보드를 USB로 연결, 전원 ON, 부팅 모드를 JTAG로.
2. Vitis에서 앱 우클릭 → **Run As → Launch Hardware**.
   - 자동으로 비트스트림(PL) + FSBL + app(PS)을 보드에 올려 실행한다.
3. SD카드는 꽂혀 있어야 한다(데이터 읽기용).
4. LCD에 R-D Map이 떠야 한다. 스위치로 모드 전환 확인.

### (B) SD 부팅 (독립 실행)
1. Vitis → Xilinx → **Create Boot Image**.
   - FSBL(.elf, platform이 생성), 비트스트림(.bit), app(.elf)을 순서대로 추가.
2. 출력 **BOOT.bin**을 SD카드 루트에 복사(데이터 .bin들과 함께).
3. 보드 부팅 모드를 **SD**로 변경, 전원 ON → 자동 실행.

---

## 동작 확인 체크리스트

- LCD 백라이트가 켜지고 화면 중앙에 256×256 컬러 맵이 보이는가.
- 스위치 sw[0] OFF → 합성 타겟 3개(점 3개)가 또렷한가.
- 스위치 sw[0] ON → ColoRadar 프레임의 ego-motion 대각선 패턴이 흐르는가.
- 안 보이면: ① SD 마운트 실패(UART 로그 확인) ② DMA 전송 안 됨(주소/길이)
  ③ 클럭/리셋 미연결 ④ XDC 핀 불일치 순으로 점검.

## UART 로그 보기
- Vitis 아래쪽 **Vitis Serial Terminal** 또는 별도 터미널(115200 baud)로
  `xil_printf` 메시지("SD mount fail" 등)를 확인하면 디버깅이 쉽다.
