import SwiftUI

private enum RPTheme {
    static let background = Color(red: 0.082, green: 0.083, blue: 0.092)
    static let panel = Color(red: 0.13, green: 0.135, blue: 0.15)
    static let orange = Color(red: 1, green: 0.40, blue: 0.10)
    static let muted = Color(red: 0.66, green: 0.67, blue: 0.70)
}

private enum LauncherSection: String, CaseIterable {
    case home = "Главная"
    case servers = "Серверы"
    case downloads = "Загрузка"
    case news = "Новости"
    case observe = "Мир"
    case profile = "Профиль"
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .servers: return "server.rack"
        case .downloads: return "arrow.down.to.line"
        case .news: return "newspaper"
        case .observe: return "person.3.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

private struct RPServer: Identifiable {
    let name: String
    let emoji: String
    var id: String { name }
    var host: String { "\(name.lowercased()).gta5rp.com:22005" }
}

struct MainDashboard: View {
    @AppStorage("rpSelectedServer") private var selectedServer = "Eclipse"
    @AppStorage("gameServer") private var gameServer = "eclipse.gta5rp.com:22005"
    @AppStorage("manifestAddress") private var manifestAddress = ""
    @State private var tab: LauncherSection = .home
    @State private var showGameAlert = false
    @StateObject private var assets = GameAssets()
    @StateObject private var live = LiveServerMonitor()
    @StateObject private var observer = PlayerObserver()
    @AppStorage("rpCoordinatesFeed") private var coordinatesFeed = ""

    private let servers: [RPServer] = [
        .init(name: "Eclipse", emoji: "🌘"),
        .init(name: "Downtown", emoji: "🌆"),
        .init(name: "Rockford", emoji: "💎"),
        .init(name: "Redwood", emoji: "🌲"),
        .init(name: "Murrieta", emoji: "🌹"),
        .init(name: "Chiliad", emoji: "⛰️"),
        .init(name: "Mirror", emoji: "🪞"),
        .init(name: "Blaine", emoji: "🐍")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .home: homeView
                    case .servers: serversView
                    case .downloads: downloadsView
                    case .news: newsView
                    case .observe: observeView
                    case .profile: profileView
                    }
                }
                .padding(.horizontal, 17)
                .padding(.top, 12)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            bottomBar
        }
        .background(RPTheme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            while !Task.isCancelled {
                await live.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        .alert("Подключение пока недоступно", isPresented: $showGameAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Это тестовая версия лаунчера. Игровой движок и совместимый с GTA5RP сетевой клиент пока не встроены. Выбранный сервер: \(selectedServer).")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("GTA5RPLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 55)
                .accessibilityLabel("GTA5 RP")
            Spacer()
            Button { tab = .downloads } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 39, height: 39)
            }
            Button { tab = .profile } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 39, height: 39)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 17)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 15) {
            featuredServer
            HStack(spacing: 11) {
                tile(title: "ИГРАТЬ", symbol: "arrow.up.right", color: RPTheme.orange) {
                    showGameAlert = true
                }
                tile(title: "СЕЙЧАС ИГРАЮТ", subtitle: live.projectOnline.map { $0.formatted() } ?? "Нет данных", symbol: "person.2", color: RPTheme.panel, action: nil)
            }
            HStack(spacing: 11) {
                cityCard
                tile(title: "ПРОСМОТР\nИГРОКОВ", symbol: "person.3.fill", color: RPTheme.orange) {
                    tab = .observe
                }
            }
            HStack(spacing: 16) {
                socialButton("VK", symbol: "network", url: "https://gta5rp.com/")
                socialButton("Discord", symbol: "bubble.left.and.bubble.right.fill", url: "https://discord.com/servers/577311012236165122")
                socialButton("YouTube", symbol: "play.rectangle.fill", url: "https://gta5rp.com/")
                socialButton("Telegram", symbol: "paperplane.fill", url: "https://t.me/gta5rp")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            Text("ЧТО ТАКОЕ\nROLEPLAY")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .tracking(-0.9)
                .lineSpacing(-3)
                .padding(.top, 7)
            HStack(alignment: .top, spacing: 13) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(RPTheme.panel)
                    .overlay {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 54, weight: .thin))
                            .foregroundStyle(RPTheme.orange)
                    }
                    .frame(width: 108, height: 114)
                Text("Roleplay — игровой режим, где ты создаёшь своего персонажа, выбираешь ему профессию и строишь историю вместе с другими игроками.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineSpacing(4)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(RPTheme.orange).frame(width: 3)
                    }
            }
            Text("Неофициальный тестовый лаунчер. Не связан с администрацией GTA5RP.")
                .font(.system(size: 11))
                .foregroundStyle(RPTheme.muted)
                .padding(.top, 6)
        }
    }

    private var featuredServer: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(colors: [.black, RPTheme.panel, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Cityscape().fill(Color.white.opacity(0.085))
                .padding(.top, 76)
            Image(systemName: "car.side.fill")
                .font(.system(size: 128, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.21))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 18, y: 9)
                .clipped()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("GTA5").fontWeight(.black)
                    Text("RP").fontWeight(.light)
                    Text("\\").fontWeight(.ultraLight)
                    Text(selectedServer).fontWeight(.light).lineLimit(1).minimumScaleFactor(0.7)
                }
                .font(.system(size: 32))
                .tracking(-1.5)
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RPTheme.orange).frame(width: 3, height: 35)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сервер: \(selectedServer)").font(.headline)
                        Text("GTA5RP ROLEPLAY").font(.caption2).tracking(3)
                    }
                    Spacer()
                }
            }
            .padding(18)
            Button { showGameAlert = true } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(RPTheme.background)
                    .frame(width: 72, height: 72)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.4), radius: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 225)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08)))
    }

    @ViewBuilder private func tile(title: String, subtitle: String? = nil, symbol: String, color: Color, action: (() -> Void)?) -> some View {
        let body = VStack(alignment: .leading, spacing: 8) {
            if title == "СЕЙЧАС ИГРАЮТ" {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                    Text("Сейчас играют")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                Text(subtitle ?? "Нет данных")
                    .font(.system(size: 22, weight: .bold))
            } else {
                Text(title)
                    .font(.system(size: 23, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .thin))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 139)
        .background(color, in: RoundedRectangle(cornerRadius: 14))
        if let action {
            Button(action: action) { body }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
        } else {
            body.frame(maxWidth: .infinity)
        }
    }

    private var cityCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [.black, RPTheme.panel], startPoint: .top, endPoint: .bottom))
            Cityscape().fill(.white.opacity(0.16)).padding(.top, 38)
            VStack {
                Spacer()
                Text("LOS SANTOS")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 139)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func socialButton(_ name: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(RPTheme.background)
                .frame(width: 50, height: 50)
                .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 13))
        }
        .accessibilityLabel(name)
    }

    private var serversView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("НАШИ СЕРВЕРЫ", detail: "Выбери сервер для будущего подключения")
            ForEach(servers) { server in
                Button {
                    selectedServer = server.name
                    gameServer = server.host
                } label: {
                    HStack(spacing: 14) {
                        Text(server.emoji).font(.system(size: 27))
                            .frame(width: 45, height: 45)
                            .background(RPTheme.background, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(server.name).font(.system(size: 20, weight: .bold))
                            Text(server.host).font(.system(size: 11)).foregroundStyle(RPTheme.muted)
                            if let current = live.snapshot(for: server.name) {
                                Text("Онлайн: \(current.players.formatted()) / \(current.maxPlayers.formatted())")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(RPTheme.orange)
                            } else {
                                Text("Онлайн: нет данных").font(.caption2).foregroundStyle(RPTheme.muted)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selectedServer == server.name ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedServer == server.name ? RPTheme.orange : RPTheme.muted)
                            .font(.system(size: 22))
                    }
                    .padding(13)
                    .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            Button("ОБНОВИТЬ СТАТИСТИКУ") { Task { await live.refresh() } }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(RPTheme.orange)
                .disabled(live.fetching)
            if let updated = live.refreshed {
                Text("Источник: RAGE MP masterlist · \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2).foregroundStyle(RPTheme.muted)
            }
            if let failure = live.error {
                Text(failure).font(.caption).foregroundStyle(.orange)
            }
            Text("Адреса указаны для справки. Клиент GTA5RP/RAGE MP пока не интегрирован.")
                .font(.caption).foregroundStyle(RPTheme.muted)
        }
    }

    private var observeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("НАБЛЮДЕНИЕ", detail: "Онлайн без игровых ресурсов GTA V")
            VStack(alignment: .leading, spacing: 10) {
                Text("СЕРВЕР: \(selectedServer.uppercased())")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(RPTheme.orange)
                if let current = live.snapshot(for: selectedServer) {
                    Text("\(current.players.formatted()) / \(current.maxPlayers.formatted())")
                        .font(.system(size: 42, weight: .black))
                    Text("Игроков онлайн по публичной статистике RAGE MP")
                        .font(.caption).foregroundStyle(RPTheme.muted)
                    Text("Адрес: \(current.address)")
                        .font(.caption2).foregroundStyle(RPTheme.muted).textSelection(.enabled)
                } else {
                    Text("Нет данных об онлайне").font(.system(size: 23, weight: .bold))
                    Text(live.error ?? "Обнови публичную статистику")
                        .font(.caption).foregroundStyle(RPTheme.muted)
                }
                Button {
                    Task { await live.refresh() }
                } label: {
                    actionLabel("ОБНОВИТЬ ОНЛАЙН", symbol: "arrow.clockwise")
                }.disabled(live.fetching)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 15))

            Text("ИГРОКИ В 3D").font(.system(size: 22, weight: .black))
            PlayerWorldView(players: observer.players)
            Text("Публичный список RAGE MP не содержит положения или имён игроков. Реальные персонажи появятся только при доступном и разрешённом сервером API координат. Никаких искусственных NPC.")
                .font(.caption)
                .foregroundStyle(RPTheme.muted)

            VStack(alignment: .leading, spacing: 11) {
                Text("ИСТОЧНИК КООРДИНАТ").font(.system(size: 13, weight: .bold))
                TextField("https://example.com/players.json", text: $coordinatesFeed)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(RPTheme.background, in: RoundedRectangle(cornerRadius: 10))
                Button {
                    Task { await observer.fetch(coordinatesFeed) }
                } label: {
                    actionLabel("ПОЛУЧИТЬ ПОЗИЦИИ", symbol: "location")
                }.disabled(observer.busy || coordinatesFeed.isEmpty)
                Text(observer.status).font(.caption).foregroundStyle(RPTheme.muted)
                Text("Формат: {\"players\":[{\"id\":\"1\",\"name\":\"Player\",\"x\":0,\"y\":0,\"z\":0}]}")
                    .font(.caption2).foregroundStyle(RPTheme.muted).textSelection(.enabled)
            }
            .padding(16)
            .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 15))
        }
    }

    private var downloadsView: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("ЗАГРУЗКА", detail: "Проверка и скачивание игровых ресурсов")
            VStack(alignment: .leading, spacing: 12) {
                Text("АДРЕС МАНИФЕСТА").font(.system(size: 12, weight: .bold)).foregroundStyle(RPTheme.muted)
                TextField("https://example.com/rp/manifest.json", text: $manifestAddress)
                    .font(.system(size: 14))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(13)
                    .background(RPTheme.background, in: RoundedRectangle(cornerRadius: 10))
                Button { Task { await assets.load(manifestAddress) } } label: {
                    actionLabel("ПОЛУЧИТЬ СПИСОК", symbol: "list.bullet")
                }
                .disabled(assets.busy || manifestAddress.isEmpty)
                Button { Task { await assets.download() } } label: {
                    actionLabel("СКАЧАТЬ / ПРОВЕРИТЬ", symbol: "arrow.down.to.line")
                }
                .disabled(assets.busy)
                if assets.busy { ProgressView().tint(RPTheme.orange) }
                HStack {
                    Image(systemName: assets.busy ? "arrow.triangle.2.circlepath" : "internaldrive")
                    Text(assets.status).font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                Text(assets.progress).font(.caption).foregroundStyle(RPTheme.muted)
                    .textSelection(.enabled)
                if assets.count > 0 {
                    Text("Обработано: \(assets.count) файлов")
                        .font(.caption).foregroundStyle(RPTheme.orange)
                }
            }
            .padding(16)
            .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 15))
            infoCard("ФАЙЛЫ НА IPHONE", body: "Файлы → На iPhone → GTA5RP Mobile → RPResources. Лаунчер не изменяет папки сторонних приложений.")
            infoCard("ВАЖНО", body: "Для скачивания нужен manifest.json на твоём HTTPS-сервере. Загрузка файлов сама по себе не добавляет поддержку сетевого протокола GTA5RP.")
        }
    }

    private var newsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("НОВОСТИ", detail: "Источники сообщества GTA5RP")
            linkCard(title: "ОФИЦИАЛЬНЫЙ САЙТ", detail: "Новости и обновления проекта", symbol: "globe", url: "https://gta5rp.com/")
            linkCard(title: "TELEGRAM", detail: "Публикации GTA5RP", symbol: "paperplane.fill", url: "https://t.me/gta5rp")
            linkCard(title: "ФОРУМ", detail: "Правила и обсуждения", symbol: "text.bubble.fill", url: "https://forum.gta5rp.com/")
            infoCard("ЛЕНТА НОВОСТЕЙ", body: "Встроенный источник новостей пока не подключён. Ссылки открывают официальные ресурсы.")
        }
    }

    private var profileView: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("ПРОФИЛЬ", detail: "Параметры тестового лаунчера")
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 54)).foregroundStyle(RPTheme.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Гостевой режим").font(.title3.bold())
                    Text("Вход в GTA5RP пока недоступен").font(.caption).foregroundStyle(RPTheme.muted)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 15))
            Text("АДРЕС СЕРВЕРА").font(.system(size: 12, weight: .bold)).foregroundStyle(RPTheme.muted)
            TextField("Домен:порт", text: $gameServer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            infoCard("СБОРКА 0.3", body: "Публичный онлайн GTA5RP, подготовка облегчённого 3D-просмотра по разрешённому API координат. Игра не встроена. Это неофициальное приложение.")
            linkCard(title: "GTA5RP.COM", detail: "Личный кабинет на сайте проекта", symbol: "person.crop.circle", url: "https://gta5rp.com/")
        }
    }

    private func sectionHeading(_ name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.system(size: 29, weight: .black, design: .rounded))
            Text(detail).font(.subheadline).foregroundStyle(RPTheme.muted)
        }
        .padding(.vertical, 8)
    }

    private func infoCard(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(RPTheme.orange)
            Text(body).font(.system(size: 14)).foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private func linkCard(title: String, detail: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.title2).foregroundStyle(RPTheme.orange)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 17, weight: .bold))
                    Text(detail).font(.caption).foregroundStyle(RPTheme.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(RPTheme.muted)
            }
            .padding(16)
            .background(RPTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.white)
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .black))
            Spacer()
            Image(systemName: symbol).font(.title3)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(RPTheme.orange, in: RoundedRectangle(cornerRadius: 11))
    }

    private var bottomBar: some View {
        HStack(spacing: 1) {
            ForEach(LauncherSection.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .frame(height: 26)
                        Text(item.rawValue).font(.system(size: 10, weight: tab == item ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Capsule().fill(tab == item ? RPTheme.orange : .clear)
                            .frame(height: 3).padding(.horizontal, 7)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(tab == item ? RPTheme.orange : .white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .background(RPTheme.panel)
    }
}

private struct Cityscape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let factors: [(CGFloat, CGFloat)] = [
            (0.02,0.26),(0.12,0.58),(0.21,0.39),(0.31,0.72),
            (0.39,0.49),(0.48,0.87),(0.57,0.57),(0.65,0.35),
            (0.73,0.76),(0.83,0.46),(0.91,0.67)
        ]
        for (x,h) in factors {
            path.addRect(CGRect(x: rect.width*x, y: rect.height*(1-h), width: rect.width*0.085, height: rect.height*h))
        }
        return path
    }
}
