public with sharing class AccountSelector {

    public static List<Account> selectById(Set<Id> accountIds) {
        return [
            SELECT Id, Name, AnnualRevenue, Rating
            FROM Account
            WHERE Id IN :accountIds
        ];
    }
}
