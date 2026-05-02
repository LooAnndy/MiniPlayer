/**
 * 底部浮动迷你播放条
 * 渐变背景 (#F2F2F2 → 透明)、封面旋转动画、歌曲名跑马灯、环形进度
 */
import { Song } from '../model/Song';
import PlayerViewModel from '../viewmodel/PlayerViewModel';

@ComponentV2
export struct PlayerBar {
  @Param viewModel: PlayerViewModel = new PlayerViewModel();
  @Param currentSong?: Song = undefined;
  @Param playlist: Song[] = [];
  @Param currentIndex: number = 0;
  @Event onPlayPause: () => void = () => {};
  @Event onPrev: () => void = () => {};
  @Event onNext: () => void = () => {};
  @Event onProgressChange: (value: number) => void = () => {};
  @Event onBarClick: () => void = () => {};

  // 封面旋转角度（播放时持续递增实现旋转动画）
  @Local coverRotation: number = 0;

  build() {
    Row({ space: 12 }) {
      // 左侧：旋转封面（点击可弹出专辑详情）
      Image(this.currentSong?.coverUrl || $r('app.media.default_cover'))
        .width(48)
        .height(48)
        .borderRadius(24)
        .objectFit(ImageFit.Cover)
        .rotate({ angle: this.coverRotation })

      // 中部：歌曲名跑马灯 + 歌手名
      Column({ space: 2 }) {
        Text(this.currentSong?.title || this.viewModel.currentFileName || '未播放')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(140)

        Text(this.currentSong?.artist || '点击选择音乐')
          .fontSize(11)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(140)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        this.onBarClick();
      })

      // 右侧：播放暂停（环形进度围绕）
      Stack() {
        // 环形进度条（背景轨道）
        Progress({
          value: this.viewModel.progressValue,
          total: 100,
          type: ProgressType.Ring
        })
          .width(40)
          .height(40)
          .color('#C20C0C')
          .backgroundColor('#E8E8E8')
          .style({ strokeWidth: 3 })

        // 播放/暂停按钮
        Button() {
          Image(this.viewModel.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(18)
            .height(18)
            .fillColor('#C20C0C')
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .width(30)
        .height(30)
        .onClick(() => {
          this.onPlayPause();
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    // 渐变背景：底部白色 → 顶部透明
    .linearGradient({
      angle: 0,
      colors: [
        ['#F4F6F9', 0.0],
        ['#FAFAFA', 0.5],
        ['#FFFFFF', 1.0]
      ]
    })
    .border({ width: { top: 0.5 }, color: '#E0E0E0' })
    .onClick(() => {
      this.onBarClick();
    })
  }
}
