/**
 * @description Tests for the consolidated hfs_ToolboxController. Two-tier:
 * Tier 1 exercises all three endpoints end-to-end (Controller -> Service ->
 * Selector) with real hfs_TestDataFactory data and real DML. Tier 2 stubs the
 * Service via ApexMocks + hfs_Application.Service.setMock to isolate the
 * Controller and prove the hfs_Response error contract: a business
 * hfs_ApplicationException surfaces its own code/message, while an unexpected
 * exception maps to the controller's domain fallback.
 */
@isTest
private class hfs_ToolboxControllerTest {
  // ---------- Tier 1: real end-to-end ----------

  @isTest
  static void getMyPrograms_realData_returnsEnrolledPrograms() {
    List<hfs_Program__c> programs = hfs_TestDataFactory.createPrograms(3);
    hfs_TestDataFactory.createEnrolments(programs, UserInfo.getUserId());

    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getMyPrograms();
    Test.stopTest();

    System.Assert.isTrue(resp.isSuccess, 'Programs call should succeed');
    hfs_ToolboxDTO.ProgramGroupDTO programGroup = (hfs_ToolboxDTO.ProgramGroupDTO) resp.payload;
    System.Assert.areEqual(
      3,
      programGroup.programs.size(),
      'Three enrolled programs expected'
    );
    System.Assert.areEqual(
      hfs_ToolboxDTO.STATUS_AVAILABLE,
      programGroup.listStatus,
      'List status should be available'
    );
  }

  @isTest
  static void getQuickActions_realData_returnsFiveOrderedActions() {
    hfs_TestDataFactory.createFavourites(2);

    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getQuickActions();
    Test.stopTest();

    System.Assert.isTrue(resp.isSuccess, 'Quick actions call should succeed');
    List<hfs_ToolboxDTO.QuickActionDTO> actions = (List<hfs_ToolboxDTO.QuickActionDTO>) resp.payload;
    System.Assert.areEqual(5, actions.size(), 'Five quick actions expected');
    System.Assert.areEqual(
      'MY_FAVOURITES',
      actions[0].key,
      'Favourites is first'
    );
  }

  @isTest
  static void getAccountLinks_returnsThreeStaticLinks() {
    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getAccountLinks();
    Test.stopTest();

    System.Assert.isTrue(resp.isSuccess, 'Account links call should succeed');
    List<hfs_ToolboxDTO.AccountLinkDTO> links = (List<hfs_ToolboxDTO.AccountLinkDTO>) resp.payload;
    System.Assert.areEqual(3, links.size(), 'Three account links expected');
    System.Assert.areEqual(
      '/my-profile',
      links[0].destinationUrl,
      'My Profile is the first link'
    );
  }

  // ---------- Tier 2: mocked Service (isolate the Controller) ----------

  @isTest
  static void getMyPrograms_mockedService_returnsPayload() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_ToolboxService mockService = (hfs_ToolboxService) mocks.mock(
      hfs_ToolboxServiceImpl.class
    );
    hfs_ToolboxDTO.ProgramGroupDTO expected = new hfs_ToolboxDTO.ProgramGroupDTO();
    mocks.startStubbing();
    mocks.when(mockService.getMyPrograms()).thenReturn(expected);
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getMyPrograms();
    Test.stopTest();

    System.Assert.isTrue(resp.isSuccess, 'Mocked success expected');
    System.Assert.areEqual(
      expected,
      resp.payload,
      'Payload should be the mocked DTO'
    );
  }

  @isTest
  static void getMyPrograms_businessException_surfacesOwnCodeAndMessage() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_ToolboxService mockService = (hfs_ToolboxService) mocks.mock(
      hfs_ToolboxServiceImpl.class
    );
    mocks.startStubbing();
    mocks.when(mockService.getMyPrograms())
      .thenThrow(
        new hfs_ApplicationException('NO_MEMBER_CONTEXT', 'No member context')
      );
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getMyPrograms();
    Test.stopTest();

    System.Assert.isFalse(
      resp.isSuccess,
      'Business exception should fail the response'
    );
    System.Assert.areEqual(
      'NO_MEMBER_CONTEXT',
      resp.errorCode,
      'Business exception code should surface unchanged'
    );
    System.Assert.areEqual(
      'No member context',
      resp.errorMessage,
      'Business exception message should surface unchanged'
    );
  }

  @isTest
  static void getQuickActions_unexpectedException_mapsToFallback() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_ToolboxService mockService = (hfs_ToolboxService) mocks.mock(
      hfs_ToolboxServiceImpl.class
    );
    mocks.startStubbing();
    mocks.when(mockService.getQuickActions())
      .thenThrow(new System.NullPointerException());
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

    Test.startTest();
    hfs_Response resp = hfs_ToolboxController.getQuickActions();
    Test.stopTest();

    System.Assert.isFalse(
      resp.isSuccess,
      'Unexpected exception should fail the response'
    );
    System.Assert.areEqual(
      hfs_ToolboxController.FALLBACK_CODE,
      resp.errorCode,
      'Unexpected exception should map to the domain fallback code'
    );
    System.Assert.areEqual(
      System.Label.hfs_Toolbox_Unexpected_Error,
      resp.errorMessage,
      'Unexpected exception should map to the safe fallback message'
    );
  }
}
