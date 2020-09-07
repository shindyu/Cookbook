import AudioKit
import AVFoundation
import SwiftUI

struct PhaserData {
    var isPlaying: Bool = false
    var notchMinimumFrequency: AUValue = 100
    var notchMaximumFrequency: AUValue = 800
    var notchWidth: AUValue = 1_000
    var notchFrequency: AUValue = 1.5
    var vibratoMode: AUValue = 1
    var depth: AUValue = 1
    var feedback: AUValue = 0
    var inverted: AUValue = 0
    var lfoBPM: AUValue = 30
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class PhaserConductor: ObservableObject {
    let engine = AKEngine()
    let player = AKPlayer()
    let phaser: AKPhaser
    let dryWetMixer: AKDryWetMixer
    let playerPlot: AKNodeOutputPlot
    let phaserPlot: AKNodeOutputPlot
    let mixPlot: AKNodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        phaser = AKPhaser(player)
        dryWetMixer = AKDryWetMixer(player, phaser)
        playerPlot = AKNodeOutputPlot(player)
        phaserPlot = AKNodeOutputPlot(phaser)
        mixPlot = AKNodeOutputPlot(dryWetMixer)
        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        phaserPlot.plotType = .rolling
        phaserPlot.color = .blue
        phaserPlot.shouldFill = true
        phaserPlot.shouldMirror = true
        phaserPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = PhaserData() {
        didSet {
            if data.isPlaying {
                player.play()
                phaser.$notchMinimumFrequency.ramp(to: data.notchMinimumFrequency, duration: data.rampDuration)
                phaser.$notchMaximumFrequency.ramp(to: data.notchMaximumFrequency, duration: data.rampDuration)
                phaser.$notchWidth.ramp(to: data.notchWidth, duration: data.rampDuration)
                phaser.$notchFrequency.ramp(to: data.notchFrequency, duration: data.rampDuration)
                phaser.$vibratoMode.ramp(to: data.vibratoMode, duration: data.rampDuration)
                phaser.$depth.ramp(to: data.depth, duration: data.rampDuration)
                phaser.$feedback.ramp(to: data.feedback, duration: data.rampDuration)
                phaser.$inverted.ramp(to: data.inverted, duration: data.rampDuration)
                phaser.$lfoBPM.ramp(to: data.lfoBPM, duration: data.rampDuration)
                dryWetMixer.balance = data.balance

            } else {
                player.pause()
            }

        }
    }

    func start() {
        playerPlot.start()
        phaserPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            AKLog(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct PhaserView: View {
    @ObservedObject var conductor = PhaserConductor()

    var body: some View {
        VStack {
            Text(self.conductor.data.isPlaying ? "STOP" : "START").onTapGesture {
                self.conductor.data.isPlaying.toggle()
            }
            VStack {
            ParameterSlider(text: "Notch Minimum Frequency",
                            parameter: self.$conductor.data.notchMinimumFrequency,
                            range: 20...5_000).padding(5)
            ParameterSlider(text: "Notch Maximum Frequency",
                            parameter: self.$conductor.data.notchMaximumFrequency,
                            range: 20...10_000).padding(5)
            ParameterSlider(text: "Between 10 and 5000",
                            parameter: self.$conductor.data.notchWidth,
                            range: 10...5_000).padding(5)
            ParameterSlider(text: "Between 1.1 and 4",
                            parameter: self.$conductor.data.notchFrequency,
                            range: 1.1...4.0).padding(5)
            ParameterSlider(text: "Direct or Vibrato (default)",
                            parameter: self.$conductor.data.vibratoMode,
                            range: 0...1).padding(5)
            ParameterSlider(text: "Between 0 and 1",
                            parameter: self.$conductor.data.depth,
                            range: 0...1).padding(5)
            ParameterSlider(text: "Between 0 and 1",
                            parameter: self.$conductor.data.feedback,
                            range: 0...1).padding(5)
            ParameterSlider(text: "1 or 0",
                            parameter: self.$conductor.data.inverted,
                            range: 0...1).padding(5)
            ParameterSlider(text: "Between 24 and 360",
                            parameter: self.$conductor.data.lfoBPM,
                            range: 24...360).padding(5)
            }
            ParameterSlider(text: "Ramp Duration",
                            parameter: self.$conductor.data.rampDuration,
                            range: 0...4,
                            format: "%0.2f").padding(5)
            ParameterSlider(text: "Balance",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            format: "%0.2f").padding(5)
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.playerPlot).clipped()
                Text("Input")
            }
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.phaserPlot).clipped()
                Text("AKPhasered Signal")
            }
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.mixPlot).clipped()
                Text("Mixed Output")
            }
        }
        .padding()
        .navigationBarTitle(Text("Phaser"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}