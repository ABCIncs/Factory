import XCTest
@testable import Factory

class Services1 {
    @Injected(Container.myServiceType) var service
    @Injected(Container.mockService) var mock
    init() {}
}

class Services2 {
    @LazyInjected(Container.myServiceType) var service
    @LazyInjected(Container.mockService) var mock
    init() {}
}

class Services3 {
    @WeakLazyInjected(Container.sharedService) var service
    @WeakLazyInjected(Container.mockService) var mock
    init() {}
}

class Services5 {
    @Injected(Container.optionalService) var service
    init() {}
}

class ServicesP {
    @LazyInjected(Container.servicesC) var service
    let name = "Parent"
    init() {}
    func test() -> String? {
        service.name
    }
}

class ServicesC {
    @WeakLazyInjected(Container.servicesP) var service: ServicesP?
    init() {}
    let name = "Child"
    func test() -> String? {
        service?.name
    }
}

extension Container {
    fileprivate static var services1 = Factory { Services1() }
    fileprivate static var services2 = Factory { Services2() }
    fileprivate static var services3 = Factory { Services3() }
    fileprivate static var servicesP = Factory(scope: .shared) { ServicesP() }
    fileprivate static var servicesC = Factory(scope: .shared) { ServicesC() }
}

protocol ProtocolP: AnyObject {
    var name: String { get }
    func test() -> String?
}

class ProtocolClassP: ProtocolP {
    let child = Container.protocolC()
    let name = "Parent"
    init() {}
    func test() -> String? {
        child.name
    }
}

protocol ProtocolC: AnyObject {
    var parent: ProtocolP? { get set }
    var name: String { get }
    func test() -> String?
}

class ProtocolClassC: ProtocolC {
    weak var parent: ProtocolP?
    init() {}
    let name = "Child"
    func test() -> String? {
        parent?.name
    }
}

extension Container {
    fileprivate static var protocolP = Factory<ProtocolP> (scope: .shared) {
        let p = ProtocolClassP()
        p.child.parent = p
        return p
    }
    fileprivate static var protocolC = Factory<ProtocolC> (scope: .shared) {
        ProtocolClassC()
    }
}


final class FactoryInjectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Container.Registrations.reset()
        Container.Scope.reset()
    }

    func testBasicInjection() throws {
        let services = Services1()
        XCTAssertTrue(services.service.text() == "MyService")
        XCTAssertTrue(services.mock.text() == "MockService")
    }

    func testLazyInjection() throws {
        let services = Services2()
        XCTAssertTrue(services.service.text() == "MyService")
        XCTAssertTrue(services.mock.text() == "MockService")
    }

    func testLazyInjectionOccursOnce() throws {
        let services = Services2()
        let id1 = services.service.id
        let id2 = services.service.id
        XCTAssertTrue(id1 == id2)
    }

    func testOptionalInjection() throws {
        let services = Services5()
        XCTAssertTrue(services.service?.text() == "MyService")
    }

    func testWeakLazyInjection() throws {
        var parent: ServicesP? = Container.servicesP()
        let child = Container.servicesC()
        XCTAssertTrue(parent?.test() == "Child")
        XCTAssertTrue(child.test() == "Parent")
        parent = nil
        XCTAssertNil(child.test())
    }

    func testWeakLazyInjectionProtocol() throws {
        var parent: ProtocolP? = Container.protocolP()
        let child: ProtocolC? = Container.protocolC()
        XCTAssertTrue(parent?.test() == "Child")
        XCTAssertTrue(child?.test() == "Parent")
        parent = nil
        XCTAssertNil(child?.test())
    }

    func testInjectionSet() throws {
        let service = Container.services1()
        let oldId = service.service.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service.id != oldId)
        XCTAssertTrue(service.service.id == newId)
    }

    func testLazyInjectionSet() throws {
        let service = Container.services2()
        let oldId = service.service.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service.id != oldId)
        XCTAssertTrue(service.service.id == newId)
    }

    func testWeakLazyInjectionSet() throws {
        let strongReference: MyService? = Container.sharedService()
        XCTAssertNotNil(strongReference)
        let service = Container.services3()
        let oldId = service.service?.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service?.id != oldId)
        XCTAssertTrue(service.service?.id == newId)
    }

    func testInjectionResolve() throws {
        let object = Container.services1()
        let oldId = object.service.id
        // force resolution
        object.$service.resolve()
        // should have new instance
        let newId = object.service.id
        XCTAssertTrue(oldId != newId)
    }

    func testLazyInjectionResolve() throws {
        let object = Container.services2()
        let oldId = object.service.id
        // force resolution
        object.$service.resolve()
        // should have new instance
        let newId = object.service.id
        XCTAssertTrue(oldId != newId)
    }

    func testWeakLazyInjectionResolve() throws {
        var strongReference: MyService? = Container.sharedService()
        XCTAssertNotNil(strongReference)
        let oldId = strongReference?.id

        let service = Container.services3()
        let newID = service.service?.id
        XCTAssertTrue(oldId == newID)

        service.service = nil

        service.$service.resolve()
        XCTAssertNotNil(service.service)
        XCTAssertTrue(service.service?.id == newID)

        strongReference = nil
        XCTAssertNil(service.service)

        service.$service.resolve()

        XCTAssertNil(service.service)
    }

}
