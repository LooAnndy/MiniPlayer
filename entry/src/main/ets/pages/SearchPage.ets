/**
 * 搜索页面 —— 支持三平台搜索源切换
 * 搜索栏下方：网易云 / QQ音乐 / B站 切换条
 * 内容：搜索结果列表 / 空状态
 */
import { Song, Platform } from '../model/Song';
import { SongItem } from '../view/SongItem';
import PlayerViewModel from '../viewmodel/PlayerViewModel';
import { netEaseService } from '../service/NetEaseService';
import { qqMusicService } from '../service/QQMusicService';
import { bilibiliService } from '../service/BilibiliService';

// 搜索源配置
interface SearchSource {
  platform: Platform;
  name: string;
  color: string;
}

const SEARCH_SOURCES: SearchSource[] = [
  { platform: Platform.NETEASE, name: '网易云', color: '#C20C0C' },
  { platform: Platform.QQ, name: 'QQ音乐', color: '#31C27C' },
  { platform: Platform.BILIBILI, name: 'B站', color: '#FB7299' }
];

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
  // 当前激活的搜索源（可切换）
  @Local activeSource: Platform = Platform.NETEASE;
  @Event onSearch: (keyword: string, platform: Platform) => void = () => {};
  @Event onPlaySong: (song: Song) => void = () => {};

  aboutToAppear(): void {
    this.activeSource = this.platform;
  }

  build() {
    Column() {
      // 顶部：搜索栏
      Column() {
        Row({ space: 12 }) {
          Text('搜索音乐')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 20, bottom: 8 })

        // 搜索输入
        Row({ space: 12 }) {
          Search({
            value: this.keyword,
            placeholder: '搜索歌曲、歌手...'
          })
            .searchButton('搜索')
            .backgroundColor(Color.White)
            .textFont({ size: 14 })
            .onChange((value: string) => { this.keyword = value; })
            .onSubmit(() => { this.performSearch(); })
            .width('100%')
        }
        .padding({ left: 16, right: 16, bottom: 8 })

        // 搜索源切换条
        Row({ space: 0 }) {
          ForEach(SEARCH_SOURCES, (src: SearchSource) => {
            Text(src.name)
              .fontSize(13)
              .fontWeight(this.activeSource === src.platform ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.activeSource === src.platform ? Color.White : 'rgba(255,255,255,0.6)')
              .padding({ left: 20, right: 20, top: 8, bottom: 10 })
              .border({
                width: { bottom: this.activeSource === src.platform ? 2 : 0 },
                color: Color.White
              })
              .onClick(() => {
                this.activeSource = src.platform;
                if (this.keyword.trim()) this.performSearch();
              })
          })
        }
        .width('100%')
      }
      .width('100%')
      .backgroundColor('#C20C0C')

      // 搜索历史
      if (this.showHistory && this.searchHistory.length > 0 && this.keyword === '') {
        Column({ space: 12 }) {
          Row() {
            Text('搜索历史').fontSize(14).fontWeight(FontWeight.Medium)
            Blank()
            Button('清空').fontSize(12).fontColor('#999999').backgroundColor(Color.Transparent)
              .onClick(() => { this.searchHistory = []; })
          }
          .width('100%').padding(16)

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.searchHistory, (item: string) => {
              Text(item).fontSize(13).fontColor('#666666')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#F5F5F5').borderRadius(16)
                .onClick(() => { this.keyword = item; this.performSearch(); })
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .width('100%').alignItems(HorizontalAlign.Start)
      }

      // 加载中
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#C20C0C')
          Text('搜索中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
      // 搜索结果
      else if (this.searchResults.length > 0) {
        List({ space: 0 }) {
          ForEach(this.searchResults, (song: Song, index: number) => {
            ListItem() {
              SongItem({
                song: song,
                isPlaying: this.currentPlayingId === song.id && this.viewModel.isPlaying,
                onPlay: (s: Song) => { this.playSong(s); },
                onMore: (s: Song) => { this.showMoreOptions(s); }
              })
            }
            .onClick(() => { this.playSong(song); })
          })
        }
        .layoutWeight(1).divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      }
      // 无结果
      else if (this.keyword !== '' && !this.isLoading) {
        Column({ space: 16 }) {
          Image($r('sys.media.ohos_ic_public_albums')).width(80).height(80).fillColor('#E0E0E0')
          Text('未找到相关歌曲').fontSize(16).fontColor('#999999')
          Text('请尝试其他关键词或切换搜索源').fontSize(14).fontColor('#CCCCCC')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
      // 默认空状态
      else {
        Column({ space: 16 }) {
          Image($r('sys.media.ohos_ic_public_search_filled')).width(80).height(80).fillColor('#E0E0E0')
          Text('搜索音乐').fontSize(16).fontColor('#999999')
          Text('输入关键词，可切换搜索源').fontSize(14).fontColor('#CCCCCC')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor('#F4F6F9')
  }

  private async performSearch(): Promise<void> {
    if (this.keyword.trim() === '') return;
    this.showHistory = false;
    this.isLoading = true;
    if (!this.searchHistory.includes(this.keyword)) {
      this.searchHistory = [this.keyword, ...this.searchHistory].slice(0, 10);
    }
    this.onSearch(this.keyword, this.activeSource);

    try {
      if (this.activeSource === Platform.NETEASE) {
        this.searchResults = await netEaseService.search(this.keyword, 30);
      } else if (this.activeSource === Platform.QQ) {
        this.searchResults = await qqMusicService.search(this.keyword, 20);
      } else if (this.activeSource === Platform.BILIBILI) {
        this.searchResults = await bilibiliService.search(this.keyword, 20);
      } else {
        this.searchResults = [];
      }
    } catch (err) {
      console.error('搜索失败:', JSON.stringify(err));
      this.searchResults = [];
    }
    this.isLoading = false;
  }

  private async playSong(song: Song): Promise<void> {
    this.currentPlayingId = song.id;
    this.currentSong = song;
    this.onPlaySong(song);

    this.viewModel.message = `正在获取播放地址: ${song.title}`;
    let url = '';
    if (song.platform === Platform.NETEASE) {
      url = await netEaseService.getSongUrl(song.id);
    } else if (song.platform === Platform.QQ && song.sourceId) {
      url = await qqMusicService.getSongUrl(song.sourceId);
    } else if (song.platform === Platform.BILIBILI && song.sourceId) {
      url = await bilibiliService.getAudioUrl(song.sourceId);
    }
    if (url) {
      song.audioUrl = url;
      // B站 CDN 需 Referer 鉴权，通过 createMediaSourceWithUrl 传递 header
      if (song.platform === Platform.BILIBILI) {
        const biliHeaders: Record<string, string> = {
          'Referer': 'https://www.bilibili.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36'
        };
        await this.viewModel.playStreamUrlWithHeaders(url, biliHeaders);
      } else {
        await this.viewModel.playStreamUrl(url);
      }
    } else {
      this.viewModel.message = `无播放权限: ${song.title}`;
    }
  }

  private showMoreOptions(song: Song): void {
    console.info('More options:', song.title);
  }
}
