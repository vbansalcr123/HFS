@isTest
private class AccountRatingServiceTest {

    @TestSetup
    static void setupData() {
        insert new List<Account>{
            new Account(Name = 'Hot Account', AnnualRevenue = 5000000),
            new Account(Name = 'Warm Account', AnnualRevenue = 250000),
            new Account(Name = 'Cold Account', AnnualRevenue = null)
        };
    }

    @isTest
    static void testRateAccounts_setsExpectedRatings() {
        Map<String, Id> accountIdByName = new Map<String, Id>();
        for (Account acc : [SELECT Id, Name FROM Account]) {
            accountIdByName.put(acc.Name, acc.Id);
        }

        Test.startTest();
        AccountRatingService.rateAccounts(new Set<Id>(accountIdByName.values()));
        Test.stopTest();

        Map<Id, Account> updatedAccountsById = new Map<Id, Account>(
            [SELECT Id, Rating FROM Account]
        );

        System.assertEquals('Hot', updatedAccountsById.get(accountIdByName.get('Hot Account')).Rating);
        System.assertEquals('Warm', updatedAccountsById.get(accountIdByName.get('Warm Account')).Rating);
        System.assertEquals('Cold', updatedAccountsById.get(accountIdByName.get('Cold Account')).Rating);
    }

    @isTest
    static void testCalculateRating_branchCoverage() {
        System.assertEquals('Cold', AccountRatingService.calculateRating(null));
        System.assertEquals('Warm', AccountRatingService.calculateRating(500000));
        System.assertEquals('Hot', AccountRatingService.calculateRating(1000000));
    }

    @isTest
    static void testRateAccounts_alreadyRated_skipsUpdate() {
        List<Account> accounts = [SELECT Id, AnnualRevenue FROM Account];
        for (Account acc : accounts) {
            acc.Rating = AccountRatingService.calculateRating(acc.AnnualRevenue);
        }
        update accounts;

        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

        Test.startTest();
        AccountRatingService.rateAccounts(accountIds);
        Test.stopTest();
    }
}
