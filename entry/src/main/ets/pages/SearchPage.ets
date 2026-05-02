/**
 * 搜索页面
 * 顶部：平台色背景 + 搜索栏
 * 内容：顶部分类图标行 + 搜索结果列表 / 空状态
 */
import { Song, Platform } from '../model/Song';
import { SongItem } from '../view/SongItem';
import PlayerViewModel from '../viewmodel/PlayerViewModel';
import { netEaseService } from '../service/NetEaseService';

// 顶部分类项
interface CategoryItem {
  icon: string;
  name: string;
}

@ComponentV2
export struct SearchPage {
  @Param platform: Platform = Platform.NETEASE;
  @Param viewModel: PlayerViewModel = new PlayerViewModel();
  @Local keyword: string = '';
  @Local searchResults: Song[] = [];
  @Local isLoading: boolean = false;
  @Local showHistory: boolean = true;
  @Local searchHistory: string[] = [];
  @Local currentPlayingId: number = -1;
  @Local currentSong?: Song;
  @Event onSearch: (keyword: string, platform: Platform) => void = () => {};
  @Event onPlaySong: (song: Song) => void = () => {};

  // 顶部分类数据
  private readonly categories: CategoryItem[] = [
    { icon: '🎵', name: '飙升榜' },
    { icon: '🎤', name: '新歌榜' },
    { icon: '🎸', name: '热歌榜' },
    { icon: '🥁', name: '原创榜' },
    { icon: '🎹', name: '抖音榜' }
  ];

  private getPlatformName(): string {
    switch (this.platform) {
      case Platform.NETEASE:
        return '网易云音乐';
      case Platform.BILIBILI:
        return 'Bilibili';
      case Platform.QQ:
        return 'QQ音乐';
      default:
        return '本地音乐';
    }
  }

  private getPlatformColor(): string {
    switch (this.platform) {
      case Platform.NETEASE:
        return '#C20C0C';
      case Platform.BILIBILI:
        return '#FB7299';
      case Platform.QQ:
        return '#31C27C';
      default:
        return '#1E88E5';
    }
  }

  build() {
    Column() {
      // 顶部区域：平台名称 + 搜索栏
      Column() {
        Row({ space: 12 }) {
          Text(this.getPlatformName())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 20, bottom: 20 })

        // 搜索栏
        Row({ space: 12 }) {
          Search({
            value: this.keyword,
            placeholder: `搜索${this.getPlatformName()}...`
          })
            .searchButton('搜索')
            .backgroundColor(Color.White)
            .textFont({ size: 14 })
            .onChange((value: string) => {
              this.keyword = value;
            })
            .onSubmit(() => {
              this.performSearch();
            })
            .width('100%')
        }
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .width('100%')
      .backgroundColor(this.getPlatformColor())

      // 搜索历史
      if (this.showHistory && this.searchHistory.length > 0 && this.keyword === '') {
        Column({ space: 12 }) {
          Row() {
            Text('搜索历史')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Blank()
            Button('清空')
              .fontSize(12)
              .fontColor('#999999')
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.searchHistory = [];
              })
          }
          .width('100%')
          .padding(16)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.searchHistory, (item: string) => {
              Text(item)
                .fontSize(13)
                .fontColor('#666666')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#F5F5F5')
                .borderRadius(16)
                .onClick(() => {
                  this.keyword = item;
                  this.performSearch();
                })
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      // 加载中
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(this.getPlatformColor())
          Text('搜索中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      // 搜索结果列表
      else if (this.searchResults.length > 0) {
        List({ space: 0 }) {
          ForEach(this.searchResults, (song: Song, index: number) => {
            ListItem() {
              SongItem({
                song: song,
                isPlaying: this.currentPlayingId === song.id && this.viewModel.isPlaying,
                onPlay: (s: Song) => {
                  this.playSong(s);
                },
                onMore: (s: Song) => {
                  this.showMoreOptions(s);
                }
              })
            }
            .onClick(() => {
              this.playSong(song);
            })
          })
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      }
      // 搜索无结果
      else if (this.keyword !== '' && !this.isLoading) {
        Column({ space: 16 }) {
          Image($r('sys.media.ohos_ic_public_albums'))
            .width(80)
            .height(80)
            .fillColor('#E0E0E0')
          Text('未找到相关歌曲').fontSize(16).fontColor('#999999')
          Text('请尝试其他关键词').fontSize(14).fontColor('#CCCCCC')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      // 默认空状态（显示顶部分类 + 歌单占位）
      else if (!this.showHistory || this.searchHistory.length === 0) {
        Scroll() {
          Column({ space: 16 }) {
            // 顶部分类行（对齐文档 SearchHeaderView）
            Row({ space: 0 }) {
              ForEach(this.categories, (cat: CategoryItem) => {
                Column({ space: 6 }) {
                  Text(cat.icon).fontSize(24)
                  Text(cat.name).fontSize(11).fontColor('#666666')
                }
                .width('20%')
                .alignItems(HorizontalAlign.Center)
              })
            }
            .width('100%')
            .padding(16)

            // 双列歌单占位
            Row({ space: 12 }) {
              ForEach([1, 2], (col: number) => {
                Column({ space: 12 }) {
                  ForEach([1, 2, 3], (row: number) => {
                    Column({ space: 6 }) {
                      Image($r('app.media.default_cover'))
                        .width('100%')
                        .aspectRatio(1)
                        .borderRadius(12)
                        .objectFit(ImageFit.Cover)
                      Text('歌单名称')
                        .fontSize(13)
                        .maxLines(1)
                        .width('100%')
                      Text('发行公司')
                        .fontSize(11)
                        .fontColor('#999999')
                        .width('100%')
                    }
                  })
                }
                .layoutWeight(1)
              })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  private async performSearch(): Promise<void> {
    if (this.keyword.trim() === '') return;
    this.showHistory = false;
    this.isLoading = true;

    // 保存搜索历史（去重，最多 10 条）
    if (!this.searchHistory.includes(this.keyword)) {
      this.searchHistory = [this.keyword, ...this.searchHistory].slice(0, 10);
    }

    // 通知父组件
    this.onSearch(this.keyword, this.platform);

    // 根据平台调用对应 API
    if (this.platform === Platform.NETEASE) {
      try {
        this.searchResults = await netEaseService.search(this.keyword, 30);
      } catch (err) {
        console.error('搜索失败:', JSON.stringify(err));
        this.searchResults = [];
      }
    } else {
      // 其他平台暂未接入
      this.searchResults = [];
    }
    this.isLoading = false;
  }

  private playSong(song: Song): void {
    this.currentPlayingId = song.id;
    this.currentSong = song;
    this.onPlaySong(song);
  }

  private showMoreOptions(song: Song): void {
    console.info('More options for song:', song.title);
  }
}
