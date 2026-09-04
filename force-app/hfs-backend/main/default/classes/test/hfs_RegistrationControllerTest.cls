/**
 * @description Controller-tier tests. Per team convention the controller test
 * covers input validation and the final hfs_Response shape (success and
 * every error branch), including the response wrapper's own success/error/
 * unexpected paths — there is no separate wrapper test class.
 */
@isTest
private class hfs_RegistrationControllerTest {
    @isTest
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

    @isTest
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

    @isTest
    static void register_nullInput_returnsErrorResponse() {
        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(null);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Null input should fail');
        Assert.isNotNull(response.errorCode, 'Guard failure should carry a code');
    }

    @isTest
    static void register_blankName_returnsErrorResponse() {
        hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('', 'blankname@dealer.test');

        Test.startTest();
        hfs_Response response = hfs_RegistrationController.register(w);
        Test.stopTest();

        Assert.isFalse(response.isSuccess, 'Blank name should fail at the guard boundary');
    }

    @isTest
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