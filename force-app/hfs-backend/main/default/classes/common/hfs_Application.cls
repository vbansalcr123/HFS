/**
 * @description Single, project-wide Apex Enterprise Patterns (fflib) factory
 * for the HFS My Toolbox feature. Every Selector and Service resolves through
 * this class so each layer can be substituted with an ApexMocks stub in tests.
 * No class outside this one should ever `new` a Selector or Service Impl
 * directly (see the project architecture standards).
 *
 * The base fflib factory `setMock(...)` methods are `protected`, so this class
 * exposes thin `public` factory subclasses that surface `setMock` for tests.
 */
public class hfs_Application {
    /**
     * @description Selector factory. Maps each SObjectType to its Selector
     * implementation. Resolve a selector with
     * `hfs_Application.Selector.newInstance(SObjectType)`.
     */
    public static final SelectorFactory Selector = new SelectorFactory(
        new Map<SObjectType, Type>{
            hfs_Program_Enrolment__c.SObjectType => hfs_ProgramEnrolmentsSelector.class,
            hfs_Favorite__c.SObjectType => hfs_FavouritesSelector.class,
            Order.SObjectType => hfs_OrdersSelector.class
        }
    );

    /**
     * @description Service factory. Maps each Service interface to its
     * implementation. Resolve a service with
     * `hfs_Application.Service.newInstance(hfs_ToolboxService.class)`.
     */
    public static final ServiceFactory Service = new ServiceFactory(
        new Map<Type, Type>{
            hfs_ToolboxService.class => hfs_ToolboxServiceImpl.class
        }
    );

    /**
     * @description Selector factory subclass that exposes a public setMock so
     * tests can inject ApexMocks-stubbed selectors.
     */
    public class SelectorFactory extends fflib_Application.SelectorFactory {
        public SelectorFactory(Map<SObjectType, Type> sObjectBySelectorType) {
            super(sObjectBySelectorType);
        }
        @TestVisible
        public override void setMock(fflib_ISObjectSelector selectorInstance) {
            setMock(selectorInstance.sObjectType(), selectorInstance);
        }
        @TestVisible
        public override void setMock(SObjectType sType, fflib_ISObjectSelector selectorInstance) {
            super.setMock(sType, selectorInstance);
        }
    }

    /**
     * @description Service factory subclass that exposes a public setMock so
     * tests can inject an ApexMocks-stubbed service implementation.
     */
    public class ServiceFactory extends fflib_Application.ServiceFactory {
        public ServiceFactory(Map<Type, Type> serviceInterfaceTypeByServiceImplType) {
            super(serviceInterfaceTypeByServiceImplType);
        }
        @TestVisible
        public override void setMock(Type serviceInterfaceType, Object serviceImpl) {
            super.setMock(serviceInterfaceType, serviceImpl);
        }
    }
}