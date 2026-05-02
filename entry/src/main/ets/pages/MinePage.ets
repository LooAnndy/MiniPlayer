/**
 * 我的页面 —— 三平台 Cookie 配置（线性滚动）
 * 平台配置统一引用 model/Song 中的 PLATFORM_LIST
 */
import { netEaseService } from '../service/NetEaseService';
import { saveCookie, loadCookie } from '../utils/CookieStorage';
import { Platform, PLATFORM_LIST, PlatformInfo } from '../model/Song';

// 每平台独立的状态
interface CookieState {
  input: string;
  status: string;
  statusColor: string;
  testing: boolean;
}

@ComponentV2
export struct MinePage {
  // 三平台各自独立状态（避免 Record<string, string>）
  @Local stateNetease: CookieState = { input: '', status: '未配置', statusColor: '#999', testing: false };
  @Local stateBilibili: CookieState = { input: '', status: '未配置', statusColor: '#999', testing: false };
  @Local stateQQ: CookieState = { input: '', status: '未配置', statusColor: '#999', testing: false };

  aboutToAppear(): void {
    this.restoreCookie(Platform.NETEASE, this.stateNetease);
    this.restoreCookie(Platform.BILIBILI, this.stateBilibili);
    this.restoreCookie(Platform.QQ, this.stateQQ);
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('我的')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ top: 20, left: 16 })

        // 三平台配置区（引用 PLATFORM_LIST 唯一数据源）
        ForEach(PLATFORM_LIST, (info: PlatformInfo) => {
          this.buildCookieSection(info)
        })

        Text('Cookie 保存在本地磁盘，应用卸载时清除。')
          .fontSize(12)
          .fontColor('#CCCCCC')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 20 })
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  @Builder
  buildCookieSection(info: PlatformInfo) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text(info.icon).fontSize(22)
        Text(info.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(info.color)
        Blank()
        Row({ space: 5 }) {
          Circle()
            .width(7)
            .height(7)
            .fill(this.getState(info.platform).statusColor)
          Text(this.getState(info.platform).status)
            .fontSize(12)
            .fontColor(this.getState(info.platform).statusColor)
        }
      }
      .width('100%')

      TextArea({
        text: this.getState(info.platform).input,
        placeholder: info.cookieHint
      })
        .height(80)
        .fontSize(12)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(10)
        .onChange((value: string) => {
          const s = this.getState(info.platform);
          s.input = value;
        })

      Row({ space: 10 }) {
        Button('保存')
          .fontSize(13)
          .backgroundColor(info.color)
          .fontColor(Color.White)
          .borderRadius(6)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .onClick(() => { this.handleSave(info.platform); })

        // 网易云支持测试连接（仅在事件回调中访问非 UI 状态）
        if (info.platform === Platform.NETEASE) {
          Button(this.stateNetease.testing ? '检测中...' : '测试连接')
            .fontSize(13)
            .backgroundColor('#F5F5F5')
            .fontColor(info.color)
            .borderRadius(6)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .enabled(!this.stateNetease.testing)
            .onClick(() => { this.handleTest(); })
        }
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(Color.White)
    .margin({ left: 16, right: 16 })
  }

  // 根据 platform 返回对应状态对象
  private getState(p: Platform): CookieState {
    if (p === Platform.NETEASE) return this.stateNetease;
    if (p === Platform.BILIBILI) return this.stateBilibili;
    return this.stateQQ;
  }

  // 恢复持久化的 Cookie
  private restoreCookie(p: Platform, s: CookieState): void {
    loadCookie(p).then((c) => {
      if (c) {
        s.input = c;
        if (p === Platform.NETEASE) {
          netEaseService.setCookie(c);
          s.status = netEaseService.hasMusicU() ? '已配置' : '无效 Cookie';
          s.statusColor = netEaseService.hasMusicU() ? '#4CAF50' : '#FF9800';
        } else {
          s.status = '已保存';
          s.statusColor = '#4CAF50';
        }
      }
    });
  }

  private async handleSave(p: Platform): Promise<void> {
    const s = this.getState(p);
    const cookie = s.input.trim();
    if (!cookie) {
      s.status = '未配置';
      s.statusColor = '#999';
      return;
    }
    await saveCookie(p, cookie);
    if (p === Platform.NETEASE) {
      netEaseService.setCookie(cookie);
      s.status = netEaseService.hasMusicU() ? '已配置 MUSIC_U' : '已保存';
      s.statusColor = netEaseService.hasMusicU() ? '#4CAF50' : '#FF9800';
    } else {
      s.status = '已保存';
      s.statusColor = '#4CAF50';
    }
  }

  private async handleTest(): Promise<void> {
    const s = this.stateNetease;
    s.testing = true;
    s.status = '检测中...';
    s.statusColor = '#FF9800';

    if (s.input.trim()) {
      netEaseService.setCookie(s.input.trim());
    }
    const ok = await netEaseService.testCookie();
    s.testing = false;
    s.status = ok ? '连接正常' : '连接失败';
    s.statusColor = ok ? '#4CAF50' : '#F44336';
  }
}
