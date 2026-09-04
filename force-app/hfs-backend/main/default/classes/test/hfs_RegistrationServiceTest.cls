/**
 * @description Service-tier tests. Per team convention the service test exercises
 * the complete flow end-to-end — duplicate rejection, guard failures, fail-closed
 * provisioning, and the permission-set assignment — and directly covers the
 * Selector and Domain helpers it orchestrates (there are no standalone
 * selector / domain test classes).
 */
@isTest
private class hfs_RegistrationServiceTest {
    @isTest
    static void registerPartner_duplicateContact_throwsDuplicate() {
        Account acct = new Account(Name = 'Existing Partner');
        insert acct;
        insert new Contact(LastName = 'Existing', Email = 'dupe@dealer.test', AccountId = acct.Id);

        hfs_RegistrationService svc = new hfs_RegistrationServiceImpl();
        hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('Dupe Dealer', 'dupe@dealer.test');

        Boolean threw = false;
        Test.startTest();
        try {
            svc.registerPartner(w);
        } catch (hfs_ApplicationException e) {
            threw = true;
            Assert.areEqual(hfs_Constants.DUPLICATE_EMAIL, e.errorCode, 'Should be DUPLICATE_EMAIL');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Duplicate contact should be rejected');
    }

    @isTest
    static void registerPartner_blankName_tripsGuard() {
        hfs_RegistrationService svc = new hfs_RegistrationServiceImpl();
        hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('', 'blank@dealer.test');

        Boolean threw = false;
        Test.startTest();
        try {
            svc.registerPartner(w);
        } catch (hfs_ApplicationException e) {
            threw = true;
            Assert.areEqual(hfs_Constants.EMPTY_PAYLOAD, e.errorCode, 'Blank name trips the guard');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Blank name should throw a guard exception');
    }

    @isTest
    static void registerPartner_uniqueInput_provisionsOrFailsClosed() {
        User current = new User(Id = UserInfo.getUserId());
        System.runAs(current) {
            hfs_RegistrationService svc = new hfs_RegistrationServiceImpl();
            hfs_RegistrationWrapper w = hfs_TestDataFactory.buildRegistrationWrapper('Fresh Dealer', 'fresh@dealer.test');

            Integer contactsBefore = [SELECT COUNT() FROM Contact WHERE Email = 'fresh@dealer.test'];
            Test.startTest();
            Boolean provisioned = false;
            try {
                svc.registerPartner(w);
                provisioned = true;
            } catch (hfs_ApplicationException e) {
                Assert.areEqual(
                    hfs_Constants.PROVISIONING_FAILED,
                    e.errorCode,
                    'On failure the code must be PROVISIONING_FAILED (fail closed)'
                );
            }
            Test.stopTest();

            Integer contactsAfter = [SELECT COUNT() FROM Contact WHERE Email = 'fresh@dealer.test'];
            if (!provisioned) {
                Assert.areEqual(contactsBefore, contactsAfter, 'No partial Contact should remain on rollback');
            }
        }
    }

    @isTest
    static void provisionPartner_createsInactiveUserOrFailsClosed() {
        User current = new User(Id = UserInfo.getUserId());
        System.runAs(current) {
            hfs_RegistrationService svc = new hfs_RegistrationServiceImpl();
            Integer contactsBefore = [SELECT COUNT() FROM Contact WHERE Email = 'runas@dealer.test'];

            Test.startTest();
            Boolean provisioned = false;
            Id userId = null;
            try {
                hfs_RegistrationWrapper dto = hfs_TestDataFactory.buildRegistrationWrapper(
                    'RunAs Fuel Co', 'RunAs Dealer', '(303) 555-0100',
                    'runas@dealer.test', 'Dealer', 'Colorado', 'Please grant portal access.'
                );
                userId = svc.provisionPartner(dto);
                provisioned = (userId != null);
            } catch (hfs_ApplicationException e) {
                Assert.areEqual(
                    hfs_Constants.PROVISIONING_FAILED,
                    e.errorCode,
                    'On failure the code must be PROVISIONING_FAILED (fail closed)'
                );
            }
            Test.stopTest();

            Integer contactsAfter = [SELECT COUNT() FROM Contact WHERE Email = 'runas@dealer.test'];
            if (provisioned) {
                Assert.areEqual(1, contactsAfter - contactsBefore, 'A Contact should exist for the provisioned partner');
                User created = [SELECT IsActive FROM User WHERE Id = :userId];
                Assert.isFalse(created.IsActive, 'The portal User must be created inactive until the emailed link is clicked');
                // The request-access form fields persist to standard fields.
                Contact con = [
                    SELECT Phone, MailingState, Description, Account.Name, Account.Type
                    FROM Contact WHERE Email = 'runas@dealer.test' LIMIT 1
                ];
                Assert.areEqual('(303) 555-0100', con.Phone, 'Phone persists to Contact.Phone');
                Assert.areEqual('Colorado', con.MailingState, 'Territory persists to Contact.MailingState');
                Assert.areEqual('Please grant portal access.', con.Description, 'Message persists to Contact.Description');
                Assert.areEqual('RunAs Fuel Co', con.Account.Name, 'Company persists to Account.Name');
                Assert.areEqual('Dealer', con.Account.Type, 'Partner type persists to Account.Type');
            } else {
                Assert.areEqual(contactsBefore, contactsAfter, 'No partial Contact should remain on rollback');
            }
        }
    }

    @isTest
    static void provisionPartner_blankEmail_tripsGuard() {
        // A blank email trips the guard before any DML — proves no records are
        // created on invalid input.
        hfs_RegistrationService svc = new hfs_RegistrationServiceImpl();
        Boolean threw = false;
        Test.startTest();
        try {
            svc.provisionPartner(hfs_TestDataFactory.buildRegistrationWrapper('No Email Dealer', ''));
        } catch (hfs_ApplicationException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Blank email should trip the guard before provisioning');
    }

    @isTest
    static void assignPartnerPermissionSet_assignsPermSet() {
        // Cover the post-insert permission-set assignment directly with a real
        // test user so the assignment line executes (no mixed DML).
        Id sysAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id;
        String uniq = 'crhfsfin' + String.valueOf(Datetime.now().getTime());
        User u = new User(
            ProfileId = sysAdminProfileId,
            Username = uniq + '@crhfs.test',
            Email = uniq + '@crhfs.test',
            FirstName = 'Fin',
            LastName = 'User',
            Alias = 'crhfsfin',
            TimeZoneSidKey = 'America/Denver',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = 'hfs_Dry_Run_Partner' LIMIT 1].Id;

        Test.startTest();
        hfs_RegistrationServiceImpl impl = new hfs_RegistrationServiceImpl();
        impl.assignPartnerPermissionSet(u.Id, permSetId);
        Test.stopTest();

        List<PermissionSetAssignment> assignments = [
            SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSetId = :permSetId
        ];
        Assert.areEqual(1, assignments.size(), 'Partner permission set should be assigned');
    }

    @isTest
    static void selectorsAndDomain_coveredThroughService() {
        // Directly exercise the Selector and Domain helpers the service orchestrates
        // (no standalone selector/domain test classes per team convention).
        Account acct = new Account(Name = 'Sel Domain Co');
        insert acct;
        insert new Contact(LastName = 'Sel', Email = 'seldomain@dealer.test', AccountId = acct.Id);

        Test.startTest();
        // Contacts selector (SYSTEM_MODE, bind map).
        List<Contact> found = new hfs_ContactsGenericSelector().getContactsRecords(
            'Email = :email',
            new Map<String, Object>{ 'email' => 'seldomain@dealer.test' },
            new List<String>{ 'Id', 'Email' }
        );
        Assert.areEqual(1, found.size(), 'Contacts selector should find the seeded Contact');

        // Users selector + profile resolution.
        hfs_UsersSelector usersSel = new hfs_UsersSelector();
        Id profileId = usersSel.getProfileIdByName('System Administrator');
        Assert.isNotNull(profileId, 'Users selector should resolve a Profile Id');

        // Portal account owner resolution by username (role-bearing owner lookup).
        User me = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Assert.areEqual(
            UserInfo.getUserId(),
            usersSel.getUserIdByUsername(me.Username),
            'Owner lookup resolves an active User by username'
        );
        Assert.isNull(usersSel.getUserIdByUsername(null), 'Blank username resolves to null');
        Assert.isNull(usersSel.getUserIdByUsername('no.such.user@nowhere.invalid'), 'Unknown username resolves to null');

        // Permission sets selector.
        Id permSetId = new hfs_PermissionSetsSelector().getPermissionSetIdByName('hfs_Dry_Run_Partner');
        Assert.isNotNull(permSetId, 'Permission set selector should resolve the partner permission set');

        // Contacts Domain (fflib) — the full name is staged on LastName;
        // parsing happens via the Domain's defaulting. Resolve the Domain
        // through the Application factory (never `new` directly).
        Contact twoWord = new Contact(LastName = 'Sonny Bono', Email = 'sonny@dealer.test', AccountId = acct.Id);
        ((hfs_ContactsDomain) hfs_Application.Domain.newInstance(new List<Contact>{ twoWord }))
            .applyRegistrationDefaults();
        Assert.areEqual('Bono', twoWord.LastName, 'Two-word name splits into last name');
        Assert.areEqual('Sonny', twoWord.FirstName, 'Two-word name splits into first name');

        Contact single = new Contact(LastName = 'Cher', Email = 'cher@dealer.test');
        new hfs_ContactsDomain(new List<Contact>{ single }).applyRegistrationDefaults();
        Assert.areEqual('Cher', single.LastName, 'Single-word name becomes last name');
        Assert.isNull(single.FirstName, 'Single-word name has no first name');

        // onApplyDefaults() (the fflib override) performs the same parsing.
        Contact viaOverride = new Contact(LastName = 'Kris Kross', Email = 'kk@dealer.test');
        hfs_ContactsDomain domain = new hfs_ContactsDomain(new List<Contact>{ viaOverride });
        domain.onApplyDefaults();
        Assert.areEqual('Kris', viaOverride.FirstName, 'onApplyDefaults parses first name');
        Assert.areEqual('Kross', viaOverride.LastName, 'onApplyDefaults parses last name');

        // Domain Constructor builds an instance from a record set.
        fflib_SObjectDomain built = new hfs_ContactsDomain.Constructor()
            .construct(new List<Contact>{ viaOverride });
        Assert.isTrue(built instanceof hfs_ContactsDomain, 'Constructor builds the domain');

        // fflib Contact selector resolves through the Application factory.
        insert new Contact(LastName = 'FfLib', Email = 'fflibsel@dealer.test', AccountId = acct.Id);
        List<Contact> byEmail = ((hfs_ContactsSelector) hfs_Application.Selector.newInstance(Contact.SObjectType))
            .selectByEmail(new Set<String>{ 'fflibsel@dealer.test' });
        Assert.areEqual(1, byEmail.size(), 'fflib selector finds the Contact by email');
        Test.stopTest();
    }
}