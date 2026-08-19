public with sharing class AccountRatingService {

    private static final Decimal HOT_THRESHOLD = 1000000;

    public static void rateAccounts(Set<Id> accountIds) {
        List<Account> accounts = AccountSelector.selectById(accountIds);
        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : accounts) {
            String newRating = calculateRating(acc.AnnualRevenue);
            if (acc.Rating != newRating) {
                acc.Rating = newRating;
                accountsToUpdate.add(acc);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    public static String calculateRating(Decimal annualRevenue) {
        if (annualRevenue == null) {
            return 'Cold';
        }
        if (annualRevenue >= HOT_THRESHOLD) {
            return 'Hot';
        }
        return 'Warm';
    }
}
