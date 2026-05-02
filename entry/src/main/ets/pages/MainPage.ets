/**
 * 主页面壳 —— 4 个 Tab + 全局浮动迷你播放条
 * Tab 内容区（首页/搜索/笔记/我的） + 底部 PlayerBar（条件显示） + 底部 TabBar
 */
import { Platform, Song, TabBarItem, SegmentItem } from '../model/Song';
import { SearchPage } from './SearchPage';
import { PlayerBar } from '../view/PlayerBar';
import PlayerViewModel from '../viewmodel/PlayerViewModel';
import router from '@ohos.router';
import { HomePage } from './HomePage';
import { MinePage } from './MinePage';

// Tab 配置
const TAB_ITEMS: TabBarItem[] = [
  { id: '2025001', name: '首页', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025002', name: '搜索', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025003', name: '笔记', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025004', name: '我的', color: '#8E8E93', selectedColor: '#C20C0C' }
];

@ComponentV2
export struct MainPage {
  @Param navPathStack: NavPathStack = new NavPathStack();
  @Local viewModel: PlayerViewModel = new PlayerViewModel();
  @Local currentTab: number = 0;
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
    Column() {
      // Tab 内容区（占据剩余空间）
      Tabs({ index: this.currentTab }) {
        // Tab 1: 首页
        TabContent() {
          HomePage({
            viewModel: this.viewModel,
            onPlaySong: this.handlePlaySong
          })
        }
        .tabBar(this.tabBarBuilder(0, TAB_ITEMS[0].name))

        // Tab 2: 搜索
        TabContent() {
          SearchPage({
            platform: Platform.NETEASE,
            viewModel: this.viewModel,
            onSearch: this.handleSearch,
            onPlaySong: this.handlePlaySong
          })
        }
        .tabBar(this.tabBarBuilder(1, TAB_ITEMS[1].name))

        // Tab 3: 笔记（占位页面）
        TabContent() {
          this.placeholderPage('笔记社区', '施工中...')
        }
        .tabBar(this.tabBarBuilder(2, TAB_ITEMS[2].name))

        // Tab 4: 我的（Cookie 配置页面）
        TabContent() {
          MinePage()
        }
        .tabBar(this.tabBarBuilder(3, TAB_ITEMS[3].name))
      }
      .barPosition(BarPosition.End)
      .scrollable(false)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentTab = index;
      })

      // 底部浮动迷你播放条（条件显示：播放状态为 true 时）
      if (this.viewModel.isPlayed) {
        PlayerBar({
          viewModel: this.viewModel,
          currentSong: this.currentSong,
          playlist: this.playlist,
          currentIndex: this.currentIndex,
          onPlayPause: () => {
            this.viewModel.togglePlayPause();
          },
          onPrev: () => {
            this.handlePrev();
          },
          onNext: () => {
            this.handleNext();
          },
          onBarClick: () => {
            router.pushUrl({ url: 'pages/PlayerPage' });
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  // Tab 栏 Builder（文字 Tab，无图标，对齐文档设计）
  @Builder
  tabBarBuilder(index: number, name: string) {
    Column() {
      Text(name)
        .fontSize(14)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? TAB_ITEMS[index].selectedColor : TAB_ITEMS[index].color)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  // 占位页面 Builder
  @Builder
  placeholderPage(title: string, subtitle: string) {
    Column({ space: 16 }) {
      Image($r('sys.symbol.music'))
        .width(80)
        .height(80)
        .fillColor('#E0E0E0')

      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)

      Text(subtitle)
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
  }

  private handleSearch = async (keyword: string, platform: Platform): Promise<void> => {
    console.info(`Search: ${keyword} on ${platform}`);
  }

  private handlePlaySong = async (song: Song): Promise<void> => {
    this.currentSong = song;
    this.playlist = [song];
    this.currentIndex = 0;
    this.viewModel.isPlayed = true;
    console.info(`Play song: ${song.title}`);
  }

  private handlePrev(): void {
    if (this.playlist.length === 0) return;
    this.currentIndex = (this.currentIndex - 1 + this.playlist.length) % this.playlist.length;
    this.currentSong = this.playlist[this.currentIndex];
  }

  private handleNext(): void {
    if (this.playlist.length === 0) return;
    this.currentIndex = (this.currentIndex + 1) % this.playlist.length;
    this.currentSong = this.playlist[this.currentIndex];
  }
}
