public with sharing class ScratchReviewBotTest {
  public static List<Account> selectAccountsForContacts(
    List<Contact> contacts
  ) {
    Set<Id> accountIds = new Set<Id>();
    for (Contact c : contacts) {
      accountIds.add(c.AccountId);
    }
    return AccountSelector.selectById(accountIds);
  }
}
