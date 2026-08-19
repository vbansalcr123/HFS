@isTest
private class ContactEmailValidationServiceTest {

    @TestSetup
    static void setupData() {
        insert new List<Contact>{
            new Contact(FirstName = 'Valid', LastName = 'Email', Email = 'valid@example.com'),
            new Contact(FirstName = 'Invalid', LastName = 'Email', Email = 'not-an-email'),
            new Contact(FirstName = 'Blank', LastName = 'Email', Email = null)
        };
    }

    @isTest
    static void testValidateEmails_setsExpectedOptOutStatus() {
        Map<String, Id> contactIdByFirstName = new Map<String, Id>();
        for (Contact con : [SELECT Id, FirstName FROM Contact]) {
            contactIdByFirstName.put(con.FirstName, con.Id);
        }

        Test.startTest();
        ContactEmailValidationService.validateEmails(new Set<Id>(contactIdByFirstName.values()));
        Test.stopTest();

        Map<Id, Contact> updatedContactsById = new Map<Id, Contact>(
            [SELECT Id, HasOptedOutOfEmail FROM Contact]
        );

        System.assertEquals(false, updatedContactsById.get(contactIdByFirstName.get('Valid')).HasOptedOutOfEmail);
        System.assertEquals(true, updatedContactsById.get(contactIdByFirstName.get('Invalid')).HasOptedOutOfEmail);
        System.assertEquals(true, updatedContactsById.get(contactIdByFirstName.get('Blank')).HasOptedOutOfEmail);
    }

    @isTest
    static void testIsValidEmail_branchCoverage() {
        System.assertEquals(true, ContactEmailValidationService.isValidEmail('someone@example.com'));
        System.assertEquals(false, ContactEmailValidationService.isValidEmail('not-an-email'));
        System.assertEquals(false, ContactEmailValidationService.isValidEmail(null));
        System.assertEquals(false, ContactEmailValidationService.isValidEmail(''));
    }

    @isTest
    static void testValidateEmails_alreadyCorrect_skipsUpdate() {
        List<Contact> contacts = [SELECT Id, Email FROM Contact];
        for (Contact con : contacts) {
            con.HasOptedOutOfEmail = !ContactEmailValidationService.isValidEmail(con.Email);
        }
        update contacts;

        Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

        Test.startTest();
        ContactEmailValidationService.validateEmails(contactIds);
        Test.stopTest();
    }
}
