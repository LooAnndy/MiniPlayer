/**
 * 我的页面 —— 三平台 Cookie 配置与测试
 * 加载时自动恢复Cookie并测试；«测试连接» 即保存+验证
 */
import { netEaseService } from '../service/NetEaseService';
import { qqMusicService } from '../service/QQMusicService';
import { bilibiliService } from '../service/BilibiliService';
import { saveCookie, loadCookie } from '../utils/CookieStorage';
import { Platform, PLATFORM_LIST, PlatformInfo } from '../model/Song';

interface CookieState {
  input: string;
  status: string;
  statusColor: string;
  testing: boolean;
  tested: boolean;
  testOk: boolean;
}

function platformSupportsTest(p: Platform): boolean {
  return p === Platform.NETEASE || p === Platform.QQ || p === Platform.BILIBILI;
}

@ComponentV2
export struct MinePage {
  @Local stateNetease: CookieState =
    { input: '', status: '未配置', statusColor: '#999', testing: false, tested: false, testOk: false };
  @Local stateBilibili: CookieState =
    { input: '', status: '未配置', statusColor: '#999', testing: false, tested: false, testOk: false };
  @Local stateQQ: CookieState =
    { input: '', status: '未配置', statusColor: '#999', testing: false, tested: false, testOk: false };

  aboutToAppear(): void {
    // 恢复持久化Cookie，支持测试的平台自动验证
    this.restoreCookie(Platform.NETEASE, this.stateNetease, true);
    this.restoreCookie(Platform.QQ, this.stateQQ, true);
    this.restoreCookie(Platform.BILIBILI, this.stateBilibili, true);
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('我的').fontSize(24).fontWeight(FontWeight.Bold)
          .width('100%').padding({ top: 20, left: 16 })
        ForEach(PLATFORM_LIST, (info: PlatformInfo) => {
          this.buildCookieSection(info)
        })
        Text('Cookie 保存在本地磁盘，应用卸载时清除。')
          .fontSize(12).fontColor('#CCCCCC')
          .width('100%').padding({ left: 16, right: 16, bottom: 20 })
      }
    }
    .scrollBar(BarState.Off).width('100%').height('100%').backgroundColor('#F4F6F9')
  }

  @Builder
  buildCookieSection(info: PlatformInfo) {
    Column({ space: 12 }) {
      // 头部
      Row({ space: 10 }) {
        Text(info.icon).fontSize(22)
        Text(info.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(info.color)
        Blank()
        Row({ space: 6 }) {
          if (this.getState(info.platform).testing) {
            LoadingProgress().width(14).height(14).color(info.color)
          } else {
            Circle().width(7).height(7).fill(this.getState(info.platform).statusColor)
          }
          Text(this.getState(info.platform).status)
            .fontSize(12).fontColor(this.getState(info.platform).statusColor)
        }
      }
      .width('100%')

      TextArea({
        text: this.getState(info.platform).input,
        placeholder: info.cookieHint
      })
        .height(80).fontSize(12)
        .backgroundColor('#F5F5F5').borderRadius(8).padding(10)
        .onChange((value: string) => { this.setCookieInput(info.platform, value); })

      // 按钮行：支持测试的平台用«测试连接»（含保存），B站仅«保存»
      Row({ space: 10 }) {
        if (platformSupportsTest(info.platform)) {
          Button(this.getState(info.platform).testing ? '⟳ 检测中' : '🔍 测试连接')
            .fontSize(13).backgroundColor(info.color).fontColor(Color.White)
            .borderRadius(6).padding({ left: 18, right: 18, top: 7, bottom: 7 })
            .enabled(!this.getState(info.platform).testing)
            .onClick(() => { this.handleTest(info.platform); })
        } else {
          Button('保存')
            .fontSize(13).backgroundColor(info.color).fontColor(Color.White)
            .borderRadius(6).padding({ left: 18, right: 18, top: 7, bottom: 7 })
            .onClick(() => { this.handleSave(info.platform); })
        }
      }

      // 测试结果卡片
      if (this.getState(info.platform).tested && !this.getState(info.platform).testing) {
        Row({ space: 8 }) {
          Text(this.getState(info.platform).testOk ? '✓' : '✗')
            .fontSize(20).fontColor(this.getState(info.platform).testOk ? '#4CAF50' : '#F44336')
          Column({ space: 2 }) {
            Text(this.getState(info.platform).testOk ? 'API 连接正常' : 'API 连接失败')
              .fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(this.getState(info.platform).testOk ? '#4CAF50' : '#F44336')
            Text(this.getState(info.platform).testOk
              ? 'Cookie 有效'
              : '请检查 Cookie 是否正确，或确认网络连接')
              .fontSize(11).fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding(12)
        .backgroundColor(this.getState(info.platform).testOk ? '#F1F8E9' : '#FFF3F0')
        .borderRadius(8)
        .border({ width: 1, color: this.getState(info.platform).testOk ? '#C8E6C9' : '#FFCDD2' })
      }
    }
    .width('100%').padding(16).borderRadius(12)
    .backgroundColor(Color.White).margin({ left: 16, right: 16 })
  }

  private getState(p: Platform): CookieState {
    if (p === Platform.NETEASE) return this.stateNetease;
    if (p === Platform.BILIBILI) return this.stateBilibili;
    return this.stateQQ;
  }

  // 恢复Cookie：填入输入框 + 自动测试（通过整体替换对象触发 @Local 更新）
  private restoreCookie(p: Platform, s: CookieState, autoTest: boolean): void {
    loadCookie(p).then((cookie) => {
      if (cookie) {
        this.setCookieInput(p, cookie);
        this.syncCookieToService(p, cookie);
        if (autoTest) {
          this.runTest(p, this.getState(p));
        } else {
          this.updateStatus(p, '已保存', '#4CAF50');
        }
      }
    });
  }

  // 更新输入框（手动逐字段赋值，ArkTS 禁止对象展开）
  private setCookieInput(p: Platform, value: string): void {
    if (p === Platform.NETEASE) { this.stateNetease = this.copyState(this.stateNetease, value, this.stateNetease.status, this.stateNetease.statusColor, this.stateNetease.testing, this.stateNetease.tested, this.stateNetease.testOk); }
    else if (p === Platform.BILIBILI) { this.stateBilibili = this.copyState(this.stateBilibili, value, this.stateBilibili.status, this.stateBilibili.statusColor, this.stateBilibili.testing, this.stateBilibili.tested, this.stateBilibili.testOk); }
    else { this.stateQQ = this.copyState(this.stateQQ, value, this.stateQQ.status, this.stateQQ.statusColor, this.stateQQ.testing, this.stateQQ.tested, this.stateQQ.testOk); }
  }

  // 更新状态（手动逐字段赋值）
  private updateStatus(p: Platform, status: string, color: string): void {
    if (p === Platform.NETEASE) { this.stateNetease = this.copyState(this.stateNetease, this.stateNetease.input, status, color, this.stateNetease.testing, this.stateNetease.tested, this.stateNetease.testOk); }
    else if (p === Platform.BILIBILI) { this.stateBilibili = this.copyState(this.stateBilibili, this.stateBilibili.input, status, color, this.stateBilibili.testing, this.stateBilibili.tested, this.stateBilibili.testOk); }
    else { this.stateQQ = this.copyState(this.stateQQ, this.stateQQ.input, status, color, this.stateQQ.testing, this.stateQQ.tested, this.stateQQ.testOk); }
  }

  private async handleSave(p: Platform): Promise<void> {
    const cookie = this.getState(p).input.trim();
    if (!cookie) { this.updateStatus(p, '未配置', '#999'); return; }
    await saveCookie(p, cookie);
    this.syncCookieToService(p, cookie);
    this.updateStatus(p, '已保存', '#4CAF50');
  }

  private async handleTest(p: Platform): Promise<void> {
    const cookie = this.getState(p).input.trim();
    if (!cookie) { this.updateStatus(p, '未配置', '#999'); return; }
    await saveCookie(p, cookie);
    this.syncCookieToService(p, cookie);
    await this.runTest(p, this.getState(p));
  }

  private async runTest(p: Platform, s: CookieState): Promise<void> {
    this.updateTestState(p, true, '检测中...', '#FF9800', false, false);
    let ok = false;
    if (p === Platform.NETEASE) { ok = await netEaseService.testCookie(); }
    else if (p === Platform.QQ) { ok = await qqMusicService.testCookie(); }
    else if (p === Platform.BILIBILI) { ok = await bilibiliService.testCookie(); }
    this.updateTestState(p, false, ok ? '连接正常' : '连接失败', ok ? '#4CAF50' : '#F44336', true, ok);
  }

  // 创建新的 CookieState
  private copyState(old: CookieState, input: string, status: string, color: string, testing: boolean, tested: boolean, ok: boolean): CookieState {
    const s: CookieState = { input: input, status: status, statusColor: color, testing: testing, tested: tested, testOk: ok };
    return s;
  }

  // 更新测试状态
  private updateTestState(p: Platform, testing: boolean, status: string, color: string, tested: boolean, ok: boolean): void {
    const s = this.getState(p);
    const ns = this.copyState(s, s.input, status, color, testing, tested, ok);
    if (p === Platform.NETEASE) { this.stateNetease = ns; }
    else if (p === Platform.BILIBILI) { this.stateBilibili = ns; }
    else { this.stateQQ = ns; }
  }

  private syncCookieToService(p: Platform, cookie: string): void {
    if (p === Platform.NETEASE) { netEaseService.setCookie(cookie); }
    else if (p === Platform.QQ) { qqMusicService.setCookie(cookie); }
    else if (p === Platform.BILIBILI) { bilibiliService.setCookie(cookie); }
  }
}
