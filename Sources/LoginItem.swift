import ServiceManagement

enum LoginItem {

    static func toggle() -> Bool {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                return false
            default:
                try service.register()
                return true
            }
        } catch {
            NSLog("ClamKeep: Login item error: \(error.localizedDescription)")
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
            return isEnabled()
        }
    }

    static func isEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
