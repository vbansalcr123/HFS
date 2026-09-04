public with sharing class OpportunityRiskController {
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getHighRiskOpportunities(
    List<Id> accountIds
  ) {
    List<Opportunity> highRiskOpportunities = new List<Opportunity>();

    for (Id accountId : accountIds) {
      List<Opportunity> opportunitiesForAccount = [
        SELECT Id, StageName, Amount, CloseDate, AccountId
        FROM Opportunity
        WHERE AccountId = :accountId
      ];
      highRiskOpportunities.addAll(opportunitiesForAccount);
    }

    return highRiskOpportunities;
  }
}
