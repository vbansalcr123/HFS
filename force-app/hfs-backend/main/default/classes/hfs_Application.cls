/**
 * @description Project-wide application factory built on the installed fflib-apex-common
 * framework. Every Unit of Work, Domain, Selector and Service resolves through this class
 * rather than being instantiated directly, so any layer can be substituted with a mock in
 * tests.
 *
 * The fflib factory setMock(...) methods are protected @TestVisible, so this class exposes
 * thin @TestVisible subclasses that surface a public setMock for test code to call.
 */
public class hfs_Application {
  /**
   * Unit of Work factory - declares the SObject types in the order they must be committed
   * so dependent inserts (e.g. self-registration's Account -> Contact -> User ->
   * PermissionSetAssignment chain) resolve their parent relationships automatically.
   */
  public static final fflib_Application.UnitOfWorkFactory UnitOfWork = new fflib_Application.UnitOfWorkFactory(
    new List<Schema.SObjectType>{
      Account.SObjectType,
      Contact.SObjectType,
      User.SObjectType,
      PermissionSetAssignment.SObjectType
    }
  );

  /** Selector factory - resolves a Selector implementation for an SObjectType. */
  public static final SelectorFactory Selector = new SelectorFactory(
    new Map<SObjectType, Type>{
      hfs_Course__c.SObjectType => hfs_CoursesSelector.class,
      hfs_CourseProgress__c.SObjectType => hfs_CourseProgressSelector.class,
      hfs_Program_Enrolment__c.SObjectType => hfs_ProgramEnrolmentsSelector.class,
      hfs_Favorite__c.SObjectType => hfs_FavouritesSelector.class,
      Order.SObjectType => hfs_OrdersSelector.class,
      Contact.SObjectType => hfs_ContactsSelector.class
    }
  );

  /** Service factory - resolves a Service implementation for a service interface Type. */
  public static final ServiceFactory Service = new ServiceFactory(
    new Map<Type, Type>{
      hfs_TrainingService.class => hfs_TrainingServiceImpl.class,
      hfs_ToolboxService.class => hfs_ToolboxServiceImpl.class
    }
  );

  /**
   * Domain factory - resolves a Domain implementation for an SObjectType. Built on the
   * Selector factory above so domain constructors can be resolved via the same registry.
   */
  public static final fflib_Application.DomainFactory Domain = new fflib_Application.DomainFactory(
    hfs_Application.Selector,
    new Map<Schema.SObjectType, Type>{
      Contact.SObjectType => hfs_ContactsDomain.Constructor.class
    }
  );

  /**
   * @description Selector factory that surfaces a public, test-only setMock over the fflib
   * SelectorFactory (whose own setMock is protected @TestVisible).
   */
  public class SelectorFactory extends fflib_Application.SelectorFactory {
    /**
     * @description Constructs the factory from a production SObjectType -> Selector registry.
     * @param sObjectBySelectorType map of SObjectType to concrete Selector class
     */
    public SelectorFactory(Map<SObjectType, Type> sObjectBySelectorType) {
      super(sObjectBySelectorType);
    }

    /**
     * @description Registers a mock Selector for the given SObjectType (test use only).
     * @param sObjectType the SObjectType to mock
     * @param selectorInstance the mock selector instance to return
     */
    @TestVisible
    public override void setMock(
      SObjectType sObjectType,
      fflib_ISObjectSelector selectorInstance
    ) {
      super.setMock(sObjectType, selectorInstance);
    }
  }

  /**
   * @description Service factory that surfaces a public, test-only setMock over the fflib
   * ServiceFactory (whose own setMock is protected @TestVisible).
   */
  public class ServiceFactory extends fflib_Application.ServiceFactory {
    /**
     * @description Constructs the factory from a production interface -> impl registry.
     * @param serviceInterfaceTypeByServiceImplType map of service interface Type to impl class
     */
    public ServiceFactory(
      Map<Type, Type> serviceInterfaceTypeByServiceImplType
    ) {
      super(serviceInterfaceTypeByServiceImplType);
    }

    /**
     * @description Registers a mock Service for the given interface Type (test use only).
     * @param serviceInterfaceType the service interface Type to mock
     * @param serviceImpl the mock service instance to return
     */
    @TestVisible
    public override void setMock(
      Type serviceInterfaceType,
      Object serviceImpl
    ) {
      super.setMock(serviceInterfaceType, serviceImpl);
    }
  }
}
