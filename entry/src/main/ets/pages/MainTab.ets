/**
 * 主 Tab 容器页面
 * 四个 Tab：网易云 | B站 | QQ音乐 | 下载管理
 * 每个音乐平台 Tab 内嵌入独立的 SearchPage，底部 TabBar 置于屏幕底部
 */
import { Platform, Song } from '../model/Song';
import { SearchPage } from './SearchPage';
import { DownloadPage } from './DownloadPage';
import PlayerViewModel from '../viewmodel/PlayerViewModel';

@Entry
@ComponentV2
export struct MainTab {
  // 全局 ViewModel 实例：跨 Tab 共享播放状态
  @Local viewModel: PlayerViewModel = new PlayerViewModel();
  @Local currentTab: number = 0;

  // 当前播放歌曲信息
  @Local currentSong?: Song;
  @Local playlist: Song[] = [];
  @Local currentIndex: number = 0;

  aboutToAppear() {
    this.viewModel.initPlayer();
  }

  aboutToDisappear() {
    this.viewModel.release();
  }

  build() {
    // Tabs 容器：底部 TabBar + 页面内容
    Tabs({ index: this.currentTab }) {
      // Tab 1: 网易云音乐搜索
      TabContent() {
        SearchPage({
          platform: Platform.NETEASE,
          viewModel: this.viewModel,
          onSearch: this.handleSearch,
          onPlaySong: this.handlePlaySong
        })
      }
      .tabBar(this.tabBarBuilder(Platform.NETEASE))

      // Tab 2: Bilibili 搜索
      TabContent() {
        SearchPage({
          platform: Platform.BILIBILI,
          viewModel: this.viewModel,
          onSearch: this.handleSearch,
          onPlaySong: this.handlePlaySong
        })
      }
      .tabBar(this.tabBarBuilder(Platform.BILIBILI))

      // Tab 3: QQ 音乐搜索
      TabContent() {
        SearchPage({
          platform: Platform.QQ,
          viewModel: this.viewModel,
          onSearch: this.handleSearch,
          onPlaySong: this.handlePlaySong
        })
      }
      .tabBar(this.tabBarBuilder(Platform.QQ))

      // Tab 4: 下载管理
      TabContent() {
        DownloadPage()
      }
      .tabBar(this.tabBarBuilder('download'))
    }
    .barPosition(BarPosition.End) // TabBar 置于屏幕底部
    .onChange((index: number) => {
      this.currentTab = index;
    })
  }

  /**
   * Tab 栏 Builder
   * 根据平台显示对应图标和名称，当前选中 Tab 高亮为平台主题色
   */
  @Builder
  tabBarBuilder(platform: Platform | string) {
    Column({ space: 4 }) {
      if (platform === Platform.NETEASE) {
        Image($r('app.media.ic_netease'))
          .width(24)
          .height(24)
          .fillColor(this.currentTab === 0 ? '#C20C0C' : '#999999')
      } else if (platform === Platform.BILIBILI) {
        Image($r('app.media.ic_bilibili'))
          .width(24)
          .height(24)
          .fillColor(this.currentTab === 1 ? '#FB7299' : '#999999')
      } else if (platform === Platform.QQ) {
        Image($r('app.media.ic_qqmusic'))
          .width(24)
          .height(24)
          .fillColor(this.currentTab === 2 ? '#31C27C' : '#999999')
      } else {
        Image($r('sys.media.ohos_save_button_filled'))
          .width(24)
          .height(24)
          .fillColor(this.currentTab === 3 ? '#1E88E5' : '#999999')
      }

      Text(this.getTabName(platform))
        .fontSize(11)
        .fontColor(this.getTabColor(platform))
        .fontWeight(this.currentTab === this.getTabIndex(platform) ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 平台 → Tab 索引映射
  private getTabIndex(platform: Platform | string): number {
    switch (platform) {
      case Platform.NETEASE:
        return 0;
      case Platform.BILIBILI:
        return 1;
      case Platform.QQ:
        return 2;
      default:
        return 3;
    }
  }

  // 平台 → 显示名称映射
  private getTabName(platform: Platform | string): string {
    switch (platform) {
      case Platform.NETEASE:
        return '网易云';
      case Platform.BILIBILI:
        return 'B站';
      case Platform.QQ:
        return 'QQ音乐';
      default:
        return '下载';
    }
  }

  // 平台 → 主题色映射（选中态使用平台标志色）
  private getTabColor(platform: Platform | string): ResourceColor {
    const activeColors: Record<string, string> = {
      [Platform.NETEASE]: '#C20C0C',
      [Platform.BILIBILI]: '#FB7299',
      [Platform.QQ]: '#31C27C',
      'download': '#1E88E5'
    };
    return activeColors[platform as string] || '#999999';
  }

  // 搜索回调：由 SearchPage 触发，后续接入各平台 API
  private handleSearch = async (keyword: string, platform: Platform): Promise<void> => {
    console.info(`Search: ${keyword} on ${platform}`);
  }

  // 播放歌曲回调：更新当前歌曲信息
  private handlePlaySong = async (song: Song): Promise<void> => {
    this.currentSong = song;
    console.info(`Play song: ${song.title}`);
  }
}
