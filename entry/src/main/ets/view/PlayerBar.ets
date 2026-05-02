/**
 * 底部浮动迷你播放条
 * 顶部细进度条 + 封面/歌名/环形播放按钮
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

  build() {
    Column({ space: 0 }) {
      // 顶部细进度条：全宽、2px 高，直观展示播放进度
      Progress({
        value: this.viewModel.progressValue,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(2)
        .color('#C20C0C')
        .backgroundColor('#E8E8E8')

      // 主体：封面 + 信息 + 播放按钮
      Row({ space: 12 }) {
        // 封面
        Image(this.currentSong?.coverUrl || $r('app.media.default_cover'))
          .width(44)
          .height(44)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)

        // 歌曲信息 + 进度时间
        Column({ space: 2 }) {
          Text(this.currentSong?.title || this.viewModel.currentFileName || '未播放')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(120)

          // 进度时间行：当前时间 / 总时长
          Row({ space: 4 }) {
            Text(this.viewModel.formatTime(this.viewModel.currentTime))
              .fontSize(10)
              .fontColor('#999999')

            Text('/')
              .fontSize(10)
              .fontColor('#CCCCCC')

            Text(this.viewModel.formatTime(this.viewModel.duration))
              .fontSize(10)
              .fontColor('#999999')

            Blank()

            Text(this.currentSong?.artist || '点击选择音乐')
              .fontSize(11)
              .fontColor('#999999')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(70)
          }
          .width(140)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          this.onBarClick();
        })

        // 播放/暂停（环形进度环绕）
        Stack() {
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

          Button() {
            Image(this.viewModel.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
              .width(16)
              .height(16)
              .fillColor('#C20C0C')
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .width(28)
          .height(28)
          .onClick(() => {
            this.onPlayPause();
          })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .border({ width: 1, color: '#F0F0F0' })
    .onClick(() => {
      this.onBarClick();
    })
  }
}
