import SwiftUI
import Combine

@main struct WeatherAtlasApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @StateObject private var model = WeatherModel()
    @State private var playing = false
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("YOUR WINDOW INTO THE WEATHER").font(.caption2).tracking(2).foregroundStyle(.teal)
                    HStack {
                        TextField("Find a city worldwide", text: $model.query).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit { Task { await model.search() } }
                        Button { Task { await model.search() } } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search")
                        Button { model.locate() } label: { Image(systemName: "location") }.accessibilityLabel("Use my location")
                    }
                    ForEach(model.results) { p in
                        Button(p.title) { model.results = []; Task { await model.load(p) } }.font(.subheadline)
                    }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text(model.place.title).font(.title2.bold())
                            Text("Next hourly forecast").font(.caption).foregroundStyle(.secondary)
                            if let date = model.loadedAt { Text("Retrieved \(date.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(temperature).font(.system(size: 48, weight: .light, design: .rounded))
                    }
                    Picker("Weather layer", selection: $model.layer) { ForEach(WeatherLayer.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    HStack {
                        Picker("Range", selection: $model.range) { ForEach(ForecastRange.allCases) { Text($0.title).tag($0) } }
                        Picker("Model", selection: $model.source) { ForEach(ForecastSource.allCases) { Text($0.title).tag($0) } }
                    }.disabled(model.layer == .radar)
                    Text(model.source.detail + " Displayed samples ~15 km apart.").font(.caption).foregroundStyle(.secondary)
                    WeatherMap(model: model).frame(height: 380).clipShape(RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }.accessibilityLabel(playing ? "Pause timeline" : "Play timeline")
                        if let date = model.validDate { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).bold() } else { Text("No data") }
                        Spacer()
                        Text(model.layer == .radar ? "OBSERVED" : "MODEL FORECAST").font(.caption2.bold()).foregroundStyle(.teal)
                    }
                    Slider(value: $model.step, in: 0...max(1,model.maxStep), step: 1).disabled(model.maxStep == 0)
                    HStack { Text(model.layer == .radar ? "Earlier observations" : "Next hourly step"); Spacer(); Text(model.layer == .radar ? "Latest observation" : "+" + model.range.title) }.font(.caption).foregroundStyle(.secondary)
                    if model.layer == .temperature { Text("Temperature · °C · blue = cold, red = warm").font(.caption) }
                    else if model.layer == .rain { Text("Hourly rain · mm · mint < 0.5, teal < 2, blue < 5, purple ≥ 5").font(.caption) }
                    if model.loading { ProgressView("Loading forecast…") }
                    if !model.message.isEmpty { Text(model.message).font(.callout).foregroundStyle(.red) }
                    if model.layer == .radar {
                        Text(model.radarMessage.isEmpty ? radarStatus : model.radarMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    if model.range.rawValue > 24 && model.center != nil {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(model.dailySummaries) { day in
                                    VStack(spacing: 8) {
                                        Text("Day \(day.id+1)").font(.caption.bold())
                                        Text(day.start, style: .date).font(.caption2)
                                        Text(model.formatted(day.minimum)+"–"+model.formatted(day.maximum)+"°").font(.title3.bold())
                                        Text(model.formatted(day.rain, digits: 1)+" mm / 24h").font(.caption).foregroundStyle(.teal)
                                    }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        Text("Cards summarize rolling 24-hour windows from the next hourly step. The map always shows the selected hour. Longer-lead hourly data may be interpolated.").font(.caption).foregroundStyle(.secondary)
                    } else if let hourly = model.center {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(model.indices, id: \.self) { i in
                                    VStack(spacing: 8) {
                                        Text(Date(timeIntervalSince1970: hourly.time[i]), style: .time).font(.caption2)
                                        Text(model.formatted(hourly.temperature_2m[i])+"°").font(.title3.bold())
                                        Text(model.formatted(hourly.precipitation[i], digits: 1)+" mm").font(.caption).foregroundStyle(.teal)
                                    }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    Text("Radar shows the past two hours where coverage exists; it is not a future forecast. Blank radar areas may mean no rain or no coverage. Forecast maps sample a 7 × 7 grid with ~15 km spacing. Model resolution varies by region. Zooming adds no weather detail. Rain totals cover the hour ending at the displayed time. All times use your device timezone.").font(.caption).foregroundStyle(.secondary)
                    HStack { Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!); Text("·"); Link("RainViewer", destination: URL(string: "https://www.rainviewer.com/")!); Text("·"); Link("Web app", destination: URL(string: "https://puneetvrma.github.io/weather/")!) }.font(.caption)
                    Text("Personal, non-commercial use. Location is sent to weather providers only when requested. No account or analytics.").font(.caption2).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Weather Atlas")
            .toolbar { Button { Task { await model.load(); await model.loadRadar() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh weather") }
            .task { async let radar: Void = model.loadRadar(); await model.load(); await radar }
            .onChange(of: model.layer) { _, newValue in playing = false; model.step = newValue == .radar ? model.maxStep : 0 }
            .onChange(of: model.range) { _, _ in playing = false; model.changeRange() }
            .onChange(of: model.source) { _, _ in playing = false; Task { await model.load() } }
            .onReceive(timer) { _ in if playing { model.step = model.step >= model.maxStep ? 0 : model.step + 1 } }
        }.tint(.teal)
    }
    private var temperature: String {
        guard let h = model.center, let i = model.indices.first else { return "—°" }
        return model.formatted(h.temperature_2m[i])+"°"
    }
    private var radarStatus: String {
        guard let frame = model.radarFrame else { return "Observed radar unavailable. Forecast layers remain available." }
        let age = Int(Date().timeIntervalSince1970 - frame.time) / 60
        return "Radar frame age: \(age) min. \(age > 150 ? "This frame is stale. " : "")Source maximum zoom: 7."
    }
}
