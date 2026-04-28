import PlayerViewModel from '../viewmodel/PlayerViewModel';

@Entry
@Component
struct Index {
  // 引入ViewModel实例
  private  viewModel: PlayerViewModel = new PlayerViewModel();

  aboutToAppear() {
    // 初始化播放器
    this.viewModel.initPlayer();
  }

  aboutToDisappear() {
    // 释放资源
    this.viewModel.release();
  }

  build() {
    Column({ space: 20 }) {
      // 消息显示
      Text(this.viewModel.message)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      // 文件名显示
      Text(`当前文件: ${this.viewModel.currentFileName}`)
        .fontSize(14)
        .fontColor(Color.Gray)

      // 时间显示行
      Row({ space: 10 }) {
        Text(this.viewModel.formatTime(this.viewModel.currentTime))
          .fontSize(14)
          .fontColor(Color.Blue)

        Text('/')
          .fontSize(14)

        Text(this.viewModel.formatTime(this.viewModel.duration))
          .fontSize(14)
          .fontColor(Color.Gray)
      }

      // 进度条组件
      Stack() {
        // 进度条背景
        Progress({
          value: this.viewModel.progressValue,
          total: 100,
          type: ProgressType.Linear
        })
          .width('90%')
          .height(6)
          .color(Color.Blue)
          .backgroundColor('#E0E0E0')

        // 拖拽手柄
        Column() {
          Circle()
            .width(24)
            .height(24)
            .fill(Color.White)
            .shadow({ radius: 4, color: '#888888' })
        }
        .position({ x: `${this.viewModel.progressValue - 12}%`, y: -9 })
      }
      .width('90%')
      .height(30)
      .gesture(
        PanGesture({ distance: 5 })
          .onActionStart(() => {
            this.viewModel.onDragStart();
          })
          .onActionUpdate((event: GestureEvent) => {
            const progressWidth = 270;
            const offsetX = event.offsetX;
            const newValue = Math.max(0, Math.min(100, (offsetX / progressWidth) * 100));
            this.viewModel.onDragMove(newValue);
          })
          .onActionEnd(() => {
            this.viewModel.onDragEnd(this.viewModel.progressValue);
          })
      )

      // 选择文件按钮
      Button('选择并播放音乐')
        .width(200)
        .height(50)
        .backgroundColor(Color.Blue)
        .fontColor(Color.White)
        .onClick(() => {
          this.viewModel.selectAndPlay();
        })

      // 播放/暂停按钮
      Button(this.viewModel.isPlaying ? '暂停' : '开始')
        .width(150)
        .height(60)
        .backgroundColor(this.viewModel.isPlaying ? Color.Orange : Color.Green)
        .fontColor(Color.White)
        .fontSize(20)
        .onClick(() => {
          this.viewModel.togglePlayPause();
        })
        .enabled(this.viewModel.hasCurrentPlaySource())

    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(20)
  }
}
