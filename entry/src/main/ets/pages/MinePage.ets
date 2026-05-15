/**
 * 我的页面 —— 三平台 Cookie 配置与测试
 * 加载时自动恢复Cookie并测试；«测试连接» 即保存+验证
 */
import { platformServiceRegistry } from '../service/PlatformService';
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

// 将平台枚举与 CookieState 绑定，替代原本 3 个独立的 @Local 变量
interface CookieStateEntry {
  platform: Platform;
  state: CookieState;
}

function platformSupportsTest(p: Platform): boolean {
  return p === Platform.NETEASE || p === Platform.QQ || p === Platform.BILIBILI;
}

function createDefaultCookieState(): CookieState {
  const s: CookieState = {
    input: '',
    status: '未配置',
    statusColor: '#999',
    testing: false,
    tested: false,
    testOk: false
  };
  return s;
}

@ComponentV2
export struct MinePage {
  @Local cookieStates: CookieStateEntry[] = [
    { platform: Platform.NETEASE, state: createDefaultCookieState() },
    { platform: Platform.QQ, state: createDefaultCookieState() },
    { platform: Platform.BILIBILI, state: createDefaultCookieState() }
  ];

  aboutToAppear(): void {
    for (let i: number = 0; i < this.cookieStates.length; i++) {
      this.restoreCookie(this.cookieStates[i].platform, true);
    }
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

  // 按平台查找 CookieState（纯迭代，无 if/else）
  private getState(p: Platform): CookieState {
    for (let i: number = 0; i < this.cookieStates.length; i++) {
      if (this.cookieStates[i].platform === p) {
        return this.cookieStates[i].state;
      }
    }
    return this.cookieStates[0].state;
  }

  // 更新单个平台的 CookieState：生成新数组触发 @Local 响应
  private updateState(p: Platform, updater: (oldState: CookieState) => CookieState): void {
    const newList: CookieStateEntry[] = [];
    for (let i: number = 0; i < this.cookieStates.length; i++) {
      const entry: CookieStateEntry = this.cookieStates[i];
      if (entry.platform === p) {
        const newEntry: CookieStateEntry = { platform: entry.platform, state: updater(entry.state) };
        newList.push(newEntry);
      } else {
        newList.push(entry);
      }
    }
    this.cookieStates = newList;
  }

  private restoreCookie(p: Platform, autoTest: boolean): void {
    loadCookie(p).then((cookie: string) => {
      if (cookie) {
        this.setCookieInput(p, cookie);
        this.syncCookieToService(p, cookie);
        if (autoTest) {
          this.runTest(p);
        } else {
          this.updateStatus(p, '已保存', '#4CAF50');
        }
      }
    });
  }

  private setCookieInput(p: Platform, value: string): void {
    this.updateState(p, (s: CookieState): CookieState => {
      const ns: CookieState = {
        input: value,
        status: s.status,
        statusColor: s.statusColor,
        testing: s.testing,
        tested: s.tested,
        testOk: s.testOk
      };
      return ns;
    });
  }

  private updateStatus(p: Platform, status: string, color: string): void {
    this.updateState(p, (s: CookieState): CookieState => {
      const ns: CookieState = {
        input: s.input,
        status: status,
        statusColor: color,
        testing: s.testing,
        tested: s.tested,
        testOk: s.testOk
      };
      return ns;
    });
  }

  private updateTestState(p: Platform, testing: boolean, status: string, color: string, tested: boolean, ok: boolean): void {
    this.updateState(p, (s: CookieState): CookieState => {
      const ns: CookieState = {
        input: s.input,
        status: status,
        statusColor: color,
        testing: testing,
        tested: tested,
        testOk: ok
      };
      return ns;
    });
  }

  private async handleSave(p: Platform): Promise<void> {
    const cookie: string = this.getState(p).input.trim();
    if (!cookie) { this.updateStatus(p, '未配置', '#999'); return; }
    await saveCookie(p, cookie);
    this.syncCookieToService(p, cookie);
    this.updateStatus(p, '已保存', '#4CAF50');
  }

  private async handleTest(p: Platform): Promise<void> {
    const cookie: string = this.getState(p).input.trim();
    if (!cookie) { this.updateStatus(p, '未配置', '#999'); return; }
    await saveCookie(p, cookie);
    this.syncCookieToService(p, cookie);
    await this.runTest(p);
  }

  private async runTest(p: Platform): Promise<void> {
    this.updateTestState(p, true, '检测中...', '#FF9800', false, false);
    const ok: boolean = await platformServiceRegistry.testCookie(p);
    this.updateTestState(p, false, ok ? '连接正常' : '连接失败', ok ? '#4CAF50' : '#F44336', true, ok);
  }

  private syncCookieToService(p: Platform, cookie: string): void {
    const svc = platformServiceRegistry.get(p);
    if (svc) {
      svc.setCookie(cookie);
    }
  }
}
