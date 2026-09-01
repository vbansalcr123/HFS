@isTest
private class OpportunityRiskControllerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Risk Test Account');
        insert acc;

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'At Risk Deal',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            )
        };
    }

    @isTest
    static void testGetHighRiskOpportunities_returnsOpportunitiesForAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Opportunity> results = OpportunityRiskController.getHighRiskOpportunities(
            new List<Id>{ acc.Id }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(acc.Id, results[0].AccountId);
    }

    @isTest
    static void testGetHighRiskOpportunities_noAccounts_returnsEmptyList() {
        Test.startTest();
        List<Opportunity> results = OpportunityRiskController.getHighRiskOpportunities(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, results.size());
    }
}
