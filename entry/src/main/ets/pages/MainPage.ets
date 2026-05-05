/**
 * 主页面壳 —— 4 Tab + PlayerBar 紧贴 TabBar 上方
 * 通过 PlayerStateCenter 中间件统一管理播放状态
 */
import { Platform, Song, TabBarItem } from '../model/Song';
import { SearchPage } from './SearchPage';
import { PlayerBar } from '../view/PlayerBar';
import { HomePage } from './HomePage';
import { MinePage } from './MinePage';
import { playerState } from '../common/PlayerStateCenter';

const TAB_ITEMS: TabBarItem[] = [
  { id: '2025001', name: '首页', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025002', name: '搜索', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025003', name: '笔记', color: '#8E8E93', selectedColor: '#C20C0C' },
  { id: '2025004', name: '我的', color: '#8E8E93', selectedColor: '#C20C0C' }
];

@ComponentV2
export struct MainPage {
  @Local currentTab: number = 0;
  private tabController: TabsController = new TabsController();

  aboutToAppear(): void {
    playerState.init();
  }

  aboutToDisappear(): void {
    playerState.release();
  }

  build() {
    Column() {
      Tabs({ index: this.currentTab, controller: this.tabController }) {
        TabContent() {
          HomePage({
            viewModel: playerState.viewModel,
            onPlaySong: this.handlePlaySong
          })
        }

        TabContent() {
          SearchPage({
            platform: Platform.NETEASE,
            viewModel: playerState.viewModel,
            onSearch: this.handleSearch,
            onPlaySong: this.handlePlaySong
          })
        }

        TabContent() {
          this.placeholderPage('笔记社区', '施工中...')
        }

        TabContent() {
          MinePage()
        }
      }
      .barHeight(0)
      .scrollable(false)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentTab = index;
      })

      if (playerState.viewModel.isPlayed) {
        PlayerBar()
      }

      Row({ space: 0 }) {
        ForEach(TAB_ITEMS, (item: TabBarItem, index: number) => {
          Column() {
            Text(item.name)
              .fontSize(13)
              .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.currentTab === index ? item.selectedColor : item.color)
          }
          .width('25%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.currentTab = index;
            this.tabController.changeIndex(index);
          })
        })
      }
      .width('100%')
      .height(48)
      .backgroundColor('#EFEDF0')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  @Builder
  placeholderPage(title: string, subtitle: string) {
    Column({ space: 16 }) {
      Text(title).fontSize(18).fontWeight(FontWeight.Medium)
      Text(subtitle).fontSize(14).fontColor('#999999')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(Color.White)
  }

  private handleSearch = async (keyword: string, platform: Platform): Promise<void> => {
    console.info(`Search: ${keyword} on ${platform}`);
  }

  private handlePlaySong = async (song: Song): Promise<void> => {
    playerState.setCurrentSong(song);
    console.info(`Play song: ${song.title}`);
  }
}
