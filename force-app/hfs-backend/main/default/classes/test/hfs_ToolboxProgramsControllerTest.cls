/**
 * @description Tests for hfs_ToolboxProgramsController. The controller is thin,
 * so tests mock the Service layer (via hfs_Application.Service.setMock) to
 * assert the controller correctly wraps a success payload and translates a
 * thrown exception into an hfs_Response failure. Assertions are made directly
 * on hfs_Response (isSuccess/payload for success; isSuccess=false/errorMessage
 * for failure).
 */
@isTest
private class hfs_ToolboxProgramsControllerTest {

    @isTest
    static void getMyPrograms_serviceSucceeds_wrapsPayloadInSuccess() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_ToolboxService mockService =
            (hfs_ToolboxService) mocks.mock(hfs_ToolboxServiceImpl.class);

        hfs_ToolboxDTO.ProgramGroupDTO programGroup = new hfs_ToolboxDTO.ProgramGroupDTO();
        hfs_ToolboxDTO.ProgramDTO dto = new hfs_ToolboxDTO.ProgramDTO();
        dto.key = 'p1';
        dto.label = 'Program 0';
        programGroup.programs.add(dto);

        mocks.startStubbing();
        mocks.when(mockService.getMyPrograms()).thenReturn(programGroup);
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

        Test.startTest();
        hfs_Response resp = hfs_ToolboxProgramsController.getMyPrograms();
        Test.stopTest();

        System.Assert.isTrue(resp.isSuccess, 'Response should be successful');
        hfs_ToolboxDTO.ProgramGroupDTO payload =
            (hfs_ToolboxDTO.ProgramGroupDTO) resp.payload;
        System.Assert.areEqual(1, payload.programs.size(), 'One program expected in payload');
        ((hfs_ToolboxService) mocks.verify(mockService, 1)).getMyPrograms();
    }

    @isTest
    static void getMyPrograms_serviceThrows_returnsErrorResponse() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_ToolboxService mockService =
            (hfs_ToolboxService) mocks.mock(hfs_ToolboxServiceImpl.class);

        mocks.startStubbing();
        mocks.when(mockService.getMyPrograms()).thenThrow(new CalloutException('boom'));
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

        Test.startTest();
        hfs_Response resp = hfs_ToolboxProgramsController.getMyPrograms();
        Test.stopTest();

        System.Assert.isFalse(resp.isSuccess, 'Response should report failure');
        System.Assert.isNotNull(resp.errorMessage, 'Error message should be populated');
    }

    @isTest
    static void getMyPrograms_realEndToEnd_returnsEnrolledPrograms() {
        // One real, unmocked end-to-end pass through Controller -> Service -> Selector.
        List<hfs_Program__c> programs = hfs_TestDataFactory.createPrograms(2);
        hfs_TestDataFactory.createEnrolments(programs, UserInfo.getUserId());

        Test.startTest();
        hfs_Response resp = hfs_ToolboxProgramsController.getMyPrograms();
        Test.stopTest();

        System.Assert.isTrue(resp.isSuccess, 'Response should be successful');
        hfs_ToolboxDTO.ProgramGroupDTO payload =
            (hfs_ToolboxDTO.ProgramGroupDTO) resp.payload;
        System.Assert.areEqual(2, payload.programs.size(), 'Two enrolled programs expected');
    }
}