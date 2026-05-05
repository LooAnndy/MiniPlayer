/**
 * 迷你播放条 —— 内置播放控制 + 点击跳转全屏播放页
 * 交互逻辑内聚：细进度条 + 封面/歌名/环形播放按钮
 */
import { Router, UIContext } from '@kit.ArkUI';
import { playerState } from '../common/PlayerStateCenter';

@ComponentV2
export struct PlayerBar {
  build() {
    Column({ space: 0 }) {
      // 顶部细进度条
      Progress({
        value: playerState.viewModel.progressValue,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(2)
        .color('#C20C0C')
        .backgroundColor('#E8E8E8')

      // 主体：封面 + 歌名/时间 + 播放按钮
      Row({ space: 12 }) {
        // 封面 + 歌名区域：点击跳转全屏播放页
        Row({ space: 10 }) {
          Image(playerState.currentSong?.coverUrl || $r('app.media.default_cover'))
            .width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover)

          Column({ space: 2 }) {
            Text(playerState.currentSong?.title || playerState.viewModel.currentFileName || '未播放')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(120)

            Row({ space: 4 }) {
              Text(playerState.viewModel.formatTime(playerState.viewModel.currentTime))
                .fontSize(10).fontColor('#999999')
              Text('/').fontSize(10).fontColor('#CCCCCC')
              Text(playerState.viewModel.formatTime(playerState.viewModel.duration))
                .fontSize(10).fontColor('#999999')
              Blank()
              Text(playerState.currentSong?.artist || '点击选择音乐')
                .fontSize(11).fontColor('#999999')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(70)
            }
            .width(140)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .onClick(() => {
          const uiContext: UIContext = this.getUIContext();
          const router: Router = uiContext.getRouter();
          router.pushUrl({ url: 'pages/PlayerPage' });
        })

        // 环形进度 + 播放按钮
        Stack() {
          Progress({
            value: playerState.viewModel.progressValue,
            total: 100,
            type: ProgressType.Ring
          })
            .width(40).height(40).color('#C20C0C')
            .backgroundColor('#E8E8E8').style({ strokeWidth: 3 })

          Button() {
            Image(playerState.viewModel.isPlaying
              ? $r('sys.media.ohos_ic_public_pause')
              : $r('sys.media.ohos_ic_public_play'))
              .width(16).height(16).fillColor('#C20C0C')
          }
          .type(ButtonType.Circle).backgroundColor(Color.Transparent)
          .width(28).height(28)
          .onClick(() => { playerState.togglePlayPause(); })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .border({ width: 1, color: '#F0F0F0' })
  }
}
