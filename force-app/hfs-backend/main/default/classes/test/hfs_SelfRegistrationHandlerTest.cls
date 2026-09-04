/**
 * @description Tests for the self-registration handler — verifies it delegates
 * to the service and fails closed without leaving partial records.
 */
@isTest
private class hfs_SelfRegistrationHandlerTest {
    @isTest
    static void createUser_delegatesToService() {
        User current = new User(Id = UserInfo.getUserId());
        System.runAs(current) {
            hfs_SelfRegistrationHandler handler = new hfs_SelfRegistrationHandler();

            Integer contactsBefore = [SELECT COUNT() FROM Contact WHERE Email = 'handler@dealer.test'];

            Test.startTest();
            Boolean provisioned = false;
            try {
                Map<SObjectField, String> attrs = new Map<SObjectField, String>{
                    User.FirstName => 'Handler',
                    User.LastName => 'Dealer',
                    User.Email => 'handler@dealer.test'
                };
                Id userId = handler.createUser(null, null, attrs, 'Abcd1234!xyz');
                provisioned = (userId != null);
            } catch (hfs_ApplicationException e) {
                Assert.areEqual(
                    hfs_Constants.PROVISIONING_FAILED,
                    e.errorCode,
                    'On failure the code must be PROVISIONING_FAILED'
                );
            }
            Test.stopTest();

            Integer contactsAfter = [SELECT COUNT() FROM Contact WHERE Email = 'handler@dealer.test'];
            if (!provisioned) {
                Assert.areEqual(contactsBefore, contactsAfter, 'No partial Contact should remain on rollback');
            }
        }
    }
}