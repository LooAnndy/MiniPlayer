/**
 * 歌曲列表项 —— 搜索结果列表中的单行歌曲展示
 * 封面 | 标题/歌手/专辑 | 时长或播放状态指示 | 更多按钮
 */
import { Song, Platform } from '../model/Song';

@ComponentV2
export struct SongItem {
  @Param song: Song = { id: 0, name: '', title: '', artist: '', album: '', duration: 0, audioUrl: '', platform: Platform.LOCAL };
  @Param isPlaying: boolean = false;

  // 点击播放回调
  @Event onPlay: (song: Song) => void = () => {};
  // 点击更多按钮回调（下载、添加到列表等）
  @Event onMore: (song: Song) => void = () => {};

  // 毫秒 → mm:ss 格式
  formatDuration(milliseconds: number): string {
    if (milliseconds <= 0) return '00:00';
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  build() {
    Row({ space: 12 }) {
      // 左侧：播放状态指示 / 时长
      Row({ space: 8 }) {
        if (this.isPlaying) {
          Image($r('sys.media.ohos_ic_public_play'))
            .width(20)
            .height(20)
            .fillColor(Color.Blue)
        } else {
          Text(`${this.formatDuration(this.song.duration)}`)
            .fontSize(12)
            .fontColor(Color.Gray)
            .width(40)
        }
      }
      .width(48)
      .alignItems(VerticalAlign.Center)

      // 歌曲封面
      Image(this.song.coverUrl || $r('app.media.default_cover'))
        .width(50)
        .height(50)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

      // 歌曲信息：标题 + 歌手/专辑
      Column({ space: 4 }) {
        Text(this.song.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`${this.song.artist} - ${this.song.album}`)
          .fontSize(12)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 更多操作按钮
      Button() {
        Image($r('sys.media.ohos_ic_public_more'))
          .width(20)
          .height(20)
          .fillColor('#666666')
      }
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onMore(this.song);
      })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .onClick(() => {
      this.onPlay(this.song);
    })
  }
}
