/**
 * 我的页面 —— Cookie 配置与账户管理
 * 填写网易云音乐 Cookie（MUSIC_U）以启用完整搜索功能
 *
 * 与 NetEaseService 单例交互：
 * - 保存 → netEaseService.setCookie()
 * - 检测 → netEaseService.testCookie()
 * - 状态 → netEaseService.hasMusicU()
 */
import { netEaseService } from '../service/NetEaseService';

@ComponentV2
export struct MinePage {
  @Local cookieInput: string = '';
  @Local cookieStatus: string = '未配置';
  @Local isTesting: boolean = false;
  @Local statusColor: string = '#999999';

  aboutToAppear(): void {
    // 读取当前已有 Cookie 显示在输入框
    this.cookieInput = netEaseService.getCookie();
    this.updateStatus();
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 标题
        Text('我的')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ top: 20, left: 20 })

        // Cookie 配置区域
        Column({ space: 12 }) {
          Row() {
            Text('Cookie 配置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Blank()
            // 状态指示
            Row({ space: 6 }) {
              Circle()
                .width(8)
                .height(8)
                .fill(this.statusColor)
              Text(this.cookieStatus)
                .fontSize(13)
                .fontColor(this.statusColor)
            }
          }
          .width('100%')

          // 说明文字
          Text('填写包含 MUSIC_U 的网易云 Cookie，格式: MUSIC_U=xxx; os=pc; ...')
            .fontSize(12)
            .fontColor('#999999')
            .width('100%')

          // Cookie 输入框（多行，显示 URL 编码的 cookie 字符串）
          TextArea({
            text: this.cookieInput,
            placeholder: '从浏览器 F12 → Application → Cookies 中复制...'
          })
            .height(100)
            .fontSize(13)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .onChange((value: string) => {
              this.cookieInput = value;
            })

          // 操作按钮行
          Row({ space: 12 }) {
            // 保存按钮
            Button('保存 Cookie')
              .fontSize(14)
              .backgroundColor('#C20C0C')
              .fontColor(Color.White)
              .borderRadius(8)
              .padding({ left: 20, right: 20 })
              .onClick(() => {
                this.saveCookie();
              })

            // 测试连接按钮
            Button(this.isTesting ? '检测中...' : '测试连接')
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .fontColor('#C20C0C')
              .borderRadius(8)
              .padding({ left: 20, right: 20 })
              .enabled(!this.isTesting)
              .onClick(() => {
                this.testCookie();
              })
          }
        }
        .width('100%')
        .padding(20)
        .borderRadius(12)
        .backgroundColor(Color.White)

        // 获取 Cookie 说明
        Column({ space: 8 }) {
          Text('如何获取 Cookie？')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          Column({ space: 6 }) {
            this.stepItem('1', '浏览器打开 music.163.com 并登录')
            this.stepItem('2', '按 F12 打开开发者工具')
            this.stepItem('3', '点击 Application → Cookies')
            this.stepItem('4', '复制所有 Cookie 值粘贴到上方')
          }
        }
        .width('100%')
        .padding(20)
        .borderRadius(12)
        .backgroundColor(Color.White)

        // 说明提示
        Text('Cookie 中的 MUSIC_U 是网易云的用户身份标识，\n拥有黑胶 VIP 账号的 Cookie 可解锁更高质量音频。')
          .fontSize(12)
          .fontColor('#CCCCCC')
          .width('100%')
          .padding({ left: 20, right: 20 })
      }
      .padding({ left: 16, right: 16, bottom: 20 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  // 步骤条目 Builder
  @Builder
  stepItem(num: string, text: string) {
    Row({ space: 10 }) {
      Text(num)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor('#C20C0C')
        .borderRadius(10)
        .width(20)
        .height(20)
        .textAlign(TextAlign.Center)

      Text(text)
        .fontSize(14)
        .fontColor('#333333')
    }
  }

  // 保存 Cookie 到共享的 NetEaseService
  private saveCookie(): void {
    if (this.cookieInput.trim() === '') {
      this.cookieStatus = '未配置';
      this.statusColor = '#999999';
      return;
    }
    netEaseService.setCookie(this.cookieInput.trim());
    this.updateStatus();
  }

  // 测试 Cookie 是否有效（发起一次轻量搜索验证）
  private async testCookie(): Promise<void> {
    this.isTesting = true;
    this.cookieStatus = '检测中...';
    this.statusColor = '#FF9800';

    // 先保存当前输入
    if (this.cookieInput.trim() !== '') {
      netEaseService.setCookie(this.cookieInput.trim());
    }

    const ok = await netEaseService.testCookie();
    this.isTesting = false;

    if (ok) {
      this.cookieStatus = '连接正常';
      this.statusColor = '#4CAF50';
    } else {
      this.cookieStatus = '连接失败';
      this.statusColor = '#F44336';
    }
  }

  // 更新 Cookie 状态显示
  private updateStatus(): void {
    if (netEaseService.hasMusicU()) {
      this.cookieStatus = '已配置 MUSIC_U';
      this.statusColor = '#4CAF50';
    } else {
      this.cookieStatus = '未检测到 MUSIC_U';
      this.statusColor = '#FF9800';
    }
  }
}
