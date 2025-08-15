//
//  DIContainer.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import Foundation

final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    private var services: [String: Any] = [:]

    func register<Service>(type: Service.Type, component: Any) {
        let key = String(describing: type)
        services[key] = component
    }

    func resolve<Service>(type: Service.Type) -> Service {
        let key = String(describing: type)
        guard let component = services[key] as? Service else {
            fatalError("\(key)가 등록되지 않았습니다. 앱 시작점에서 등록했는지 확인하세요.")
        }
        return component
    }
}

extension DIContainer {
    static func registerForPreview() {
        let container = DIContainer.shared
        
        container.register(type: BibleRepository.self, component: MockBibleRepository.shared)
        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
        container.register(type: FontThemeManager.self, component: FontThemeManager(
            fontConfiguration: defaultFontConfiguration,
            theme: Theme.system
        ))
    }
}
