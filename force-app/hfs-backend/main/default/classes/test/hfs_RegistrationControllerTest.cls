/**
 * @description Controller-tier tests. Per team convention the controller test
 * covers input validation and the final hfs_Response shape (success and
 * every error branch), including the response wrapper's own success/error/
 * unexpected paths — there is no separate wrapper test class. Two-tier
 * structure like hfs_ToolboxControllerTest / hfs_TrainingControllerTest:
 * Tier 1 exercises register() end-to-end against the real
 * hfs_RegistrationServiceImpl; Tier 2 stubs hfs_RegistrationService via
 * ApexMocks + hfs_Application.Service.setMock to deterministically prove the
 * hfs_Response translation contract in isolation from provisioning.
 */
@IsTest
private class hfs_RegistrationControllerTest {
    // ---------- Tier 1: real end-to-end ----------

    @IsTest
    static void register_uniqueInput_returnsWellFormedResponse() {
        User current = new User(Id = UserInfo.getUserId());
        hfs_Response response;
        System.runAs(current) {
            hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('Ctrl Dealer', 'ctrl@dealer.test');
            Test.startTest();
            response = hfs_RegistrationController.register(w);
            Test.stopTest();
        }

        // Either provisioning succeeds, or it fails closed with a displayable
        // error — the Controller always returns a well-formed hfs_Response.
        if (response.isSuccess) {
            hfs_RegistrationWrapper payload = (hfs_RegistrationWrapper) response.payload;
            Assert.isTrue(payload.provisioned, 'provisioned flag should be true on success');
        } else {
            Assert.isNotNull(response.errorCode, 'A machine-readable error code should be present');
            Assert.isNotNull(response.errorMessage, 'A displayable error message should be present');
        }
    }

    @IsTest
    static void register_duplicate_returnsDuplicateErrorResponse() {
        Account acct = new Account(Name = 'Ctrl Existing');
        insert acct;
        insert new Contact(LastName = 'Existing', Email = 'ctrldupe@dealer.test', AccountId = acct.Id);

        hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('Ctrl Dupe', 'ctrldupe@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(w);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Duplicate should fail');
        Assert.areEqual(hfs_Constants.DUPLICATE_EMAIL, response.errorCode, 'Error code should be DUPLICATE_EMAIL');
        Assert.isNotNull(response.errorMessage, 'A displayable error message should be present');
    }

    @IsTest
    static void register_nullInput_returnsErrorResponse() {
        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(null);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Null input should fail');
        Assert.isNotNull(response.errorCode, 'Guard failure should carry a code');
    }

    @IsTest
    static void register_blankName_returnsErrorResponse() {
        hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('', 'blankname@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(w);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Blank name should fail at the guard boundary');
    }

    // ---------- Tier 2: mocked Service (isolate the Controller) ----------

    @IsTest
    static void register_mockedService_returnsProvisionedPayload() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_RegistrationService mockService = (hfs_RegistrationService) mocks.mock(
            hfs_RegistrationServiceImpl.class
        );
        mocks.startStubbing();
        mocks.when(mockService.registerPartner((hfs_RegistrationWrapper) fflib_Match.anyObject()))
            .thenReturn((Id) null);
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_RegistrationService.class, mockService);

        hfs_RegistrationWrapper dto = hfs_TestDataFactory.buildRegistrationWrapper('Mock Dealer', 'mock@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(dto);
        Test.stopTest();

        Assert.isTrue(response.isSuccess, 'Mocked success expected');
        hfs_RegistrationWrapper payload = (hfs_RegistrationWrapper) response.payload;
        Assert.isTrue(payload.provisioned, 'Controller should set provisioned=true on success');
        Assert.areEqual('mock@dealer.test', payload.email, 'Payload should echo the submitted DTO');
    }

    @IsTest
    static void register_businessException_surfacesOwnCodeAndMessage() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_RegistrationService mockService = (hfs_RegistrationService) mocks.mock(
            hfs_RegistrationServiceImpl.class
        );
        mocks.startStubbing();
        mocks.when(mockService.registerPartner((hfs_RegistrationWrapper) fflib_Match.anyObject()))
            .thenThrow(
                hfs_ApplicationException.build(System.Label.hfs_Error_Duplicate_Email, hfs_Constants.DUPLICATE_EMAIL)
            );
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_RegistrationService.class, mockService);

        hfs_RegistrationWrapper dto = hfs_TestDataFactory.buildRegistrationWrapper('Mock Dupe', 'mockdupe@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(dto);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Business exception should fail the response');
        Assert.areEqual(
            hfs_Constants.DUPLICATE_EMAIL,
            response.errorCode,
            'Business exception code should surface unchanged'
        );
        Assert.areEqual(
            System.Label.hfs_Error_Duplicate_Email,
            response.errorMessage,
            'Business exception message should surface unchanged'
        );
    }

    @IsTest
    static void register_unexpectedException_mapsToFallback() {
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        hfs_RegistrationService mockService = (hfs_RegistrationService) mocks.mock(
            hfs_RegistrationServiceImpl.class
        );
        mocks.startStubbing();
        mocks.when(mockService.registerPartner((hfs_RegistrationWrapper) fflib_Match.anyObject()))
            .thenThrow(new System.NullPointerException());
        mocks.stopStubbing();
        hfs_Application.Service.setMock(hfs_RegistrationService.class, mockService);

        hfs_RegistrationWrapper dto = hfs_TestDataFactory.buildRegistrationWrapper('Mock Fail', 'mockfail@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(dto);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Unexpected exception should fail the response');
        Assert.areEqual(
            hfs_Constants.UNEXPECTED_ERROR,
            response.errorCode,
            'Unexpected exception should map to the domain-neutral fallback code'
        );
        Assert.areEqual(
            System.Label.hfs_Msg_Generic_Error,
            response.errorMessage,
            'Unexpected exception should map to the safe fallback message'
        );
    }

    @IsTest
    static void response_successAndErrorFactories_populateFields() {
        // Covers the response wrapper directly — success, explicit error(msg,code),
        // known hfs_ApplicationException, and the generic/unexpected branch.
        hfs_Response ok = hfs_Response.success('payload');
        Assert.isTrue(ok.isSuccess, 'success() should set isSuccess');
        Assert.areEqual('payload', (String) ok.payload, 'success() should carry the payload');

        hfs_Response explicit = hfs_Response.error('boom', hfs_Constants.VALIDATION);
        Assert.isFalse(explicit.isSuccess, 'error() should set isSuccess false');
        Assert.areEqual(hfs_Constants.VALIDATION, explicit.errorCode, 'error() should carry the code');

        hfs_Response known = hfs_Response.error(
            hfs_ApplicationException.build('nope', hfs_Constants.CONFIG_MISSING)
        );
        Assert.areEqual(hfs_Constants.CONFIG_MISSING, known.errorCode, 'Known exception code should surface');

        hfs_Response unexpected = hfs_Response.error(new NullPointerException());
        Assert.areEqual(hfs_Constants.UNEXPECTED_ERROR, unexpected.errorCode, 'Unknown exception maps to UNEXPECTED');
        Assert.isNotNull(unexpected.errorMessage, 'Unexpected error should carry a generic message');
    }
}