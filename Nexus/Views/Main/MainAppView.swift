import SwiftUI


struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @State private var showWorldSwitcher = false

    var body: some View {
        HStack(spacing: 0) {
            if appState.sidebarVisible {
                SidebarView()
                    .frame(width: 216)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                TopBarView(showWorldSwitcher: $showWorldSwitcher)

                ZStack {
                    switch appState.currentTab {
                    case .home: HomeView()
                    case .world: WorldWorkspaceView()
                    case .wiki: WikiView()
                    case .quill: QuillView()
                    case .echo: EchoView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.currentTab)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: appState.sidebarVisible)
    }
}
