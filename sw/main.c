/*====================================================================
 * main.c : FMCW R-D Map 시스템 PS 코드 (Vitis 2023.2, standalone)
 *--------------------------------------------------------------------
 * - SD카드에서 프레임(.bin, 64KB)을 읽어 AXI DMA(MM2S)로 PL에 전송.
 * - 스위치/버튼(AXI GPIO)으로 모드 선택 (토글 방식):
 * 한 번 누르면 실데이터 모드 -> real_0000.bin.. 순차 재생
 * 다시 누르면 검증 모드    -> synth.bin 반복
 * - PL이 2D FFT -> R-D Map -> LCD 출력을 자동 수행.
 *===================================================================*/
#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xil_cache.h"
#include "sleep.h"
#include "ff.h"          /* FatFs (xilffs) */

#define N            128
#define FRAME_SMPL   (N*N)            /* 16384 */
#define FRAME_BYTES  (FRAME_SMPL*4)   /* 65536 = 64KB, 32bit/샘플 */

/*--- DMA/GPIO 베이스 주소 (Vitis 2023.2 SDT 방식) ---*/
#define DMA_BASEADDR   XPAR_AXI_DMA_0_BASEADDR
#define GPIO_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_CH        1             /* 스위치 채널 1 */

static XAxiDma AxiDma;
static XGpio   Gpio;
static FATFS   FatFs;

/* DDR 프레임 버퍼 (DMA 소스). 캐시 라인 정렬 */
static u32 frame_buf[FRAME_SMPL] __attribute__((aligned(64)));

static int init_dma(void)
{
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(DMA_BASEADDR);
    if (!cfg) return XST_FAILURE;
    if (XAxiDma_CfgInitialize(&AxiDma, cfg) != XST_SUCCESS) return XST_FAILURE;
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    return XST_SUCCESS;
}

static int init_gpio(void)
{
    if (XGpio_Initialize(&Gpio, GPIO_BASEADDR) != XST_SUCCESS) return XST_FAILURE;
    XGpio_SetDataDirection(&Gpio, GPIO_CH, 0xFFFFFFFF);  /* 입력 */
    return XST_SUCCESS;
}

/* SD에서 한 프레임 읽어 frame_buf에 적재. 성공 0, 실패 -1 */
static int read_frame(const char *fname)
{
    FIL  fil;
    UINT br;
    if (f_open(&fil, fname, FA_READ) != FR_OK) return -1;
    FRESULT fr = f_read(&fil, (void *)frame_buf, FRAME_BYTES, &br);
    f_close(&fil);
    return (fr == FR_OK && br == FRAME_BYTES) ? 0 : -1;
}

/* frame_buf를 DMA로 PL에 전송하고 완료까지 대기 */
static void send_frame(void)
{
    Xil_DCacheFlushRange((UINTPTR)frame_buf, FRAME_BYTES);
    XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)frame_buf, FRAME_BYTES,
                           XAXIDMA_DMA_TO_DEVICE);
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) { /* 폴링 */ }
}

int main(void)
{
    char fname[32];
    int  real_idx = 0;
    
    /* 토글 및 엣지 검출을 위한 상태 변수 */
    u32 prev_btn = 0;       /* 이전 루프의 버튼 상태 */
    int is_real_mode = 0;   /* 현재 재생 모드 (0: 검증 모드, 1: 실데이터 모드) */

    Xil_DCacheEnable();

    if (init_dma()  != XST_SUCCESS) { xil_printf("DMA init fail\r\n");  return -1; }
    if (init_gpio() != XST_SUCCESS) { xil_printf("GPIO init fail\r\n"); return -1; }
    if (f_mount(&FatFs, "0:/", 0) != FR_OK) { xil_printf("SD mount fail\r\n"); return -1; }

    xil_printf("FMCW R-D Map start\r\n");

    while (1) {
        /* 현재 버튼 상태 읽기 (0번 비트만 마스킹) */
        u32 curr_btn = XGpio_DiscreteRead(&Gpio, GPIO_CH) & 0x1;

        /* Rising Edge 검출: 안 눌렸다가(0) 눌린(1) 순간을 포착 */
        if (curr_btn == 1 && prev_btn == 0) {
            is_real_mode = !is_real_mode; /* 모드 반전 (토글) */
            real_idx = 0;                 /* 모드가 변경되면 인덱스 초기화 */
            
            if (is_real_mode) {
                xil_printf("Mode changed: Real Data Playback\r\n");
            } else {
                xil_printf("Mode changed: Synth Data Verification\r\n");
            }
        }
        
        /* 현재 상태를 이전 상태로 저장하여 다음 루프에서 비교 */
        prev_btn = curr_btn;

        /* 선택된 모드에 따라 데이터 로드 및 DMA 전송 */
        if (is_real_mode) {
            /* 실데이터 모드: ColoRadar 프레임 순차 재생 */
            snprintf(fname, sizeof(fname), "real_%04d.bin", real_idx);
            if (read_frame(fname) == 0) {
                send_frame();
                real_idx++;
            } else {
                real_idx = 0;          /* 파일이 없거나 끝에 도달하면 처음부터 다시 재생 */
            }
        } else {
            /* 검증 모드: 합성 프레임 반복 */
            if (read_frame("synth.bin") == 0) {
                send_frame();
            }
        }

        /* 약 30fps 제어 및 하드웨어 버튼 디바운싱(채터링 방지)을 위한 딜레이 */
        usleep(30000);
    }
    
    return 0;
}