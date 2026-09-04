/**
 * @description Tests for hfs_ToolboxQuickActionsController. The controller is
 * thin, so tests mock the Service layer (via hfs_Application.Service.setMock)
 * to assert success wrapping and error translation, plus one real end-to-end
 * pass. Assertions are made directly on hfs_Response.
 */
@isTest
private class hfs_ToolboxQuickActionsControllerTest {

    @isTest
    static void getQuickActions_serviceSucceeds_wrapsPayloadInSuccess() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_ToolboxService mockService =
            (hfs_ToolboxService) mocks.mock(hfs_ToolboxServiceImpl.class);

        hfs_ToolboxDTO.QuickActionDTO a = new hfs_ToolboxDTO.QuickActionDTO();
        a.key = 'MY_FAVOURITES';
        a.count = 3;
        a.countStatus = hfs_ToolboxDTO.STATUS_AVAILABLE;

        mocks.startStubbing();
        mocks.when(mockService.getQuickActions())
            .thenReturn(new List<hfs_ToolboxDTO.QuickActionDTO>{ a });
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

        Test.startTest();
        hfs_Response resp = hfs_ToolboxQuickActionsController.getQuickActions();
        Test.stopTest();

        System.Assert.isTrue(resp.isSuccess, 'Response should be successful');
        List<hfs_ToolboxDTO.QuickActionDTO> payload =
            (List<hfs_ToolboxDTO.QuickActionDTO>) resp.payload;
        System.Assert.areEqual(1, payload.size(), 'One action expected in payload');
        System.Assert.areEqual(3, payload[0].count, 'Count should be carried through');
        ((hfs_ToolboxService) mocks.verify(mockService, 1)).getQuickActions();
    }

    @isTest
    static void getQuickActions_serviceThrows_returnsErrorResponse() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_ToolboxService mockService =
            (hfs_ToolboxService) mocks.mock(hfs_ToolboxServiceImpl.class);

        mocks.startStubbing();
        mocks.when(mockService.getQuickActions()).thenThrow(new CalloutException('boom'));
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_ToolboxService.class, mockService);

        Test.startTest();
        hfs_Response resp = hfs_ToolboxQuickActionsController.getQuickActions();
        Test.stopTest();

        System.Assert.isFalse(resp.isSuccess, 'Response should report failure');
        System.Assert.isNotNull(resp.errorMessage, 'Error message should be populated');
    }

    @isTest
    static void getQuickActions_realEndToEnd_returnsFiveActions() {
        hfs_TestDataFactory.createFavourites(3);

        Test.startTest();
        hfs_Response resp = hfs_ToolboxQuickActionsController.getQuickActions();
        Test.stopTest();

        System.Assert.isTrue(resp.isSuccess, 'Response should be successful');
        List<hfs_ToolboxDTO.QuickActionDTO> payload =
            (List<hfs_ToolboxDTO.QuickActionDTO>) resp.payload;
        System.Assert.areEqual(5, payload.size(), 'Five quick actions expected');
        System.Assert.areEqual(3, payload[0].count, 'Favourites count should be 3');
    }
}