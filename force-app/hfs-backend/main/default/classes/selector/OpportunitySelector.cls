public with sharing class OpportunitySelector {

    public static List<Opportunity> selectById(Set<Id> opportunityIds) {
        return [
            SELECT Id, Name, StageName, Amount, CloseDate, AccountId
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];
    }
}
