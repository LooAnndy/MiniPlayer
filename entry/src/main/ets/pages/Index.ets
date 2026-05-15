/**
 * 应用根页面 —— Navigation 导航容器
 * 管理全局路由栈，启动时展示 SplashPage，3 秒后自动跳转 MainPage
 */
import { MainPage } from './MainPage';
import { initCookieStorage } from '../utils/CookieStorage';
import { platformServiceRegistry } from '../service/PlatformService';

@Entry
@ComponentV2
struct Index {
  private navPathStack: NavPathStack = new NavPathStack();
  @Local showSplash: boolean = true;
  @Local countdown: number = 3;
  private timer?: number;

  aboutToAppear() {
    // 初始化 Cookie 持久化存储，恢复所有已注册平台的 Cookie
    initCookieStorage(getContext(this)).then(() => {
      platformServiceRegistry.restoreAllCookies();
    });

    // 3 秒倒计时，结束后跳转主页面
    this.timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(this.timer);
        this.showSplash = false;
      }
    }, 1000);
  }

  aboutToDisappear() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  build() {
    Navigation(this.navPathStack) {
      if (this.showSplash) {
        // 启动闪屏
        Stack({ alignContent: Alignment.Bottom }) {
          Column({ space: 20 }) {
            Image($r('app.media.default_cover'))
              .width(120)
              .height(120)
              .borderRadius(24)
              .objectFit(ImageFit.Cover)

            Text('MiniPlayer')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text('发现音乐的力量')
              .fontSize(14)
              .fontColor('rgba(255, 255, 255, 0.7)')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#C20C0C')

          // 右上角倒计时跳过按钮
          Button(`跳过 ${this.countdown}`)
            .fontSize(14)
            .fontColor('#C20C0C')
            .backgroundColor(Color.White)
            .borderRadius(16)
            .position({ x: '70%', y: 32 })
            .onClick(() => {
              clearInterval(this.timer);
              this.showSplash = false;
            })
        }
        .width('100%')
        .height('100%')
      } else {
        // 主页面壳（4 个 Tab + 全局 PlayerBar）
        MainPage({ navPathStack: this.navPathStack })
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
  }
}
