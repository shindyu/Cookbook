import AudioKit
import AVFoundation
import SwiftUI

struct HeartBeatData {
    var isRecording = false
    var isPlaying = false
    var inputVolume: AUValue = 10
    var mixerVolume: AUValue = 0
    var centerFrequency: AUValue = 50
    var bandwidth: AUValue = 30
}

class HeartBeatConductor: ObservableObject {

    let engine = AudioEngine()
    let mic: AudioEngine.InputNode
    let recorder: NodeRecorder
    let mixer = Mixer()
    let filter: BandPassFilter
    let fader: Fader
    var tappableNode1: Mixer

    let rollingPlot: NodeOutputPlot

    @Published var data = HeartBeatData() {
        didSet {
            mic.volume = data.inputVolume
            filter.centerFrequency = data.centerFrequency
            filter.bandwidth = data.bandwidth
            mixer.volume = data.mixerVolume

            if data.isRecording {
                NodeRecorder.removeTempFiles()
                do {
                    try recorder.record()
                    rollingPlot.plotType = .rolling
                    rollingPlot.shouldFill = true
                    rollingPlot.shouldMirror = true
                    rollingPlot.start()
                } catch let err {
                    print(err)
                }
            } else {
                recorder.stop()
                saveToFile()
            }
        }
    }

    private func saveToFile() {
        print(#function)

        if let file = recorder.audioFile {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docsDirect = paths[0]
            let audioUrl = docsDirect.appendingPathComponent("test.caf")
            file.extract(to: audioUrl, from: 0, to: file.duration)
            UserDefaults.standard.recordFiles.append(audioUrl)
        }
    }

    init() {
        guard let input = engine.input else {
            fatalError()
        }
        mic = input
        tappableNode1 = Mixer(mic)
        filter = BandPassFilter(tappableNode1)
        fader = Fader(filter)
        mixer.addInput(fader)
        engine.output = mixer

        do {
            recorder = try NodeRecorder(node: fader)
        } catch let err {
            fatalError("\(err)")
        }

        rollingPlot = NodeOutputPlot(tappableNode1)
        rollingPlot.plotType = .rolling
        rollingPlot.shouldFill = true
        rollingPlot.shouldMirror = true
        rollingPlot.start()
    }

    func start() {
        do {
            try engine.start()

        } catch let err {
            print(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct HeartBeatView: View {
    @ObservedObject var conductor = HeartBeatConductor()
    @State var show: Bool = false

    var body: some View {
        VStack {
            if !show {
                Button("start") {
                    conductor.start()
                    show.toggle()
                }.padding()
            }

            if show {
                Button(conductor.data.isRecording ? "STOP RECORDING" : "RECORD") {
                    self.conductor.data.isRecording.toggle()
                }
                .padding()
                .onAppear {
                    // mixerVolumeをconductor.startより後で変更することで最初のハウリングを抑える
                    conductor.data.mixerVolume = 10
                }

                PlotView(view: conductor.rollingPlot).clipped()

                ParameterSlider(text: "mixer volume",
                                parameter: self.$conductor.data.mixerVolume,
                                range: 0...10,
                                units: "dB")

                NavigationLink(destination: HeartBeatSavedFilesView()) {
                    Text("SavedFiles")
                }
            }
        }
        .padding()
        .navigationBarTitle(Text("Recorder"))
        .onDisappear {
            self.conductor.stop()
        }
    }
}


class SavedFileConductor: ObservableObject {

    let engine = AudioEngine()
    let player = AudioPlayer()
    let mixer = Mixer()

    init() {
        player.isLooping = true
        player.volume = 10
        mixer.addInput(player)
        engine.output = mixer
    }

    func load(fileUrl: URL) {
        player.stop()

        if let file = try? AVAudioFile(forReading: fileUrl) {
            player.scheduleFile(file, at: nil)
            player.play()
        }
    }

    func start() {
        do {
            try engine.start()
        } catch let err {
            print(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct HeartBeatSavedFilesView: View {
    var urls: [URL] = UserDefaults.standard.recordFiles
    @ObservedObject var conductor = SavedFileConductor()

    var body: some View {
        List {
            ForEach(urls, id: \.absoluteString) { url in
                Text("\(url.absoluteString)")
                    .onTapGesture {
                        self.conductor.load(fileUrl: url)
                    }
            }
        }
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }


}

extension UserDefaults {
    var recordFiles: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "recordFiles"),
                  let decoded = try? JSONDecoder().decode([URL].self, from: data) else {
                return []
            }
            return NSOrderedSet(array: decoded).array as! [URL]
        }

        set {

            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(encoded, forKey: "recordFiles")
        }
    }
}
